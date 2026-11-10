"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import type { CountResultRow } from "@/features/count/queries";
import { vi } from "@/i18n/vi";

/**
 * Xuất biên bản chênh lệch ra Excel (T-033, AC chính): dùng `xlsx` 0.18.5
 * đã có sẵn trong repo (T-014 dùng để import) — không thêm thư viện mới.
 * Chỉ người có `count.view_variance` mới thấy nút này (view v_count_result
 * đã chặn ở tầng dữ liệu; nút chỉ là cổng hiển thị).
 */
export function CountExportButton({
  rows,
  docNo,
}: {
  rows: CountResultRow[];
  docNo: string;
}) {
  const [exporting, setExporting] = useState(false);

  function flagLabel(flag: CountResultRow["flag"]): string {
    if (flag === "ok") return vi.count.flags.ok;
    if (flag === "recount") return vi.count.flags.recount;
    if (flag === "red") return vi.count.flags.red;
    return vi.common.noData;
  }

  function reasonLabel(code: string | null): string {
    switch (code) {
      case "lost":
        return vi.count.reasonCodes.lost;
      case "damaged":
        return vi.count.reasonCodes.damaged;
      case "expired":
        return vi.count.reasonCodes.expired;
      case "theft":
        return vi.count.reasonCodes.theft;
      case "miscount":
        return vi.count.reasonCodes.miscount;
      case "supplier_short":
        return vi.count.reasonCodes.supplierShort;
      case "other":
        return vi.count.reasonCodes.other;
      default:
        return "";
    }
  }

  async function handleExport(): Promise<void> {
    if (exporting || rows.length === 0) {
      return;
    }
    setExporting(true);
    try {
      // Nạp `xlsx` (chunk ~400KB) chỉ khi người dùng bấm xuất — import
      // tĩnh ở đầu file kéo cả thư viện vào bundle trang kết quả kiểm kê.
      const { utils, writeFile } = await import("xlsx");
      const cols = vi.count.exportColumns;
      const data = rows.map((row) => ({
        [cols.itemCode]: row.item_code,
        [cols.itemName]: row.item_name,
        [cols.uom]: row.stock_uom,
        [cols.bookQty]: row.book_qty ?? "",
        [cols.finalQty]: row.final_qty ?? "",
        [cols.varianceQty]: row.variance_qty ?? "",
        [cols.variancePct]: row.variance_pct ?? "",
        [cols.flag]: flagLabel(row.flag),
        [cols.reasonCode]: reasonLabel(row.reason_code),
        [cols.explanation]: row.explanation ?? "",
      }));
      const sheet = utils.json_to_sheet(data);
      const workbook = utils.book_new();
      utils.book_append_sheet(workbook, sheet, vi.count.reportTitle);
      writeFile(workbook, `bien-ban-chenh-lech-${docNo}.xlsx`);
    } finally {
      setExporting(false);
    }
  }

  return (
    <Button
      variant="outline"
      disabled={exporting || rows.length === 0}
      onClick={handleExport}
    >
      {exporting ? vi.count.exporting : vi.count.exportExcel}
    </Button>
  );
}
