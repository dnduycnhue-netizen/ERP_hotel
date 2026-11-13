import "fake-indexeddb/auto";
import { beforeEach, describe, expect, it, vi } from "vitest";

/**
 * Dong bo offline kiem minibar (Q152, M-03) — tang don vi.
 * Mock cac server action (khong chay duoc trong Node) roi test
 * `pumpQueue` trong src/lib/offline/sync.ts that: goi dung
 * `submitCheckAction`, xoa job sau khi xong, loi server thi job
 * `failed` + `lastError`, giu thu tu job.
 *
 * Luu y: `navigator` cua Node co san nhung khong ghi de duoc bang
 * phep gan (`navigator.onLine` la `undefined`) — test phai dung
 * `Object.defineProperty` de dieu khien trang thai online.
 */

// Shim trinh duyet truoc khi dung db.ts / sync.ts.
(globalThis as unknown as { window: unknown }).window = globalThis;

function setOnline(value: boolean): void {
  Object.defineProperty(globalThis, "navigator", {
    value: { onLine: value },
    configurable: true,
  });
}

const { submitCheckMock, recordCountLineMock } = vi.hoisted(() => ({
  submitCheckMock: vi.fn(),
  recordCountLineMock: vi.fn(),
}));

vi.mock("@/features/minibar/actions", () => ({
  submitCheckAction: (...args: unknown[]) => submitCheckMock(...args),
}));
vi.mock("@/features/count/actions", () => ({
  recordCountLineAction: (...args: unknown[]) =>
    recordCountLineMock(...args),
}));
vi.mock("@/features/receiving/actions", () => ({
  getReceivingReceiptStatusAction: vi.fn(),
  overrideReceivingLineAction: vi.fn(),
  postReceivingAction: vi.fn(),
  recordReceivingLineAction: vi.fn(),
}));
vi.mock("@/features/trolley/actions", () => ({
  closeTrolleyShiftAction: vi.fn(),
  getTrolleyShiftAction: vi.fn(),
  listOpenTrolleyShiftAction: vi.fn(),
  openTrolleyShiftAction: vi.fn(),
}));
vi.mock("@/features/attachments/upload-client", () => ({
  uploadCapturedPhoto: vi.fn(),
}));

import {
  countOfflineJobsByStatus,
  enqueueOfflineJob,
  getOfflineDb,
  listPendingJobs,
  type OfflineJob,
} from "@/lib/offline/db";
import { addSyncListener, pumpQueue } from "@/lib/offline/sync";

const PROPERTY_ID = "11111111-1111-4111-8111-111111111111";
const CHECK_ID = "22222222-2222-4222-8222-222222222222";
const ITEM_ID = "33333333-3333-4333-8333-333333333333";
const COUNT_ID = "44444444-4444-4444-8444-444444444444";
const CLIENT_UUID = "55555555-5555-4555-8555-555555555555";

function minibarJob(
  createdAt: number,
  clientUuid: string | null = CLIENT_UUID,
): Omit<OfflineJob, "id" | "status" | "attempts" | "lastError"> {
  return {
    propertyId: PROPERTY_ID,
    grId: null,
    countId: null,
    kind: "minibar_submit",
    clientUuid,
    payload: {
      kind: "minibar_submit",
      input: {
        propertyId: PROPERTY_ID,
        checkId: CHECK_ID,
        lines: [{ itemId: ITEM_ID, missingQty: 2, nearExpiry: false }],
        clientUuid: clientUuid ?? "",
      },
    },
    createdAt,
  };
}

function countJob(createdAt: number): Omit<
  OfflineJob,
  "id" | "status" | "attempts" | "lastError"
> {
  return {
    propertyId: PROPERTY_ID,
    grId: null,
    countId: COUNT_ID,
    kind: "count_record",
    clientUuid: CLIENT_UUID,
    payload: {
      kind: "count_record",
      input: {
        countId: COUNT_ID,
        itemId: ITEM_ID,
        detail: [{ qty: 1, uom: "cai" }],
        bottleWeightG: null,
        clientUuid: CLIENT_UUID,
      },
    },
    createdAt,
  };
}

beforeEach(async () => {
  setOnline(true);
  vi.clearAllMocks();
  submitCheckMock.mockResolvedValue({
    ok: true,
    data: {
      ok: true,
      id: CHECK_ID,
      doc_no: "MB-0001",
      status: "submitted",
      total_amount: 15000,
      is_loss: false,
      duplicate: false,
    },
  });
  recordCountLineMock.mockResolvedValue({ ok: true, data: {} });
  const db = getOfflineDb();
  expect(db).not.toBeNull();
  await db?.jobs.clear();
});

describe("dong bo offline kiem minibar (Q152)", () => {
  it("S1 — mat mang: job xep hang, pumpQueue khong bom", async () => {
    await enqueueOfflineJob(minibarJob(1000));
    setOnline(false);
    await pumpQueue();
    expect(submitCheckMock).not.toHaveBeenCalled();
    const pending = await listPendingJobs();
    expect(pending).toHaveLength(1);
    expect(pending[0]?.kind).toBe("minibar_submit");
    expect(pending[0]?.status).toBe("pending");
    expect(pending[0]?.clientUuid).toBe(CLIENT_UUID);
  });

  it("S2 — pumpQueue goi submitCheckAction dung tham so va xoa job", async () => {
    const synced: { checkId: string }[] = [];
    const unsub = addSyncListener({
      onMinibarSubmitSynced: (info) => synced.push(info),
    });
    await enqueueOfflineJob(minibarJob(1000));
    await pumpQueue();
    expect(submitCheckMock).toHaveBeenCalledTimes(1);
    expect(submitCheckMock).toHaveBeenCalledWith({
      propertyId: PROPERTY_ID,
      checkId: CHECK_ID,
      lines: [{ itemId: ITEM_ID, missingQty: 2, nearExpiry: false }],
      clientUuid: CLIENT_UUID,
    });
    expect(await listPendingJobs()).toHaveLength(0);
    expect(await countOfflineJobsByStatus("pending")).toBe(0);
    expect(synced).toEqual([{ checkId: CHECK_ID }]);
    unsub();
  });

  it("S3 — bom lai sau khi xong khong gui lai (khong tao job thu hai)", async () => {
    await enqueueOfflineJob(minibarJob(1000));
    await pumpQueue();
    await pumpQueue();
    expect(submitCheckMock).toHaveBeenCalledTimes(1);
    expect(await listPendingJobs()).toHaveLength(0);
  });

  it("S4 — hai job cung clientUuid (bam nop 2 lan khi offline) deu duoc bom, server tra duplicate lan 2", async () => {
    submitCheckMock
      .mockResolvedValueOnce({
        ok: true,
        data: {
          ok: true,
          id: CHECK_ID,
          doc_no: "MB-0001",
          status: "submitted",
          total_amount: 15000,
          is_loss: false,
          duplicate: false,
        },
      })
      .mockResolvedValueOnce({
        ok: true,
        data: {
          ok: true,
          id: CHECK_ID,
          doc_no: "MB-0001",
          status: "submitted",
          total_amount: 15000,
          is_loss: false,
          duplicate: true,
        },
      });
    // Tang DB khong chan trung clientUuid (xem U2): chong trung la
    // viec cua server — RPC tra `duplicate` thay vi ghi trung.
    await enqueueOfflineJob(minibarJob(1000));
    await enqueueOfflineJob(minibarJob(2000));
    await pumpQueue();
    expect(submitCheckMock).toHaveBeenCalledTimes(2);
    expect(await listPendingJobs()).toHaveLength(0);
    expect(await countOfflineJobsByStatus("failed")).toBe(0);
  });

  it("S5 — loi server: job failed + lastError, job sau khong bi bom", async () => {
    submitCheckMock.mockResolvedValue({
      ok: false,
      error: "ERR_PRICE_NOT_SET",
    });
    await enqueueOfflineJob(minibarJob(1000));
    await enqueueOfflineJob(countJob(2000));
    await pumpQueue();
    expect(submitCheckMock).toHaveBeenCalledTimes(1);
    expect(recordCountLineMock).not.toHaveBeenCalled();
    expect(await countOfflineJobsByStatus("failed")).toBe(1);
    expect(await countOfflineJobsByStatus("pending")).toBe(1);
    const db = getOfflineDb();
    const failed = await db?.jobs
      .where("status")
      .equals("failed")
      .toArray();
    expect(failed).toHaveLength(1);
    expect(failed?.[0]?.kind).toBe("minibar_submit");
    expect(failed?.[0]?.lastError).toBe("ERR_PRICE_NOT_SET");
    const pending = await listPendingJobs();
    expect(pending).toHaveLength(1);
    expect(pending[0]?.kind).toBe("count_record");
  });

  it("S6 — thu tu job: bom theo createdAt", async () => {
    await enqueueOfflineJob(countJob(1000));
    await enqueueOfflineJob(minibarJob(2000));
    await pumpQueue();
    expect(recordCountLineMock).toHaveBeenCalledTimes(1);
    expect(submitCheckMock).toHaveBeenCalledTimes(1);
    expect(
      recordCountLineMock.mock.invocationCallOrder[0] ?? 0,
    ).toBeLessThan(submitCheckMock.mock.invocationCallOrder[0] ?? 0);
    expect(await listPendingJobs()).toHaveLength(0);
  });
});
