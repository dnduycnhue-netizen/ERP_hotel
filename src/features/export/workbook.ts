import { utils, write } from "xlsx";
import { vi } from "@/i18n/vi";
import type { ExportColumn, ExportDefinition } from "./definitions";

/**
 * Xay workbook .xlsx tu ket qua RPC xuat ke toan (T-043).
 *
 * Cau truc sheet: dong tieu de (merge) + 3 dong meta (phap nhan, ky, ngay
 * xuat/nguoi xuat) + dong trong + header tieng Viet + dong du lieu + dong
 * tong cong. Tien/so luong la so Excel that (t: "n", dinh dang #,##0.00 /
 * #,##0.0000), khong phai text — de ke toan cong tru truc tiep trong Excel.
 *
 * Dung `xlsx` 0.18.5 da co san trong repo (T-033 xuat bien ban kiem ke
 * bang thu vien nay) — khong them thu vien moi. Luu y: ban community cua
 * xlsx khong ho tro style (bold/mau) khi ghi file, nen chi dinh dang so.
 */

export interface ExportPayload {
  ok: boolean;
  rows: Array<Record<string, unknown>>;
  totals: Record<string, unknown>;
  meta: {
    entity_code: string;
    entity_name: string;
    from: string;
    to: string;
    exported_by: string;
    exported_at: string;
  };
}

const MONEY_FORMAT = "#,##0.00";
const QTY_FORMAT = "#,##0.0000";
const INT_FORMAT = "#,##0";

function numberFormat(column: ExportColumn): string | null {
  if (column.format === "money") return MONEY_FORMAT;
  if (column.format === "qty") return QTY_FORMAT;
  if (column.format === "int") return INT_FORMAT;
  return null;
}

function mapLabel(column: ExportColumn, value: unknown): unknown {
  if (value === null || value === undefined) return "";
  if (!column.map) return value;
  const raw = String(value);
  if (column.map === "moveType") {
    return (vi.export.moveTypeLabels as Record<string, string>)[raw] ?? raw;
  }
  if (column.map === "docType") {
    return (vi.export.docTypeLabels as Record<string, string>)[raw] ?? raw;
  }
  return (vi.export.advanceStatusLabels as Record<string, string>)[raw] ?? raw;
}

function cellValue(
  column: ExportColumn,
  row: Record<string, unknown>,
): unknown {
  const raw = row[column.key];
  if (raw === null || raw === undefined) return "";
  const mapped = mapLabel(column, raw);
  if (
    column.format === "money" ||
    column.format === "qty" ||
    column.format === "int"
  ) {
    const num = typeof mapped === "number" ? mapped : Number(mapped);
    return Number.isFinite(num) ? num : "";
  }
  return mapped;
}

/** "2026-10-01" -> "01/10/2026". */
function formatDateVn(isoDate: string): string {
  const [y, m, d] = isoDate.split("-");
  if (!y || !m || !d) return isoDate;
  return `${d}/${m}/${y}`;
}

/** Timestamptz ISO -> "dd/mm/yyyy HH:mm" gio Viet Nam. */
function formatDateTimeVn(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return date.toLocaleString("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

export function buildExportWorkbook(
  def: ExportDefinition,
  payload: ExportPayload,
): Buffer {
  const meta = payload.meta;
  const cols = def.columns;

  const aoa: unknown[][] = [
    [def.title],
    [`${vi.export.meta.entity}: ${meta.entity_name} (${meta.entity_code})`],
    [
      `${vi.export.meta.period}: ${formatDateVn(meta.from)} – ${formatDateVn(meta.to)}`,
    ],
    [
      `${vi.export.meta.exportedAt}: ${formatDateTimeVn(meta.exported_at)} — ${vi.export.meta.exportedBy}: ${meta.exported_by}`,
    ],
    [],
    cols.map((c) => c.header),
    ...payload.rows.map((row) => cols.map((c) => cellValue(c, row))),
    [
      vi.export.totalRow,
      ...cols.slice(1).map((c) => {
        if (!def.totalKeys.includes(c.key)) return "";
        const total = payload.totals[c.key];
        if (typeof total === "number") return total;
        const num = Number(total);
        return Number.isFinite(num) ? num : "";
      }),
    ],
  ];

  const sheet = utils.aoa_to_sheet(aoa);

  // Tieu de merge ngang het bang.
  sheet["!merges"] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: cols.length - 1 } }];
  // Do rong cot.
  sheet["!cols"] = cols.map((c) => ({ wch: c.width }));

  // Dinh dang so cho dong du lieu (bat dau dong 7, chi so 6) + dong tong.
  const firstDataRow = 6;
  const lastRow = firstDataRow + payload.rows.length;
  for (let r = firstDataRow; r <= lastRow; r++) {
    for (let c = 0; c < cols.length; c++) {
      const format = numberFormat(cols[c]);
      if (!format) continue;
      const ref = utils.encode_cell({ r, c });
      const cell = sheet[ref];
      if (cell && typeof cell.v === "number") {
        cell.z = format;
      }
    }
  }

  const workbook = utils.book_new();
  utils.book_append_sheet(workbook, sheet, def.sheetName);
  // cellStyles: true bat buoc de dinh dang so (cell.z) duoc ghi vao file;
  // mac dinh xlsx bo qua moi style khi ghi.
  return Buffer.from(
    write(workbook, { type: "buffer", bookType: "xlsx", cellStyles: true }),
  );
}
