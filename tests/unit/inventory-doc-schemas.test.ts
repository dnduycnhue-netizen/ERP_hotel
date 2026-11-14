import { describe, expect, it } from "vitest";
import {
  docLineQtySchema,
  docOpSchema,
  saveDocDraftSchema,
} from "@/features/inventory/doc-schemas";

const P = "b0000000-0000-4000-8000-000000000002";
const W1 = "b0000000-0000-4000-8000-000000000022";
const W2 = "9a467199-e3a2-4d71-be6d-cf0e4ab5ebde";
const O = "c9f21a4b-8446-4009-bde2-5938759b2f74";
const I = "b0000000-0000-4000-8000-000000000011";
const line = { itemId: I, qty: 2 };

describe("saveDocDraftSchema", () => {
  it("hủy hàng cần kho + lý do + ít nhất một dòng", () => {
    expect(
      saveDocDraftSchema.safeParse({ kind: "waste", propertyId: P, lines: [line] }).success,
    ).toBe(false);
    expect(
      saveDocDraftSchema.safeParse({
        kind: "waste",
        propertyId: P,
        warehouseId: W1,
        reasonCode: "expired",
        lines: [line],
      }).success,
    ).toBe(true);
    expect(
      saveDocDraftSchema.safeParse({
        kind: "waste",
        propertyId: P,
        warehouseId: W1,
        reasonCode: "expired",
        lines: [],
      }).success,
    ).toBe(false);
  });

  it("phiếu lĩnh/điều chuyển: kho xuất ≠ kho nhận; phiếu lĩnh cần bộ phận", () => {
    const base = { propertyId: P, fromWarehouseId: W1, toWarehouseId: W2, lines: [line] };
    expect(saveDocDraftSchema.safeParse({ ...base, kind: "transfer" }).success).toBe(true);
    expect(
      saveDocDraftSchema.safeParse({ ...base, kind: "transfer", toWarehouseId: W1 }).success,
    ).toBe(false);
    expect(saveDocDraftSchema.safeParse({ ...base, kind: "requisition" }).success).toBe(false);
    expect(
      saveDocDraftSchema.safeParse({ ...base, kind: "requisition", outletId: O }).success,
    ).toBe(true);
  });

  it("xuất mục đích cần kho + mục đích; mục đích ngoài danh sách bị từ chối", () => {
    const ok = saveDocDraftSchema.safeParse({
      kind: "purpose_issue",
      propertyId: P,
      warehouseId: W1,
      purposeCode: "staff_meal",
      costCenterId: O,
      expenseCategoryId: W2,
      lines: [line],
    });
    expect(ok.success).toBe(true);
    // Thiếu cost center/khoản mục: RPC ghi sổ sẽ từ chối nên form chặn sớm.
    expect(
      saveDocDraftSchema.safeParse({
        kind: "purpose_issue",
        propertyId: P,
        warehouseId: W1,
        purposeCode: "staff_meal",
        lines: [line],
      }).success,
    ).toBe(false);
    const bad = saveDocDraftSchema.safeParse({
      kind: "purpose_issue",
      propertyId: P,
      warehouseId: W1,
      purposeCode: "gift",
      costCenterId: O,
      expenseCategoryId: W2,
      lines: [line],
    });
    expect(bad.success).toBe(false);
  });

  it("số lượng phải dương", () => {
    const r = saveDocDraftSchema.safeParse({
      kind: "waste",
      propertyId: P,
      warehouseId: W1,
      reasonCode: "other",
      lines: [{ itemId: I, qty: 0 }],
    });
    expect(r.success).toBe(false);
  });
});

describe("docOpSchema / docLineQtySchema", () => {
  it("thao tác lạ bị từ chối", () => {
    expect(
      docOpSchema.safeParse({ kind: "waste", op: "delete", propertyId: P, id: I }).success,
    ).toBe(false);
    expect(
      docOpSchema.safeParse({ kind: "waste", op: "submit", propertyId: P, id: I }).success,
    ).toBe(true);
  });
  it("xuất/nhận theo dòng cần ít nhất một dòng và số lượng không âm", () => {
    expect(
      docLineQtySchema.safeParse({ kind: "transfer_send", id: I, lines: [] }).success,
    ).toBe(false);
    expect(
      docLineQtySchema.safeParse({
        kind: "transfer_send",
        id: I,
        lines: [{ lineId: I, qtyStock: -1 }],
      }).success,
    ).toBe(false);
    expect(
      docLineQtySchema.safeParse({
        kind: "requisition_issue",
        id: I,
        lines: [{ lineId: I, qtyStock: 1.5 }],
      }).success,
    ).toBe(true);
  });
});

describe("searchWords (V10-N1)", () => {
  it("tách từ, bỏ dấu kể cả đ, bỏ ký tự đặc biệt của bộ lọc", async () => {
    const { searchWords } = await import("@/lib/text/normalize");
    expect(searchWords("Đường  thẻ")).toEqual(["duong", "the"]);
    expect(searchWords("ba chỉ,nách (x)")).toEqual(["ba", "chi", "nach", "x"]);
    expect(searchWords("   ")).toEqual([]);
  });
});

describe("awaitingReweigh (C2-N1)", () => {
  it("chỉ còn phải cân lại khi lệch ở lần cân 1; sau lần cân 2 thì không", async () => {
    const { awaitingReweigh } = await import("@/components/receiving/reweigh");
    expect(awaitingReweigh({ needs_reweigh: true, weigh_count: 1 })).toBe(true);
    expect(awaitingReweigh({ needs_reweigh: true, weigh_count: 2 })).toBe(false);
    expect(awaitingReweigh({ needs_reweigh: false, weigh_count: 1 })).toBe(false);
    expect(awaitingReweigh(null)).toBe(false);
  });
});
