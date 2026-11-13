import type { PosCsvLine } from "./parse-csv";

/**
 * Column mapping for POS import (M-01).
 *
 * The POS export file used to be assumed to have the exact canonical header
 * (`docs/samples/pos-export-sample-SYNTHETIC.csv`). Real POS files use
 * different column names, so the browser now lets the user map source
 * columns to the 11 target fields before upload. Everything here is pure
 * and runs in the browser; the server action and the RPC are untouched.
 */

/** Target fields of a POS export line (match RPC `pos_import_commit`). */
export const POS_TARGET_FIELDS = [
  "bill_no",
  "business_date",
  "shift",
  "time",
  "outlet",
  "item_code",
  "item_name",
  "qty",
  "unit_price",
  "amount",
  "payment",
] as const;

export type PosTargetField = (typeof POS_TARGET_FIELDS)[number];

/** Fields that must be mapped (same set as `REQUIRED` in parse-csv). */
export const POS_REQUIRED_FIELDS: readonly PosTargetField[] = [
  "bill_no",
  "business_date",
  "shift",
  "item_code",
  "qty",
  "unit_price",
  "amount",
];

/** Mapping: target field -> source header name (`null` = not mapped yet). */
export type PosColumnMapping = Record<PosTargetField, string | null>;

/** Normalize a header for comparison: lowercase, no diacritics/spaces. */
export function normalizeHeaderName(name: string): string {
  return name
    .trim()
    .toLowerCase()
    .replace(/đ/g, "d")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]/g, "");
}

/**
 * Known source names per target field (already normalized). The canonical
 * name itself is always accepted; these aliases cover Vietnamese POS
 * exports (e.g. "Mã bill", "Ngày", "Ca", "Số lượng", "Đơn giá").
 */
const FIELD_ALIASES: Record<PosTargetField, string[]> = {
  bill_no: [
    "billno",
    "bill",
    "receipt",
    "receiptno",
    "orderno",
    "order",
    "checkno",
    "check",
    "mahoadon",
    "mahd",
    "mabill",
    "sobill",
    "madon",
    "sohoadon",
    "hoadon",
    "sophieu",
    "maphieu",
  ],
  business_date: [
    "businessdate",
    "ngay",
    "ngaykinhdoanh",
    "ngayban",
    "date",
    "transactiondate",
    "ngaygiaodich",
    "ngaylap",
    "ngaytao",
    "ngaychungtu",
  ],
  shift: ["shift", "ca", "calamviec", "shiftname", "tenca", "khoa", "session"],
  time: ["time", "gio", "thoigian", "hour", "gioban"],
  outlet: [
    "outlet",
    "quay",
    "cuahang",
    "store",
    "branch",
    "diemban",
    "outletname",
    "tenquay",
    "khu",
  ],
  item_code: [
    "itemcode",
    "mamon",
    "mahang",
    "mavt",
    "code",
    "productcode",
    "sku",
    "mahanghoa",
    "mavattu",
    "mamonan",
    "codehang",
  ],
  item_name: [
    "itemname",
    "tenmon",
    "tenhang",
    "tenmonan",
    "productname",
    "name",
    "tenhanghoa",
    "tenvattu",
    "mon",
    "ten",
  ],
  qty: ["qty", "soluong", "sl", "quantity", "sluong", "soluongban"],
  unit_price: ["unitprice", "dongia", "giaban", "price", "gia", "dongiaban"],
  amount: [
    "amount",
    "thanhtien",
    "tongtien",
    "total",
    "sotien",
    "tongcong",
    "totalamount",
  ],
  payment: [
    "payment",
    "thanhtoan",
    "hinhthucthanhtoan",
    "phuongthucthanhtoan",
    "paymethod",
    "paymentmethod",
    "hinhthuc",
  ],
};

/**
 * Guess a mapping from the file headers. Each source column is used at
 * most once; targets are tried in order, so an ambiguous header goes to
 * the first target that claims it.
 */
export function guessPosMapping(headers: string[]): PosColumnMapping {
  const used = new Set<number>();
  const mapping = {} as PosColumnMapping;
  for (const field of POS_TARGET_FIELDS) {
    const accepted = new Set([
      normalizeHeaderName(field),
      ...FIELD_ALIASES[field],
    ]);
    let found: string | null = null;
    for (let i = 0; i < headers.length; i++) {
      if (used.has(i)) continue;
      if (accepted.has(normalizeHeaderName(headers[i] ?? ""))) {
        used.add(i);
        found = headers[i] ?? "";
        break;
      }
    }
    mapping[field] = found;
  }
  return mapping;
}

/** Convert an Excel date serial (days since 1899-12-30) to ISO date. */
export function excelSerialToIso(serial: number): string | null {
  if (!Number.isInteger(serial) || serial < 20000 || serial > 80000) {
    return null;
  }
  const ms = Date.UTC(1899, 11, 30) + serial * 86_400_000;
  const d = new Date(ms);
  return Number.isNaN(d.getTime()) ? null : d.toISOString().slice(0, 10);
}

function isRealDate(year: number, month: number, day: number): boolean {
  if (month < 1 || month > 12 || day < 1 || day > 31) return false;
  const d = new Date(Date.UTC(year, month - 1, day));
  return (
    d.getUTCFullYear() === year &&
    d.getUTCMonth() === month - 1 &&
    d.getUTCDate() === day
  );
}

function toIsoDate(year: number, month: number, day: number): string | null {
  if (!isRealDate(year, month, day)) return null;
  const m = String(month).padStart(2, "0");
  const dd = String(day).padStart(2, "0");
  return `${year}-${m}-${dd}`;
}

/**
 * Normalize a business date to `YYYY-MM-DD`. Accepts ISO dates,
 * `DD/MM/YYYY` (Vietnamese convention, also with `-` or `.` separators),
 * `DD/MM/YY`, and Excel serial numbers.
 */
export function normalizePosDate(raw: unknown): string | null {
  if (typeof raw === "number") return excelSerialToIso(raw);
  if (typeof raw !== "string") return null;
  const s = raw.trim();
  if (s === "") return null;
  const iso = s.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (iso) {
    return toIsoDate(Number(iso[1]), Number(iso[2]), Number(iso[3]));
  }
  const dmy = s.match(/^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$/);
  if (dmy) {
    return toIsoDate(Number(dmy[3]), Number(dmy[2]), Number(dmy[1]));
  }
  const dmyShort = s.match(/^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2})$/);
  if (dmyShort) {
    return toIsoDate(
      2000 + Number(dmyShort[3]),
      Number(dmyShort[2]),
      Number(dmyShort[1]),
    );
  }
  return null;
}

/**
 * Normalize a number to a plain string with `.` as the decimal separator
 * and no thousands separator. Accepts `1.234,56` (Vietnamese),
 * `1,234.56` (English), `1,5`, `1.234` (thousands) and plain numbers.
 * Returns `null` when the value is not a number.
 */
export function normalizePosNumber(raw: unknown): string | null {
  if (typeof raw === "number") {
    return Number.isFinite(raw) ? String(raw) : null;
  }
  if (typeof raw !== "string") return null;
  let s = raw.trim().replace(/[\s\u00a0]/g, "");
  if (s === "") return null;
  if (!/^-?[\d.,]+$/.test(s)) return null;
  const hasDot = s.includes(".");
  const hasComma = s.includes(",");
  if (hasDot && hasComma) {
    // The separator that appears last is the decimal separator.
    if (s.lastIndexOf(".") > s.lastIndexOf(",")) {
      s = s.replace(/,/g, "");
    } else {
      s = s.replace(/\./g, "").replace(",", ".");
    }
  } else if (hasComma) {
    s = /^-?\d{1,3}(,\d{3})+$/.test(s) ? s.replace(/,/g, "") : s.replace(",", ".");
  } else if (hasDot) {
    if (/^-?\d{1,3}(\.\d{3})+$/.test(s)) s = s.replace(/\./g, "");
  }
  return /^-?\d+(\.\d+)?$/.test(s) ? s : null;
}

export type PosMappedRowsResult =
  | { ok: true; lines: PosCsvLine[] }
  | {
      ok: false;
      error: "empty" | "missing_columns" | "bad_row";
      detail: string;
    };

function cellToText(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "number") return String(value);
  return String(value).trim();
}

/**
 * Apply a column mapping to raw rows (header excluded) and validate every
 * row with the same rules as `parsePosCsv`. `rows` may hold raw Excel cell
 * values (numbers stay numbers so date serials survive).
 */
export function mapRowsToLines(
  headers: string[],
  rows: (string | number | null)[][],
  mapping: PosColumnMapping,
): PosMappedRowsResult {
  const indexOf = (field: PosTargetField): number => {
    const name = mapping[field];
    if (!name) return -1;
    return headers.findIndex((h) => h.trim() === name.trim());
  };
  const missing = POS_REQUIRED_FIELDS.filter((f) => indexOf(f) < 0);
  if (missing.length > 0) {
    return { ok: false, error: "missing_columns", detail: missing.join(", ") };
  }
  const idx: Record<PosTargetField, number> = {} as Record<
    PosTargetField,
    number
  >;
  for (const field of POS_TARGET_FIELDS) idx[field] = indexOf(field);
  const get = (row: (string | number | null)[], field: PosTargetField) =>
    idx[field] >= 0 ? (row[idx[field]] ?? null) : null;

  const lines: PosCsvLine[] = [];
  for (let r = 0; r < rows.length; r++) {
    const row = rows[r] ?? [];
    if (row.every((c) => cellToText(c) === "")) continue;
    const businessDate = normalizePosDate(get(row, "business_date"));
    const qty = normalizePosNumber(get(row, "qty"));
    const unitPrice = normalizePosNumber(get(row, "unit_price"));
    const amount = normalizePosNumber(get(row, "amount"));
    const line: PosCsvLine = {
      bill_no: cellToText(get(row, "bill_no")),
      business_date: businessDate ?? "",
      shift: cellToText(get(row, "shift")),
      time: cellToText(get(row, "time")),
      outlet: cellToText(get(row, "outlet")),
      item_code: cellToText(get(row, "item_code")),
      item_name: cellToText(get(row, "item_name")),
      qty: qty ?? "",
      unit_price: unitPrice ?? "",
      amount: amount ?? "",
      payment: cellToText(get(row, "payment")),
    };
    if (
      line.bill_no === "" ||
      line.item_code === "" ||
      line.shift === "" ||
      businessDate === null ||
      qty === null ||
      Number(qty) <= 0 ||
      unitPrice === null ||
      Number(unitPrice) < 0 ||
      amount === null ||
      Number(amount) < 0
    ) {
      return { ok: false, error: "bad_row", detail: String(r + 2) };
    }
    lines.push(line);
  }
  if (lines.length === 0) {
    return { ok: false, error: "empty", detail: "" };
  }
  return { ok: true, lines };
}

const STORAGE_KEY = "erp-pos-column-mapping-v1";

/** Last mapping the user chose, keyed by target field (best effort). */
export function loadSavedPosMapping(): Partial<
  Record<PosTargetField, string>
> | null {
  try {
    if (typeof localStorage === "undefined") return null;
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed: unknown = JSON.parse(raw);
    if (typeof parsed !== "object" || parsed === null) return null;
    const out: Partial<Record<PosTargetField, string>> = {};
    for (const field of POS_TARGET_FIELDS) {
      const v = (parsed as Record<string, unknown>)[field];
      if (typeof v === "string" && v.trim() !== "") out[field] = v;
    }
    return out;
  } catch {
    return null;
  }
}

export function savePosMapping(mapping: PosColumnMapping): void {
  try {
    if (typeof localStorage === "undefined") return;
    const slim: Partial<Record<PosTargetField, string>> = {};
    for (const field of POS_TARGET_FIELDS) {
      if (mapping[field]) slim[field] = mapping[field] as string;
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(slim));
  } catch {
    // Storage full or unavailable: mapping just is not remembered.
  }
}
