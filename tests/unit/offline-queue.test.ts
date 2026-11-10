import "fake-indexeddb/auto";
import { beforeEach, describe, expect, it } from "vitest";

/**
 * Hang doi offline Dexie (T-025/T-033) — tang don vi (11-TESTING.md §1).
 * Chi test lop queue (src/lib/offline/db.ts): thu tu FIFO, cho phep
 * trung clientUuid (chong trung la viec cua server), retry/discard.
 * Khong test pumpQueue o day: sync.ts goi server actions (Next.js)
 * nen khong chay duoc trong Node — dong bo that do Playwright W5
 * kiem chung tren trinh duyet.
 */

// Shim window truoc khi dung db.ts (getOfflineDb kiem tra window).
(globalThis as unknown as { window: unknown }).window = globalThis;

import {
  countOfflineJobsByStatus,
  deleteOfflineJob,
  discardFailedOfflineJobs,
  enqueueOfflineJob,
  getOfflineDb,
  listPendingJobs,
  retryFailedOfflineJobs,
  updateOfflineJob,
  type OfflineJob,
} from "@/lib/offline/db";

const GR_ID = "11111111-1111-4111-8111-111111111111";
const PO_LINE_ID = "22222222-2222-4222-8222-222222222222";
const ITEM_ID = "33333333-3333-4333-8333-333333333333";
const COUNT_ID = "44444444-4444-4444-8444-444444444444";
const CLIENT_UUID = "55555555-5555-4555-8555-555555555555";

function recordJob(
  createdAt: number,
  clientUuid: string | null = CLIENT_UUID,
): Omit<OfflineJob, "id" | "status" | "attempts" | "lastError"> {
  return {
    propertyId: "test-property",
    grId: GR_ID,
    countId: null,
    kind: "record",
    clientUuid,
    payload: {
      kind: "record",
      input: {
        grId: GR_ID,
        poLineId: PO_LINE_ID,
        itemId: ITEM_ID,
        gross: 10,
        tare: 0,
        uom: "kg",
        qc: {
          status: "pass",
          checklist: [],
          temperature_c: null,
          reason: null,
        },
        lot: null,
        expiry: null,
        photoIds: [],
        clientUuid,
      },
      photos: [],
    },
    createdAt,
  };
}

beforeEach(async () => {
  const db = getOfflineDb();
  expect(db).not.toBeNull();
  await db?.jobs.clear();
});

describe("offline queue (Dexie)", () => {
  it("U1 — bơm theo thứ tự tạo (record → override → post)", async () => {
    await enqueueOfflineJob(recordJob(1000));
    const overrideId = await enqueueOfflineJob({
      propertyId: "test-property",
      grId: GR_ID,
      countId: null,
      kind: "override",
      clientUuid: null,
      payload: {
        kind: "override",
        input: {
          grLineId: "66666666-6666-4666-8666-666666666666",
          reason: "Vượt PO do cân sai",
        },
      },
      createdAt: 2000,
    });
    await enqueueOfflineJob({
      propertyId: "test-property",
      grId: GR_ID,
      countId: null,
      kind: "post",
      clientUuid: null,
      payload: { kind: "post", input: { grId: GR_ID, pin: "1234" } },
      createdAt: 3000,
    });
    expect(overrideId).toBeGreaterThan(0);
    const pending = await listPendingJobs();
    expect(pending.map((j) => j.kind)).toEqual(["record", "override", "post"]);
    expect(pending.map((j) => j.createdAt)).toEqual([1000, 2000, 3000]);
  });

  it("U2 — cùng clientUuid được xếp hàng 2 lần (chống trùng là việc server)", async () => {
    await enqueueOfflineJob(recordJob(1000, CLIENT_UUID));
    await enqueueOfflineJob(recordJob(2000, CLIENT_UUID));
    const pending = await listPendingJobs();
    expect(pending).toHaveLength(2);
    expect(pending.map((j) => j.clientUuid)).toEqual([
      CLIENT_UUID,
      CLIENT_UUID,
    ]);
  });

  it("U3 — job lỗi → retry về pending, lỗi cũ được xóa", async () => {
    const id = await enqueueOfflineJob(recordJob(1000));
    await updateOfflineJob(id, { status: "failed", lastError: "ERR_NETWORK" });
    expect(await countOfflineJobsByStatus("failed")).toBe(1);
    await retryFailedOfflineJobs();
    expect(await countOfflineJobsByStatus("failed")).toBe(0);
    expect(await countOfflineJobsByStatus("pending")).toBe(1);
    const pending = await listPendingJobs();
    expect(pending[0]?.lastError).toBeNull();
  });

  it("U4 — job lỗi → discard thì mất khỏi hàng đợi", async () => {
    const id = await enqueueOfflineJob(recordJob(1000));
    await updateOfflineJob(id, { status: "failed", lastError: "ERR_NETWORK" });
    await discardFailedOfflineJobs();
    expect(await countOfflineJobsByStatus("failed")).toBe(0);
    expect(await countOfflineJobsByStatus("pending")).toBe(0);
    expect(await listPendingJobs()).toHaveLength(0);
  });

  it("U5 — đếm theo trạng thái + xóa 1 job", async () => {
    const id1 = await enqueueOfflineJob(recordJob(1000));
    await enqueueOfflineJob({
      propertyId: "test-property",
      grId: null,
      countId: COUNT_ID,
      kind: "count_record",
      clientUuid: CLIENT_UUID,
      payload: {
        kind: "count_record",
        input: {
          countId: COUNT_ID,
          itemId: ITEM_ID,
          detail: null,
          bottleWeightG: null,
          clientUuid: CLIENT_UUID,
        },
      },
      createdAt: 2000,
    });
    await deleteOfflineJob(id1);
    expect(await countOfflineJobsByStatus("pending")).toBe(1);
    const pending = await listPendingJobs();
    expect(pending[0]?.kind).toBe("count_record");
  });
});
