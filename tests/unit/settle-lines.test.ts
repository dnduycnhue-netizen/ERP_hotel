import { describe, expect, it } from "vitest";
import {
  buildSettleLines,
  canSubmitSettleLines,
  emptySettleFormLine,
  formatReceiptOption,
  sortReceiptsForAdvance,
  type SettleFormLine,
} from "@/features/finance/settle-lines";
import type { ReceiptListRow } from "@/features/receiving/queries";

function receipt(
  overrides: Partial<ReceiptListRow> & { id: string },
): ReceiptListRow {
  return {
    doc_no: "GR-000001",
    po_id: null,
    po_doc_no: null,
    supplier_name: "Nhà cung cấp A",
    status: "posted",
    receiver_id: "00000000-0000-4000-8000-000000000001",
    received_at: "2026-11-10T05:00:00.000Z",
    line_count: 2,
    ...overrides,
  };
}

function line(overrides: Partial<SettleFormLine> = {}): SettleFormLine {
  return { ...emptySettleFormLine(), ...overrides };
}

describe("buildSettleLines", () => {
  it("giữ grId và receiptPhotoId khi dòng có gắn chứng từ", () => {
    expect(
      buildSettleLines([
        line({
          amount: "120000",
          grId: "00000000-0000-4000-8000-000000000010",
          photoId: "00000000-0000-4000-8000-000000000020",
        }),
      ]),
    ).toEqual([
      {
        amount: 120000,
        grId: "00000000-0000-4000-8000-000000000010",
        receiptPhotoId: "00000000-0000-4000-8000-000000000020",
      },
    ]);
  });

  it("dòng không gắn chứng từ thành null (RPC chấp nhận, Q74)", () => {
    expect(buildSettleLines([line({ amount: "50000" })])).toEqual([
      { amount: 50000, grId: null, receiptPhotoId: null },
    ]);
  });

  it("parse số tiền từ chuỗi nhập ở form", () => {
    expect(buildSettleLines([line({ amount: "120000.5" })])[0]?.amount).toBe(
      120000.5,
    );
  });
});

describe("canSubmitSettleLines", () => {
  it("chặn khi chưa có dòng nào hoặc đang gửi", () => {
    expect(canSubmitSettleLines([], false)).toBe(false);
    expect(canSubmitSettleLines([line({ amount: "1000" })], true)).toBe(false);
  });

  it("chặn khi có dòng chưa nhập tiền hoặc tiền <= 0", () => {
    expect(
      canSubmitSettleLines(
        [line({ amount: "1000" }), line({ amount: "" })],
        false,
      ),
    ).toBe(false);
    expect(canSubmitSettleLines([line({ amount: "0" })], false)).toBe(false);
    expect(canSubmitSettleLines([line({ amount: "-5" })], false)).toBe(false);
  });

  it("chặn khi có dòng đang tải ảnh lên", () => {
    expect(
      canSubmitSettleLines([line({ amount: "1000", uploading: true })], false),
    ).toBe(false);
  });

  it("cho gửi khi mọi dòng có tiền > 0 và không tải ảnh", () => {
    expect(
      canSubmitSettleLines(
        [
          line({ amount: "1000" }),
          line({
            amount: "2000",
            grId: "00000000-0000-4000-8000-000000000010",
          }),
        ],
        false,
      ),
    ).toBe(true);
  });
});

describe("sortReceiptsForAdvance", () => {
  const poId = "00000000-0000-4000-8000-000000000100";
  const rows = [
    receipt({
      id: "00000000-0000-4000-8000-000000000001",
      doc_no: "GR-1",
      po_id: "00000000-0000-4000-8000-000000000101",
      received_at: "2026-11-10T05:00:00.000Z",
    }),
    receipt({
      id: "00000000-0000-4000-8000-000000000002",
      doc_no: "GR-2",
      po_id: poId,
      received_at: "2026-11-09T05:00:00.000Z",
    }),
    receipt({
      id: "00000000-0000-4000-8000-000000000003",
      doc_no: "GR-3",
      po_id: poId,
      received_at: "2026-11-10T05:00:00.000Z",
    }),
  ];

  it("đưa phiếu của PO tạm ứng lên trước, mới nhất trước", () => {
    expect(sortReceiptsForAdvance(rows, poId).map((r) => r.doc_no)).toEqual([
      "GR-3",
      "GR-2",
      "GR-1",
    ]);
  });

  it("không có PO thì giữ nguyên thứ tự API trả về", () => {
    expect(sortReceiptsForAdvance(rows, null).map((r) => r.doc_no)).toEqual([
      "GR-1",
      "GR-2",
      "GR-3",
    ]);
  });
});

describe("formatReceiptOption", () => {
  it("gồm số phiếu, PO, nhà cung cấp và ngày nhận (giờ VN)", () => {
    expect(
      formatReceiptOption(
        receipt({
          id: "00000000-0000-4000-8000-000000000001",
          doc_no: "GR-000123",
          po_id: "00000000-0000-4000-8000-000000000100",
          po_doc_no: "PO-00045",
          supplier_name: "Chợ Cồn",
        }),
      ),
    ).toBe("GR-000123 · PO PO-00045 · Chợ Cồn · 10/11/2026");
  });

  it("bỏ phần PO khi phiếu không gắn PO nào", () => {
    expect(
      formatReceiptOption(
        receipt({
          id: "00000000-0000-4000-8000-000000000001",
          doc_no: "GR-000124",
        }),
      ),
    ).toBe("GR-000124 · Nhà cung cấp A · 10/11/2026");
  });
});
