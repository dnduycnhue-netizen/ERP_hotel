import { describe, expect, it } from "vitest";

import {
  advanceSettleLineSchema,
  advanceSettleSchema,
  invoiceApproveSchema,
  invoiceMatchSchema,
  invoiceSaveDraftSchema,
  invoiceSaveLineSchema,
  noInvoiceListingLineSchema,
  noInvoiceListingSaveSchema,
  paymentMarkPaidSchema,
  paymentRequestCreateSchema,
  paymentRequestDecideSchema,
  paymentRequestLineSchema,
} from "@/features/finance/schemas";

const UUID_A = "00000000-0000-4000-8000-000000000001";
const UUID_B = "00000000-0000-4000-8000-000000000002";
const UUID_C = "00000000-0000-4000-8000-000000000003";

const validLine = {
  poLineId: UUID_A,
  qty: 10,
  unitPrice: 100000,
};

describe("invoiceSaveLineSchema", () => {
  it("chấp nhận dòng hợp lệ (có/không có VAT, có/không có GR line)", () => {
    expect(invoiceSaveLineSchema.safeParse(validLine).success).toBe(true);
    expect(
      invoiceSaveLineSchema.safeParse({
        ...validLine,
        vatRate: 8,
        grLineId: UUID_B,
      }).success,
    ).toBe(true);
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, vatRate: null }).success,
    ).toBe(true);
  });

  it("từ chối số lượng 0 hoặc âm", () => {
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, qty: 0 }).success,
    ).toBe(false);
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, qty: -2 }).success,
    ).toBe(false);
  });

  it("chấp nhận đơn giá 0, từ chối đơn giá âm", () => {
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, unitPrice: 0 }).success,
    ).toBe(true);
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, unitPrice: -1 }).success,
    ).toBe(false);
  });

  it("VAT phải trong 0–100", () => {
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, vatRate: 100 }).success,
    ).toBe(true);
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, vatRate: 101 }).success,
    ).toBe(false);
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, vatRate: -1 }).success,
    ).toBe(false);
  });

  it("từ chối UUID dòng PO sai định dạng", () => {
    expect(
      invoiceSaveLineSchema.safeParse({ ...validLine, poLineId: "abc" })
        .success,
    ).toBe(false);
  });
});

describe("invoiceSaveDraftSchema", () => {
  const valid = {
    propertyId: UUID_A,
    supplierId: UUID_B,
    header: {
      invoiceSymbol: "AA",
      invoiceNo: "0001234",
      invoiceDate: "2026-11-13",
    },
    lines: [validLine],
  };

  it("chấp nhận hóa đơn hợp lệ", () => {
    expect(invoiceSaveDraftSchema.safeParse(valid).success).toBe(true);
  });

  it("từ chối khi không có dòng nào", () => {
    expect(
      invoiceSaveDraftSchema.safeParse({ ...valid, lines: [] }).success,
    ).toBe(false);
  });

  it("từ chối ngày hóa đơn sai định dạng dd/mm/yyyy", () => {
    expect(
      invoiceSaveDraftSchema.safeParse({
        ...valid,
        header: { ...valid.header, invoiceDate: "13/11/2026" },
      }).success,
    ).toBe(false);
  });

  it("từ chối số hóa đơn trống hoặc chỉ khoảng trắng", () => {
    expect(
      invoiceSaveDraftSchema.safeParse({
        ...valid,
        header: { ...valid.header, invoiceNo: "   " },
      }).success,
    ).toBe(false);
  });
});

describe("invoiceMatchSchema / invoiceApproveSchema", () => {
  it("chấp nhận UUID hợp lệ, từ chối UUID sai", () => {
    expect(
      invoiceMatchSchema.safeParse({ propertyId: UUID_A, invoiceId: UUID_B })
        .success,
    ).toBe(true);
    expect(
      invoiceMatchSchema.safeParse({ propertyId: UUID_A, invoiceId: "x" })
        .success,
    ).toBe(false);
    expect(
      invoiceApproveSchema.safeParse({ propertyId: UUID_A, invoiceId: UUID_B })
        .success,
    ).toBe(true);
  });
});

describe("advanceSettleSchema", () => {
  it("chấp nhận quyết toán hợp lệ; từ chối tiền 0/âm và danh sách rỗng", () => {
    expect(
      advanceSettleSchema.safeParse({
        propertyId: UUID_A,
        advanceId: UUID_B,
        lines: [{ amount: 500000 }],
      }).success,
    ).toBe(true);
    expect(
      advanceSettleLineSchema.safeParse({ amount: 0 }).success,
    ).toBe(false);
    expect(
      advanceSettleLineSchema.safeParse({ amount: -100 }).success,
    ).toBe(false);
    expect(
      advanceSettleSchema.safeParse({
        propertyId: UUID_A,
        advanceId: UUID_B,
        lines: [],
      }).success,
    ).toBe(false);
    expect(
      advanceSettleLineSchema.safeParse({ amount: 1000, grId: "abc" })
        .success,
    ).toBe(false);
  });
});

describe("paymentRequestLineSchema / paymentRequestCreateSchema", () => {
  it("từ chối tiền đề nghị 0 hoặc âm", () => {
    expect(
      paymentRequestLineSchema.safeParse({ invoiceId: UUID_A, amount: 0 })
        .success,
    ).toBe(false);
    expect(
      paymentRequestLineSchema.safeParse({ invoiceId: UUID_A, amount: -5 })
        .success,
    ).toBe(false);
  });

  it("từ chối đề nghị không có hóa đơn nào", () => {
    expect(
      paymentRequestCreateSchema.safeParse({
        propertyId: UUID_A,
        supplierId: UUID_B,
        lines: [],
      }).success,
    ).toBe(false);
  });

  it("chấp nhận đề nghị có hạn thanh toán hợp lệ", () => {
    expect(
      paymentRequestCreateSchema.safeParse({
        propertyId: UUID_A,
        supplierId: UUID_B,
        lines: [{ invoiceId: UUID_C, amount: 1000000 }],
        dueDate: "2026-11-30",
      }).success,
    ).toBe(true);
  });
});

describe("paymentRequestDecideSchema", () => {
  const base = { propertyId: UUID_A, requestId: UUID_B };

  it("duyệt không cần lý do; từ chối bắt buộc có lý do", () => {
    expect(
      paymentRequestDecideSchema.safeParse({ ...base, decision: "approved" })
        .success,
    ).toBe(true);
    expect(
      paymentRequestDecideSchema.safeParse({ ...base, decision: "rejected" })
        .success,
    ).toBe(false);
    expect(
      paymentRequestDecideSchema.safeParse({
        ...base,
        decision: "rejected",
        comment: "Sai số tiền so với hóa đơn.",
      }).success,
    ).toBe(true);
  });

  it("từ chối quyết định ngoài approved/rejected và ghi chú quá 1000 ký tự", () => {
    expect(
      paymentRequestDecideSchema.safeParse({ ...base, decision: "pending" })
        .success,
    ).toBe(false);
    expect(
      paymentRequestDecideSchema.safeParse({
        ...base,
        decision: "rejected",
        comment: "x".repeat(1001),
      }).success,
    ).toBe(false);
  });
});

describe("paymentMarkPaidSchema", () => {
  it("bắt buộc mã tham chiếu ngân hàng, từ chối chuỗi trống/khoảng trắng", () => {
    expect(
      paymentMarkPaidSchema.safeParse({
        propertyId: UUID_A,
        requestId: UUID_B,
        bankRef: "CK-2026-001",
      }).success,
    ).toBe(true);
    expect(
      paymentMarkPaidSchema.safeParse({
        propertyId: UUID_A,
        requestId: UUID_B,
        bankRef: "",
      }).success,
    ).toBe(false);
    expect(
      paymentMarkPaidSchema.safeParse({
        propertyId: UUID_A,
        requestId: UUID_B,
        bankRef: "   ",
      }).success,
    ).toBe(false);
  });
});

describe("noInvoiceListingLineSchema / noInvoiceListingSaveSchema", () => {
  it("từ chối dòng không tên hàng, số lượng 0, đơn giá âm; chấp nhận đơn giá 0", () => {
    expect(
      noInvoiceListingLineSchema.safeParse({
        itemDesc: "",
        qty: 1,
        unitPrice: 1000,
      }).success,
    ).toBe(false);
    expect(
      noInvoiceListingLineSchema.safeParse({
        itemDesc: "Rau muống",
        qty: 0,
        unitPrice: 1000,
      }).success,
    ).toBe(false);
    expect(
      noInvoiceListingLineSchema.safeParse({
        itemDesc: "Rau muống",
        qty: 1,
        unitPrice: -1,
      }).success,
    ).toBe(false);
    expect(
      noInvoiceListingLineSchema.safeParse({
        itemDesc: "Rau muống",
        qty: 2,
        unitPrice: 0,
      }).success,
    ).toBe(true);
  });

  it("từ chối bảng kê không có dòng và thiếu tên người bán", () => {
    const base = {
      propertyId: UUID_A,
      listing: {
        sellerName: "Bà Tư chợ",
        purchaseDate: "2026-11-13",
      },
      lines: [{ itemDesc: "Rau muống", qty: 2, unitPrice: 5000 }],
    };
    expect(noInvoiceListingSaveSchema.safeParse(base).success).toBe(true);
    expect(
      noInvoiceListingSaveSchema.safeParse({ ...base, lines: [] }).success,
    ).toBe(false);
    expect(
      noInvoiceListingSaveSchema.safeParse({
        ...base,
        listing: { ...base.listing, sellerName: "" },
      }).success,
    ).toBe(false);
  });
});
