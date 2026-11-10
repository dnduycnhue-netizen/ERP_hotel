import { describe, expect, it } from "vitest";
import {
  enqueueOfflineJob,
  getOfflineDb,
  listPendingJobs,
} from "@/lib/offline/db";

/**
 * Queue offline o phia server (khong co window/indexedDB):
 * getOfflineDb tra null, enqueue nem loi ro, list tra rong.
 * Chay trong worker rieng (khong co shim window nhu offline-queue.test.ts).
 */
describe("offline queue (phía server)", () => {
  it("U6 — getOfflineDb trả null khi không có window", () => {
    expect(getOfflineDb()).toBeNull();
  });

  it("U7 — enqueue ném lỗi rõ ràng khi queue không khả dụng", async () => {
    await expect(
      enqueueOfflineJob({
        propertyId: "test-property",
        grId: "11111111-1111-4111-8111-111111111111",
        countId: null,
        kind: "post",
        clientUuid: null,
        payload: {
          kind: "post",
          input: {
            grId: "11111111-1111-4111-8111-111111111111",
            pin: "1234",
          },
        },
        createdAt: 1000,
      }),
    ).rejects.toThrow("Offline queue unavailable");
  });

  it("U8 — listPendingJobs trả rỗng khi không có window", async () => {
    await expect(listPendingJobs()).resolves.toEqual([]);
  });
});
