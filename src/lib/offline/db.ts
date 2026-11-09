import Dexie, { type Table } from "dexie";
import type {
  ReceivingOverrideLineInput,
  ReceivingPostInput,
  ReceivingRecordLineInput,
} from "@/features/receiving/schemas";

/**
 * Ảnh chụp khi offline, nằm trong payload của job record (T-025).
 * Ảnh đã tải lên server trước khi xếp hàng thì `blob` null — chỉ còn
 * `attachmentId` để đưa vào `receiving_record_line`.
 */
export type QueuedPhoto = {
  blob: Blob | null;
  sha256: string;
  width: number;
  height: number;
  deviceTime: string;
  /** attachmentId trên server; null = chưa tải lên. */
  attachmentId: string | null;
};

export type OfflineJobKind = "record" | "override" | "post";
export type OfflineJobStatus = "pending" | "syncing" | "failed";

export type OfflineJobPayload =
  | {
      kind: "record";
      input: ReceivingRecordLineInput;
      photos: QueuedPhoto[];
    }
  | { kind: "override"; input: ReceivingOverrideLineInput }
  | { kind: "post"; input: ReceivingPostInput };

/**
 * Một thao tác nhận hàng xếp hàng chờ đồng bộ (T-025).
 * `clientUuid` cố định từ lúc xếp hàng: gửi lại cùng key, server
 * (`receiving_start` / `receiving_record_line`, T-023) trả về dòng cũ
 * thay vì tạo trùng. Job `post` không có idempotency key phía server —
 * đồng bộ lại kiểm tra trạng thái phiếu trước khi đánh lỗi.
 */
export type OfflineJob = {
  id?: number;
  propertyId: string;
  grId: string;
  kind: OfflineJobKind;
  status: OfflineJobStatus;
  clientUuid: string | null;
  payload: OfflineJobPayload;
  createdAt: number;
  attempts: number;
  lastError: string | null;
};

class OfflineDb extends Dexie {
  jobs!: Table<OfflineJob, number>;

  constructor() {
    super("erp-hotel-offline");
    this.version(1).stores({
      jobs: "++id, propertyId, grId, status, createdAt",
    });
  }
}

let db: OfflineDb | null = null;

/** Lazy singleton — không chạm IndexedDB khi render phía server. */
export function getOfflineDb(): OfflineDb | null {
  if (typeof window === "undefined" || typeof indexedDB === "undefined") {
    return null;
  }
  db ??= new OfflineDb();
  return db;
}

export async function enqueueOfflineJob(
  job: Omit<OfflineJob, "id" | "status" | "attempts" | "lastError">,
): Promise<number> {
  const d = getOfflineDb();
  if (!d) {
    throw new Error("Offline queue unavailable");
  }
  return d.jobs.add({
    ...job,
    status: "pending",
    attempts: 0,
    lastError: null,
  });
}

/** Job chờ đồng bộ, cũ nhất trước — giữ thứ tự record → override → post. */
export async function listPendingJobs(): Promise<OfflineJob[]> {
  const d = getOfflineDb();
  if (!d) {
    return [];
  }
  return d.jobs.where("status").equals("pending").sortBy("createdAt");
}

export async function countOfflineJobsByStatus(
  status: OfflineJobStatus,
): Promise<number> {
  const d = getOfflineDb();
  if (!d) {
    return 0;
  }
  return d.jobs.where("status").equals(status).count();
}

export async function updateOfflineJob(
  id: number,
  patch: Partial<OfflineJob>,
): Promise<void> {
  const d = getOfflineDb();
  if (!d) {
    return;
  }
  await d.jobs.update(id, patch);
}

export async function deleteOfflineJob(id: number): Promise<void> {
  const d = getOfflineDb();
  if (!d) {
    return;
  }
  await d.jobs.delete(id);
}

export async function retryFailedOfflineJobs(): Promise<void> {
  const d = getOfflineDb();
  if (!d) {
    return;
  }
  await d.jobs
    .where("status")
    .equals("failed")
    .modify({ status: "pending", lastError: null });
}

export async function discardFailedOfflineJobs(): Promise<void> {
  const d = getOfflineDb();
  if (!d) {
    return;
  }
  await d.jobs.where("status").equals("failed").delete();
}
