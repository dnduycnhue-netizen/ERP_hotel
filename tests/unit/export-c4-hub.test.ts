import { describe, expect, it } from "vitest";
import {
  MAX_BANK_TRANSFER_IDS,
  buildAccountingExportUrl,
  buildBankTransferUrl,
  buildPoPdfUrl,
  formatDateTimeVn,
  formatDateVn,
  isPoDownloadable,
  monthStartOf,
} from "@/features/export/hub";

describe("màn hub xuất file tài chính (C4)", () => {
  it("chỉ PO đã duyệt trở đi mới tải được PDF", () => {
    for (const status of [
      "approved",
      "sent",
      "partially_received",
      "received",
      "closed",
    ]) {
      expect(isPoDownloadable(status)).toBe(true);
    }
    for (const status of ["draft", "submitted", "rejected", "cancelled"]) {
      expect(isPoDownloadable(status)).toBe(false);
    }
  });

  it("URL PDF PO giữ nguyên contract C3", () => {
    const id = "11111111-2222-3333-4444-555555555555";
    expect(buildPoPdfUrl(id)).toBe(`/api/export/po/${id}`);
  });

  it("URL chuyển khoản loại trùng id, trả null khi rỗng", () => {
    expect(MAX_BANK_TRANSFER_IDS).toBe(200);
    const a = "11111111-2222-3333-4444-555555555555";
    const b = "22222222-3333-4444-5555-666666666666";
    expect(buildBankTransferUrl([a, b, a])).toBe(
      `/api/export/bank-transfer?ids=${encodeURIComponent(`${a},${b}`)}`,
    );
    expect(buildBankTransferUrl([])).toBeNull();
    expect(buildBankTransferUrl(["  ", ""])).toBeNull();
  });

  it("URL xuất kế toán giữ nguyên contract T-043", () => {
    expect(
      buildAccountingExportUrl(
        "payables",
        "11111111-2222-3333-4444-555555555555",
        "2026-10-01",
        "2026-10-31",
      ),
    ).toBe(
      "/api/export/payables?entity=11111111-2222-3333-4444-555555555555&from=2026-10-01&to=2026-10-31",
    );
  });

  it("định dạng ngày VN", () => {
    expect(monthStartOf("2026-11-10")).toBe("2026-11-01");
    expect(formatDateVn("2026-11-10")).toBe("10/11/2026");
    expect(formatDateVn(null)).toBeNull();
    expect(formatDateVn("10/11/2026")).toBe("10/11/2026");
    // 2026-11-10 09:30 UTC = 16:30 giờ VN.
    expect(formatDateTimeVn("2026-11-10T09:30:00.000Z")).toBe(
      "10/11/2026 16:30",
    );
    expect(formatDateTimeVn(null)).toBeNull();
  });
});
