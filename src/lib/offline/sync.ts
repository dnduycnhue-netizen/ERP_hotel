"use client";

import { uploadCapturedPhoto } from "@/features/attachments/upload-client";
import { recordCountLineAction } from "@/features/count/actions";
import {
  getReceivingReceiptStatusAction,
  overrideReceivingLineAction,
  postReceivingAction,
  recordReceivingLineAction,
} from "@/features/receiving/actions";
import {
  countOfflineJobsByStatus,
  deleteOfflineJob,
  discardFailedOfflineJobs,
  getOfflineDb,
  listPendingJobs,
  retryFailedOfflineJobs,
  updateOfflineJob,
  type OfflineJob,
  type QueuedPhoto,
} from "./db";

export type OfflineSyncState = {
  online: boolean;
  /** Job pending + đang gửi (chưa xong). */
  pendingCount: number;
  syncing: boolean;
  failedCount: number;
  lastError: string | null;
  lastSyncedAt: number | null;
};

export const initialSyncState: OfflineSyncState = {
  online: true,
  pendingCount: 0,
  syncing: false,
  failedCount: 0,
  lastError: null,
  lastSyncedAt: null,
};

export type SyncListener = {
  onRecordSynced?: (info: { grId: string; poLineId: string }) => void;
  onOverrideSynced?: (info: { grId: string; grLineId: string }) => void;
  onPostSynced?: (grId: string) => void;
  onCountRecordSynced?: (info: { countId: string; itemId: string }) => void;
};

let state: OfflineSyncState = initialSyncState;
const stateListeners = new Set<() => void>();
const syncListeners = new Set<SyncListener>();
let engineStarted = false;
let draining = false;

function setState(patch: Partial<OfflineSyncState>): void {
  state = { ...state, ...patch };
  for (const listener of stateListeners) {
    listener();
  }
}

export function subscribeSync(listener: () => void): () => void {
  stateListeners.add(listener);
  return () => {
    stateListeners.delete(listener);
  };
}

export function getSyncSnapshot(): OfflineSyncState {
  return state;
}

export function addSyncListener(listener: SyncListener): () => void {
  syncListeners.add(listener);
  return () => {
    syncListeners.delete(listener);
  };
}

async function refreshCounts(): Promise<void> {
  const [pending, syncing, failed] = await Promise.all([
    countOfflineJobsByStatus("pending"),
    countOfflineJobsByStatus("syncing"),
    countOfflineJobsByStatus("failed"),
  ]);
  setState({ pendingCount: pending + syncing, failedCount: failed });
}

/**
 * Khởi động engine đồng bộ (T-025, gọi 1 lần duy nhất): nghe sự kiện
 * online/offline của trình duyệt, có mạng lại là tự bơm hàng đợi.
 * Chạy phía client — mọi hàm đều tự bảo vệ khi render phía server.
 */
export function ensureOfflineEngine(): void {
  if (typeof window === "undefined" || engineStarted) {
    return;
  }
  engineStarted = true;
  const handleOnlineChange = () => {
    setState({ online: navigator.onLine });
    if (navigator.onLine) {
      void pumpQueue();
    }
  };
  window.addEventListener("online", handleOnlineChange);
  window.addEventListener("offline", handleOnlineChange);
  setState({ online: navigator.onLine });
  void refreshCounts();
  if (navigator.onLine) {
    void pumpQueue();
  }
}

/** Bơm hàng đợi theo thứ tự tạo; gặp lỗi thì dừng để giữ thứ tự. */
export async function pumpQueue(): Promise<void> {
  if (typeof window === "undefined" || draining || !navigator.onLine) {
    return;
  }
  if (!getOfflineDb()) {
    return;
  }
  draining = true;
  setState({ syncing: true, lastError: null });
  let syncedAny = false;
  try {
    for (;;) {
      const pending = await listPendingJobs();
      const job = pending[0];
      if (!job || job.id === undefined) {
        break;
      }
      await updateOfflineJob(job.id, {
        status: "syncing",
        attempts: job.attempts + 1,
      });
      const result = await processJob(job);
      if (!result.ok) {
        await updateOfflineJob(job.id, {
          status: "failed",
          lastError: result.error,
        });
        setState({ lastError: result.error });
        break;
      }
      await deleteOfflineJob(job.id);
      syncedAny = true;
    }
  } finally {
    draining = false;
    await refreshCounts();
    setState({
      syncing: false,
      lastSyncedAt: syncedAny ? Date.now() : state.lastSyncedAt,
    });
  }
}

export async function retryFailedJobs(): Promise<void> {
  await retryFailedOfflineJobs();
  await refreshCounts();
  await pumpQueue();
}

export async function discardFailedJobs(): Promise<void> {
  await discardFailedOfflineJobs();
  await refreshCounts();
}

type JobResult = { ok: true } | { ok: false; error: string };

async function processJob(job: OfflineJob): Promise<JobResult> {
  // Job nhận hàng bắt buộc có grId; job kiểm kê bắt buộc có countId.
  if (job.payload.kind !== "count_record" && !job.grId) {
    return { ok: false, error: "Thiếu mã phiếu nhận." };
  }
  if (job.payload.kind === "count_record" && !job.countId) {
    return { ok: false, error: "Thiếu mã đợt kiểm kê." };
  }
  switch (job.payload.kind) {
    case "record":
      return processRecordJob(job);
    case "count_record":
      return processCountRecordJob(job);
    case "override": {
      const grId = job.grId;
      if (!grId) {
        return { ok: false, error: "Thiếu mã phiếu nhận." };
      }
      const res = await overrideReceivingLineAction(job.payload.input);
      if (!res.ok) {
        return { ok: false, error: res.error };
      }
      for (const listener of syncListeners) {
        listener.onOverrideSynced?.({
          grId,
          grLineId: job.payload.input.grLineId,
        });
      }
      return { ok: true };
    }
    case "post": {
      const grId = job.grId;
      if (!grId) {
        return { ok: false, error: "Thiếu mã phiếu nhận." };
      }
      const res = await postReceivingAction(job.payload.input);
      if (res.ok) {
        for (const listener of syncListeners) {
          listener.onPostSynced?.(grId);
        }
        return { ok: true };
      }
      // Ghi sổ có thể đã chạy xong nhưng mất phản hồi (rớt mạng giữa
      // chừng): kiểm tra trạng thái phiếu — đã posted thì coi như xong,
      // không đánh lỗi và không gửi lại.
      const statusRes = await getReceivingReceiptStatusAction(grId);
      if (statusRes.ok && statusRes.data.status === "posted") {
        for (const listener of syncListeners) {
          listener.onPostSynced?.(grId);
        }
        return { ok: true };
      }
      return { ok: false, error: res.error };
    }
  }
}

/**
 * Ghi 1 dòng đếm xếp hàng (T-033): gửi lại cùng clientUuid, server
 * (`count_record_line`, T-032) trả về dòng đã ghi thay vì tạo trùng.
 */
async function processCountRecordJob(job: OfflineJob): Promise<JobResult> {
  if (job.payload.kind !== "count_record") {
    return { ok: false, error: "Loại thao tác không hợp lệ." };
  }
  const countId = job.countId;
  if (!countId) {
    return { ok: false, error: "Thiếu mã đợt kiểm kê." };
  }
  const { input } = job.payload;
  const res = await recordCountLineAction({
    ...input,
    clientUuid: job.clientUuid,
  });
  if (!res.ok) {
    return { ok: false, error: res.error };
  }
  for (const listener of syncListeners) {
    listener.onCountRecordSynced?.({ countId, itemId: input.itemId });
  }
  return { ok: true };
}

async function processRecordJob(job: OfflineJob): Promise<JobResult> {
  if (job.payload.kind !== "record") {
    return { ok: false, error: "Loại thao tác không hợp lệ." };
  }
  const grId = job.grId;
  if (!grId) {
    return { ok: false, error: "Thiếu mã phiếu nhận." };
  }
  const { input } = job.payload;
  // Bản sao để cập nhật tiến trình tải ảnh ngay trong job: gửi lại lần sau
  // chỉ tải những ảnh chưa có attachmentId, không tạo trùng ảnh.
  const photos: QueuedPhoto[] = job.payload.photos.map((photo) => ({
    ...photo,
  }));
  const photoIds: string[] = [];
  for (let i = 0; i < photos.length; i++) {
    const photo = photos[i];
    if (!photo) {
      continue;
    }
    if (photo.attachmentId) {
      photoIds.push(photo.attachmentId);
      continue;
    }
    if (!photo.blob) {
      return { ok: false, error: "Thiếu ảnh chờ tải lên." };
    }
    const uploaded = await uploadCapturedPhoto({
      propertyId: job.propertyId,
      docType: "receiving",
      docId: grId,
      photo: {
        blob: photo.blob,
        sha256: photo.sha256,
        width: photo.width,
        height: photo.height,
        deviceTime: photo.deviceTime,
      },
    });
    if (!uploaded.ok) {
      return { ok: false, error: uploaded.error };
    }
    photoIds.push(uploaded.data.id);
    photos[i] = { ...photo, attachmentId: uploaded.data.id };
    if (job.id !== undefined) {
      await updateOfflineJob(job.id, {
        payload: { kind: "record", input, photos },
      });
    }
  }

  // Gửi lại cùng clientUuid: server (T-023) trả về dòng đã ghi thay vì
  // tạo dòng mới — không trùng dù job được bơm lại nhiều lần.
  const res = await recordReceivingLineAction({
    ...input,
    photoIds,
    clientUuid: job.clientUuid,
  });
  if (!res.ok) {
    return { ok: false, error: res.error };
  }
  for (const listener of syncListeners) {
    listener.onRecordSynced?.({ grId, poLineId: input.poLineId });
  }
  return { ok: true };
}
