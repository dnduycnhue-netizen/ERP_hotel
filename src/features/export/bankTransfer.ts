import { utils, write } from "xlsx";
import { vi } from "@/i18n/vi";

/**
 * File Excel danh sach chuyen khoan (C3, M09): de nghi thanh toan DA DUYET
 * gom theo NCC -> ke toan mang ra ngan hang. Dung `xlsx` 0.18.5 da co
 * trong repo (nhu T-043). Tien la so Excel that.
 *
 * Query param duy nhat: `?ids=<uuid>,<uuid>,...` (toi da 200 id, khong
 * trung). Chon ids thay vi theo ky: ke toan xuat dung cac de nghi da
 * duyet muon tra dot nay; xuat theo ky de lot de nghi chua duyet hoac
 * da tra. Trang thai xuat duoc doi chieu qua bang `export_batches`.
 */

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const BANK_TRANSFER_MAX_IDS = 200;

/**
 * Parse `?ids=...`. Tra `{ ok: false }` khi thieu, qua 200 id, trung id
 * khong hop le, hoac co id khong phai uuid.
 */
export function parseBankTransferIds(
  searchParams: URLSearchParams,
): { ok: true; ids: string[] } | { ok: false } {
  const raw = searchParams.get("ids");
  if (!raw) return { ok: false };
  const ids = raw
    .split(",")
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (ids.length === 0 || ids.length > BANK_TRANSFER_MAX_IDS) {
    return { ok: false };
  }
  if (!ids.every((id) => UUID_RE.test(id))) return { ok: false };
  return { ok: true, ids: [...new Set(ids)] };
}

export interface BankTransferRow {
  request_id: string;
  doc_no: string;
  due_date: string | null;
  supplier_code: string;
  supplier_name: string;
  bank_name: string;
  account_no: string;
  account_name: string;
  /** numeric(18,2) — tra ve dang so tu RPC. */
  amount: number;
  content: string;
  /** Lan xuat bank-transfer truoc do (null = chua xuat bao gio). */
  previously_exported_at: string | null;
}

export interface BankTransferPayload {
  rows: BankTransferRow[];
  totals: { count: number; amount: number };
  meta: { exported_at: string; exported_by: string };
}

/** Kiem tra hinh dang payload tra ve tu RPC `export_bank_transfer`. */
export function isBankTransferPayload(
  value: unknown,
): value is BankTransferPayload {
  if (typeof value !== "object" || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    v.ok === true &&
    Array.isArray(v.rows) &&
    typeof v.totals === "object" &&
    v.totals !== null &&
    typeof v.meta === "object" &&
    v.meta !== null
  );
}

const MONEY_FORMAT = "#,##0.00";

/** "2026-11-20" -> "20/11/2026". */
function formatDateVn(isoDate: string | null): string {
  if (!isoDate) return "";
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

interface BankTransferColumn {
  key: string;
  header: string;
  width: number;
  format: "text" | "money" | "date";
}

const COLUMNS: BankTransferColumn[] = [
  {
    key: "doc_no",
    header: vi.export.bankTransfer.columns.requestNo,
    width: 14,
    format: "text",
  },
  {
    key: "due_date",
    header: vi.export.bankTransfer.columns.dueDate,
    width: 12,
    format: "date",
  },
  {
    key: "supplier_code",
    header: vi.export.columns.supplierCode,
    width: 10,
    format: "text",
  },
  {
    key: "supplier_name",
    header: vi.export.columns.supplierName,
    width: 32,
    format: "text",
  },
  {
    key: "bank_name",
    header: vi.export.bankTransfer.columns.bankName,
    width: 22,
    format: "text",
  },
  {
    key: "account_no",
    header: vi.export.bankTransfer.columns.accountNo,
    width: 18,
    format: "text",
  },
  {
    key: "account_name",
    header: vi.export.bankTransfer.columns.accountName,
    width: 28,
    format: "text",
  },
  {
    key: "amount",
    header: vi.export.bankTransfer.columns.amount,
    width: 18,
    format: "money",
  },
  {
    key: "content",
    header: vi.export.bankTransfer.columns.content,
    width: 32,
    format: "text",
  },
  {
    key: "note",
    header: vi.export.bankTransfer.columns.note,
    width: 28,
    format: "text",
  },
];

function cellValue(
  column: BankTransferColumn,
  row: BankTransferRow,
): string | number {
  if (column.key === "note") {
    return row.previously_exported_at
      ? `${vi.export.bankTransfer.alreadyExported}: ${formatDateTimeVn(row.previously_exported_at)}`
      : "";
  }
  const raw = row[column.key as keyof BankTransferRow];
  if (raw === null || raw === undefined) return "";
  if (column.format === "date") return formatDateVn(String(raw));
  if (column.format === "money") {
    const num = typeof raw === "number" ? raw : Number(raw);
    return Number.isFinite(num) ? num : "";
  }
  return String(raw);
}

export function buildBankTransferWorkbook(
  payload: BankTransferPayload,
): Buffer {
  const T = vi.export.bankTransfer;
  const aoa: unknown[][] = [
    [T.title],
    [
      `${T.metaCount}: ${payload.totals.count} — ${T.metaTotal}: ${payload.totals.amount.toLocaleString("vi-VN")}`,
    ],
    [
      `${vi.export.meta.exportedAt}: ${formatDateTimeVn(payload.meta.exported_at)} — ${vi.export.meta.exportedBy}: ${payload.meta.exported_by}`,
    ],
    [],
    COLUMNS.map((c) => c.header),
    ...payload.rows.map((row) => COLUMNS.map((c) => cellValue(c, row))),
    [
      vi.export.totalRow,
      ...COLUMNS.slice(1).map((c) =>
        c.key === "amount" ? payload.totals.amount : "",
      ),
    ],
  ];

  const sheet = utils.aoa_to_sheet(aoa);
  sheet["!merges"] = [
    { s: { r: 0, c: 0 }, e: { r: 0, c: COLUMNS.length - 1 } },
  ];
  sheet["!cols"] = COLUMNS.map((c) => ({ wch: c.width }));

  // Dinh dang so cho cot tien (dong du lieu + dong tong).
  const firstDataRow = 5;
  const lastRow = firstDataRow + payload.rows.length;
  const amountCol = COLUMNS.findIndex((c) => c.key === "amount");
  for (let r = firstDataRow; r <= lastRow; r++) {
    const ref = utils.encode_cell({ r, c: amountCol });
    const cell = sheet[ref];
    if (cell && typeof cell.v === "number") {
      cell.z = MONEY_FORMAT;
    }
  }

  const workbook = utils.book_new();
  utils.book_append_sheet(workbook, sheet, T.sheet);
  return Buffer.from(
    write(workbook, { type: "buffer", bookType: "xlsx", cellStyles: true }),
  );
}
