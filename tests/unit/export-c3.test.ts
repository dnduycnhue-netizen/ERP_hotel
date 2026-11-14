import { describe, expect, it } from "vitest";
import { read } from "xlsx";
import {
  buildBankTransferWorkbook,
  isBankTransferPayload,
  parseBankTransferIds,
  type BankTransferPayload,
} from "@/features/export/bankTransfer";
import {
  buildPoPdf,
  isPoPdfData,
  type PoPdfData,
} from "@/features/export/poPdf";

const UUID_A = "11111111-1111-4111-8111-111111111111";
const UUID_B = "22222222-2222-4222-8222-222222222222";

describe("parseBankTransferIds", () => {
  it("chấp nhận danh sách uuid phân tách bằng dấu phẩy", () => {
    const parsed = parseBankTransferIds(
      new URLSearchParams(`ids=${UUID_A},${UUID_B}`),
    );
    expect(parsed).toEqual({ ok: true, ids: [UUID_A, UUID_B] });
  });

  it("loại bỏ id trùng và khoảng trắng thừa", () => {
    const parsed = parseBankTransferIds(
      new URLSearchParams(`ids=${UUID_A}, ${UUID_A}`),
    );
    expect(parsed).toEqual({ ok: true, ids: [UUID_A] });
  });

  it("từ chối khi thiếu ids", () => {
    expect(parseBankTransferIds(new URLSearchParams()).ok).toBe(false);
  });

  it("từ chối khi có id không phải uuid", () => {
    expect(
      parseBankTransferIds(new URLSearchParams(`ids=${UUID_A},khong-phai-uuid`))
        .ok,
    ).toBe(false);
  });

  it("từ chối khi quá 200 id", () => {
    const ids = Array.from(
      { length: 201 },
      (_, i) => `00000000-0000-4000-8000-${String(i).padStart(12, "0")}`,
    ).join(",");
    expect(parseBankTransferIds(new URLSearchParams(`ids=${ids}`)).ok).toBe(
      false,
    );
  });
});

const bankPayload: BankTransferPayload = {
  rows: [
    {
      request_id: UUID_A,
      doc_no: "DNTT-001",
      due_date: "2026-11-20",
      supplier_code: "NCC1",
      supplier_name: "Công ty Gạo Sạch",
      bank_name: "Vietcombank",
      account_no: "1234567890",
      account_name: "CTY GAO SACH",
      amount: 1500000,
      content: "Thanh toán DNTT-001",
      previously_exported_at: null,
    },
    {
      request_id: UUID_B,
      doc_no: "DNTT-002",
      due_date: null,
      supplier_code: "NCC2",
      supplier_name: "Công ty Thịt Sạch",
      bank_name: "BIDV",
      account_no: "9876543210",
      account_name: "CTY THIT SACH",
      amount: 500000,
      content: "Thanh toán DNTT-002",
      previously_exported_at: "2026-11-09T10:00:00+07:00",
    },
  ],
  totals: { count: 2, amount: 2000000 },
  meta: {
    exported_at: "2026-11-10T08:00:00+07:00",
    exported_by: "user-1",
  },
};

describe("buildBankTransferWorkbook", () => {
  it("trả về file xlsx (PK zip magic) với đúng sheet và số tiền là số thật", () => {
    const buffer = buildBankTransferWorkbook(bankPayload);
    expect(buffer.subarray(0, 2).toString("latin1")).toBe("PK");

    const workbook = read(buffer, { type: "buffer" });
    expect(workbook.SheetNames).toEqual(["Chuyển khoản"]);
    const sheet = workbook.Sheets["Chuyển khoản"];
    // Dong 1: tieu de; dong 5 (chi so 4): header; dong 6-7: du lieu.
    expect(sheet["A1"]?.v).toBe("Danh sách chuyển khoản");
    expect(sheet["A5"]?.v).toBe("Số đề nghị");
    expect(sheet["A6"]?.v).toBe("DNTT-001");
    // Cot tien (H): so that, khong phai text.
    expect(sheet["H6"]?.v).toBe(1500000);
    expect(sheet["H6"]?.t).toBe("n");
    // Dong tong: tong tien o cot H.
    expect(sheet["H8"]?.v).toBe(2000000);
    // Hang da xuat truoc do duoc danh dau o cot Ghi chu (J).
    expect(String(sheet["J7"]?.v)).toContain("Đã xuất trước đây");
    expect(sheet["J6"]?.v ?? "").toBe("");
  });
});

describe("isBankTransferPayload", () => {
  it("chấp nhận payload đủ hình dạng", () => {
    expect(isBankTransferPayload({ ok: true, ...bankPayload })).toBe(true);
  });

  it("từ chối payload thiếu rows/meta", () => {
    expect(isBankTransferPayload({ ok: true, rows: [] })).toBe(false);
    expect(isBankTransferPayload(null)).toBe(false);
  });
});

const poData: PoPdfData = {
  po: {
    doc_no: "PO-001",
    supplier_code: "NCC1",
    supplier_name: "Công ty Gạo Sạch",
    supplier_tax_code: "1234567890",
    entity_code: "SONHOIAN",
    entity_name: "Son Hoi An Boutique Hotel & Spa",
    channel: "contract",
    kind: "stock",
    order_date: "2026-11-10",
    expected_date: "2026-11-15",
    status: "approved",
    total_amount: 1000000,
    created_by_name: "Nguyễn Văn A",
    created_at: "2026-11-10T08:00:00+07:00",
  },
  lines: [
    {
      item_code: "ITM_GAO",
      item_name: "Gạo ST25",
      qty: 10,
      uom: "kg",
      unit_price: 50000,
      line_amount: 500000,
    },
    {
      item_code: null,
      item_name: "Muối hạt",
      qty: 20,
      uom: "kg",
      unit_price: 25000,
      line_amount: 500000,
    },
  ],
  timeline: [
    {
      step: 1,
      approver_role_name: "Trưởng outlet",
      decision: "approved",
      decided_by_name: "Trần Thị B",
      decided_at: "2026-11-10T09:00:00+07:00",
      comment: null,
    },
    {
      step: 2,
      approver_role_name: "Giám đốc",
      decision: "pending",
      decided_by_name: null,
      decided_at: null,
      comment: null,
    },
  ],
};

describe("buildPoPdf", () => {
  it("trả về buffer PDF hợp lệ (%PDF) với tiếng Việt có dấu", async () => {
    const buffer = await buildPoPdf(poData);
    expect(buffer.subarray(0, 4).toString("latin1")).toBe("%PDF");
    expect(buffer.length).toBeGreaterThan(2000);
  });

  it("chạy được với PO không có dòng và không có lịch sử duyệt", async () => {
    const buffer = await buildPoPdf({
      ...poData,
      lines: [],
      timeline: [],
    });
    expect(buffer.subarray(0, 4).toString("latin1")).toBe("%PDF");
  });
});

describe("isPoPdfData", () => {
  it("chấp nhận payload đủ hình dạng", () => {
    expect(isPoPdfData({ ok: true, ...poData })).toBe(true);
  });

  it("từ chối payload thiếu lines/timeline", () => {
    expect(isPoPdfData({ ok: true, po: poData.po })).toBe(false);
    expect(isPoPdfData(null)).toBe(false);
  });
});

describe("normalizeExportPayload (B-5)", () => {
  it("gói entity/from/to/exported_* của RPC vào meta; không văng lỗi khi rows rỗng", async () => {
    const { normalizeExportPayload, buildExportWorkbook } = await import(
      "@/features/export/workbook"
    );
    const { getExportDefinition } = await import(
      "@/features/export/definitions"
    );
    const payload = normalizeExportPayload({
      ok: true,
      entity: { id: "e1", code: "TEST47-LE", name: "Pháp nhân test" },
      from: "2026-11-01",
      to: "2026-11-14",
      exported_at: "2026-11-14T02:04:41+00:00",
      exported_by: "u1",
      rows: [],
      totals: { count: 0, amount: 0 },
    });
    expect(payload.meta.entity_code).toBe("TEST47-LE");
    expect(payload.meta.from).toBe("2026-11-01");
    for (const kind of [
      "goods-receipts",
      "stock-issues",
      "invoices",
      "payables",
      "advances",
    ]) {
      const def = getExportDefinition(kind);
      expect(def).toBeDefined();
      if (def) {
        expect(() => buildExportWorkbook(def, payload)).not.toThrow();
      }
    }
  });
});
