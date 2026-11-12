import Dexie, { type Table } from "dexie";
import type { CountRecordLineInput } from "@/features/count/schemas";
import type { MinibarSubmitCheckInput } from "@/features/minibar/schemas";
import type {
  ReceivingOverrideLineInput,
  ReceivingPostInput,
  ReceivingRecordLineInput,
} from "@/features/receiving/schemas";
import type {
  TrolleyShiftCloseInput,
  TrolleyShiftOpenInput,
} from "@/features/trolley/schemas";

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

export type OfflineJobKind =
  | "record"
  | "override"
  | "post"
  | "count_record"
  | "trolley_open"
  | "trolley_close"
  | "minibar_submit";
export type OfflineJobStatus = "pending" | "syncing" | "failed";

export type OfflineJobPayload =
  | {
      kind: "record";
      input: ReceivingRecordLineInput;
      photos: QueuedPhoto[];
    }
  | { kind: "override"; input: ReceivingOverrideLineInput }
  | { kind: "post"; input: ReceivingPostInput }
  | { kind: "count_record"; input: CountRecordLineInput }
  | { kind: "trolley_open"; input: TrolleyShiftOpenInput }
  | { kind: "trolley_close"; input: TrolleyShiftCloseInput }
  | { kind: "minibar_submit"; input: MinibarSubmitCheckInput };

/**
 * Nháp số đếm xe đẩy đang nhập dở (mở ca / đóng ca). Số đếm lưu dạng
 * chuỗi như trên NumPad ("" = chưa đếm) để không mất khi mất mạng,
 * tải lại trang hay chuyển màn. Nháp bị xóa khi ca đã mở/đóng xong
 * (online hoặc đồng bộ xong). Khác với hàng đợi `jobs` (thao tác đã
 * gửi chờ đồng bộ), nháp là dữ liệu chưa gửi.
 */
export type TrolleyDraftKind = "open" | "close";

export type TrolleyDraft = {
  id?: number;
  /** open:${propertyId}:${trolleyWh}:${shift}:${businessDate} | close:${shiftId} */
  key: string;
  propertyId: string;
  shiftId: string | null;
  trolleyWh: string | null;
  shift: string | null;
  businessDate: string | null;
  kind: TrolleyDraftKind;
  counts: Array<{ itemId: string; qty: string }>;
  roomsDone: Array<{ roomId: string; cleanType: string; guests: string }>;
  updatedAt: number;
};

/**
 * Một thao tác nhận hàng / kiểm kê xếp hàng chờ đồng bộ (T-025, T-033).
 * `clientUuid` cố định từ lúc xếp hàng: gửi lại cùng key, server
 * (`receiving_start` / `receiving_record_line` / `count_record_line`,
 * T-023/T-032) trả về dòng cũ thay vì tạo trùng. Job `post` không có
 * idempotency key phía server — đồng bộ lại kiểm tra trạng thái phiếu
 * trước khi đánh lỗi.
 */
export type OfflineJob = {
  id?: number;
  propertyId: string;
  /** Phiếu nhận (job nhận hàng); null với job kiểm kê. */
  grId: string | null;
  /** Đợt kiểm kê (job kiểm kê); null với job nhận hàng. */
  countId: string | null;
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
  trolleyDrafts!: Table<TrolleyDraft, number>;

  constructor() {
    super("erp-hotel-offline");
    this.version(1).stores({
      jobs: "++id, propertyId, grId, status, createdAt",
    });
    // v2: thêm bảng nháp đếm xe đẩy (giữ nguyên dữ liệu bảng jobs).
    this.version(2).stores({
      jobs: "++id, propertyId, grId, status, createdAt",
      trolleyDrafts: "++id, key, propertyId, shiftId, updatedAt",
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

/** Nháp đếm xe đẩy theo khóa (mở ca: theo xe + ca + ngày; đóng ca: theo ca). */
export async function getTrolleyDraft(
  key: string,
): Promise<TrolleyDraft | undefined> {
  const d = getOfflineDb();
  if (!d) {
    return undefined;
  }
  return d.trolleyDrafts.where("key").equals(key).first();
}

/** Lưu (upsert theo khóa) nháp đếm xe đẩy. */
export async function saveTrolleyDraft(
  draft: Omit<TrolleyDraft, "id">,
): Promise<void> {
  const d = getOfflineDb();
  if (!d) {
    return;
  }
  const existing = await d.trolleyDrafts.where("key").equals(draft.key).first();
  if (existing?.id !== undefined) {
    await d.trolleyDrafts.update(existing.id, draft);
    return;
  }
  await d.trolleyDrafts.add(draft);
}

/** Xóa nháp đếm xe đẩy (sau khi ca đã mở/đóng xong). */
export async function deleteTrolleyDraft(key: string): Promise<void> {
  const d = getOfflineDb();
  if (!d) {
    return;
  }
  await d.trolleyDrafts.where("key").equals(key).delete();
}
