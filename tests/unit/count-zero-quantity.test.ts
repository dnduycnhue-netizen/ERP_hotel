import "fake-indexeddb/auto";
import { beforeEach, describe, expect, it } from "vitest";

// Shim window truoc khi dung db.ts (getOfflineDb kiem tra window).
(globalThis as unknown as { window: unknown }).window = globalThis;

import {
  calcBottleTotal,
  calcUomTotal,
  parseDecimal,
} from "@/components/count/count-utils";
import {
  countDetailItemSchema,
  countRecordLineSchema,
} from "@/features/count/schemas";
import {
  enqueueOfflineJob,
  getOfflineDb,
  listPendingJobs,
} from "@/lib/offline/db";

/**
 * R30 — dem so 0 (het hang) tren form mobile (tang don vi).
 * - parseDecimal/calcUomTotal/calcBottleTotal: 0 la gia tri hop le, chi
 *   null (chua nhap / nhap sai) moi khong cho luu.
 * - Zod countDetailItemSchema: qty 0 qua, so am van bi chan.
 * - Hang doi offline Dexie: job count_record giu nguyen qty 0 khi luu
 *   va doc lai (khong roi thanh rong/undefined).
 */

const COUNT_ID = "44444444-4444-4444-8444-444444444444";
const ITEM_ID = "33333333-3333-4333-8333-333333333333";
const CLIENT_UUID = "55555555-5555-4555-8555-555555555555";

describe("parseDecimal (R30)", () => {
  it("tra ve 0 cho chuoi '0' — khong coi la rong", () => {
    expect(parseDecimal("0")).toBe(0);
    expect(parseDecimal("0.0")).toBe(0);
  });

  it("tra ve null khi chua nhap hoac nhap sai", () => {
    expect(parseDecimal("")).toBeNull();
    expect(parseDecimal("-")).toBeNull();
    expect(parseDecimal(".")).toBeNull();
    expect(parseDecimal("-.")).toBeNull();
    expect(parseDecimal("abc")).toBeNull();
  });

  it("tra ve so cho chuoi hop le", () => {
    expect(parseDecimal("10")).toBe(10);
    expect(parseDecimal("0.5")).toBe(0.5);
    expect(parseDecimal("10.")).toBe(10);
  });
});

describe("calcUomTotal (R30)", () => {
  it("tra ve null khi khong co dong nao nhap so", () => {
    expect(calcUomTotal([])).toBeNull();
    expect(calcUomTotal([{ qty: null, factor: 1 }])).toBeNull();
    expect(
      calcUomTotal([
        { qty: null, factor: 1 },
        { qty: null, factor: 2 },
      ]),
    ).toBeNull();
  });

  it("tra ve 0 khi co dong nhap 0 (het hang)", () => {
    expect(calcUomTotal([{ qty: 0, factor: 1 }])).toBe(0);
    expect(
      calcUomTotal([
        { qty: 0, factor: 1 },
        { qty: null, factor: 1 },
      ]),
    ).toBe(0);
  });

  it("cong dung nhieu dong, ke ca dong 0", () => {
    expect(
      calcUomTotal([
        { qty: 10, factor: 1 },
        { qty: 5, factor: 2 },
      ]),
    ).toBe(20);
    expect(
      calcUomTotal([
        { qty: 0, factor: 1 },
        { qty: 3, factor: 1000 },
      ]),
    ).toBe(3000);
  });

  it("tra ve null khi dong da nhap so nhung khong ro he so quy doi", () => {
    expect(calcUomTotal([{ qty: 5, factor: null }])).toBeNull();
    expect(
      calcUomTotal([
        { qty: 0, factor: 1 },
        { qty: 2, factor: null },
      ]),
    ).toBeNull();
  });
});

describe("calcBottleTotal (R30, §6.3)", () => {
  const base = {
    tareG: 450,
    densityGml: 0.95,
    defaultFactor: 700,
    mlFactor: 1,
  };

  it("tra ve null khi chua nhap gi (ca 2 o deu trong)", () => {
    expect(
      calcBottleTotal({ ...base, fullBottles: null, openGrams: null }),
    ).toEqual({ openMl: null, total: null });
  });

  it("tra ve total 0 khi nhap 0 chai nguyen va khong can chai mo", () => {
    expect(
      calcBottleTotal({ ...base, fullBottles: 0, openGrams: null }),
    ).toEqual({ openMl: null, total: 0 });
  });

  it("chai mo can dung bang bi (0 ml) la hop le, total 0", () => {
    expect(
      calcBottleTotal({ ...base, fullBottles: 0, openGrams: 450 }),
    ).toEqual({ openMl: 0, total: 0 });
  });

  it("gram chai mo nho hon bi (ml am) la nhap sai -> total null", () => {
    const res = calcBottleTotal({
      ...base,
      fullBottles: 1,
      openGrams: 100,
    });
    expect(res.openMl).toBeLessThan(0);
    expect(res.total).toBeNull();
  });

  it("tinh dung tong khi co ca chai nguyen va chai mo", () => {
    // 1 chai nguyen (700 ml) + chai mo (800 - 450) / 0.95 = 368.42 ml.
    const res = calcBottleTotal({
      ...base,
      fullBottles: 1,
      openGrams: 800,
    });
    expect(res.openMl).toBeCloseTo(368.4211, 3);
    expect(res.total).toBeCloseTo(1068.4211, 3);
  });

  it("tra ve null khi chai mo > 0 ml nhung khong co he so ml", () => {
    const res = calcBottleTotal({
      ...base,
      fullBottles: null,
      openGrams: 800,
      mlFactor: null,
    });
    expect(res.total).toBeNull();
  });
});

describe("countDetailItemSchema (R30)", () => {
  it("chap nhan qty 0", () => {
    expect(countDetailItemSchema.safeParse({ qty: 0, uom: "kg" }).success).toBe(
      true,
    );
    expect(
      countRecordLineSchema.safeParse({
        countId: COUNT_ID,
        itemId: ITEM_ID,
        detail: [{ qty: 0, uom: "kg" }],
        bottleWeightG: null,
        clientUuid: CLIENT_UUID,
      }).success,
    ).toBe(true);
  });

  it("van tu choi qty am", () => {
    expect(countDetailItemSchema.safeParse({ qty: -1, uom: "kg" }).success).toBe(
      false,
    );
    expect(
      countRecordLineSchema.safeParse({
        countId: COUNT_ID,
        itemId: ITEM_ID,
        detail: [{ qty: -1, uom: "kg" }],
        bottleWeightG: null,
        clientUuid: CLIENT_UUID,
      }).success,
    ).toBe(false);
  });
});

describe("hang doi offline giu qty 0 (R30)", () => {
  beforeEach(async () => {
    const d = getOfflineDb();
    if (d) {
      await d.jobs.clear();
    }
  });

  it("job count_record luu va doc lai dung detail qty 0", async () => {
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
          detail: [{ qty: 0, uom: "kg" }],
          bottleWeightG: null,
          clientUuid: CLIENT_UUID,
        },
      },
      createdAt: Date.now(),
    });
    const jobs = await listPendingJobs();
    expect(jobs).toHaveLength(1);
    const job = jobs[0];
    expect(job).toBeDefined();
    if (job?.payload.kind !== "count_record") {
      throw new Error("expected count_record job");
    }
    const detail = job.payload.input.detail;
    expect(Array.isArray(detail)).toBe(true);
    expect(detail).toEqual([{ qty: 0, uom: "kg" }]);
  });

  it("job count_record nhieu dong giu ca dong 0 lan dong co so", async () => {
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
          detail: [
            { qty: 0, uom: "kg" },
            { qty: 5, uom: "thung" },
          ],
          bottleWeightG: null,
          clientUuid: CLIENT_UUID,
        },
      },
      createdAt: Date.now(),
    });
    const jobs = await listPendingJobs();
    expect(jobs).toHaveLength(1);
    const job = jobs[0];
    if (job?.payload.kind !== "count_record") {
      throw new Error("expected count_record job");
    }
    expect(job.payload.input.detail).toEqual([
      { qty: 0, uom: "kg" },
      { qty: 5, uom: "thung" },
    ]);
  });
});
