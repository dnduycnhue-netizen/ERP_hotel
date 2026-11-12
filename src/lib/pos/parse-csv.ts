/** Dòng xuất POS sau khi chuẩn hóa (khớp tham số RPC `pos_import_commit`). */
export type PosCsvLine = {
  bill_no: string;
  business_date: string;
  shift: string;
  time: string;
  outlet: string;
  item_code: string;
  item_name: string;
  qty: string;
  unit_price: string;
  amount: string;
  payment: string;
};

export const POS_CSV_COLUMNS = [
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

/** Cột bắt buộc phải có trong tiêu đề (cột khác là tùy chọn). */
const REQUIRED = [
  "bill_no",
  "business_date",
  "shift",
  "item_code",
  "qty",
  "unit_price",
  "amount",
] as const;

export type PosCsvParseResult =
  | { ok: true; lines: PosCsvLine[] }
  | { ok: false; error: "empty" | "missing_columns" | "bad_row"; detail: string };

/** Tách CSV có hỗ trợ dấu ngoặc kép, xuống dòng CRLF/LF. */
export function splitCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;
  const src = text.replace(/^﻿/, "");
  for (let i = 0; i < src.length; i++) {
    const ch = src[i];
    if (quoted) {
      if (ch === '"' && src[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (ch === '"') {
        quoted = false;
      } else {
        cell += ch;
      }
    } else if (ch === '"') {
      quoted = true;
    } else if (ch === ",") {
      row.push(cell);
      cell = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && src[i + 1] === "\n") i++;
      row.push(cell);
      cell = "";
      if (row.some((c) => c.trim() !== "")) rows.push(row);
      row = [];
    } else {
      cell += ch;
    }
  }
  row.push(cell);
  if (row.some((c) => c.trim() !== "")) rows.push(row);
  return rows;
}

/** Đọc file CSV xuất POS (định dạng giả định — xem scripts/gen-pos-sample.py). */
export function parsePosCsv(text: string): PosCsvParseResult {
  const rows = splitCsv(text);
  if (rows.length < 2) {
    return { ok: false, error: "empty", detail: "" };
  }
  const header = rows[0].map((h) => h.trim().toLowerCase());
  const missing = REQUIRED.filter((c) => !header.includes(c));
  if (missing.length > 0) {
    return { ok: false, error: "missing_columns", detail: missing.join(", ") };
  }
  const idx = (name: string) => header.indexOf(name);
  const lines: PosCsvLine[] = [];
  for (let r = 1; r < rows.length; r++) {
    const row = rows[r];
    const get = (name: string) =>
      idx(name) >= 0 ? (row[idx(name)] ?? "").trim() : "";
    const line: PosCsvLine = {
      bill_no: get("bill_no"),
      business_date: get("business_date"),
      shift: get("shift"),
      time: get("time"),
      outlet: get("outlet"),
      item_code: get("item_code"),
      item_name: get("item_name"),
      qty: get("qty"),
      unit_price: get("unit_price"),
      amount: get("amount"),
      payment: get("payment"),
    };
    if (
      line.bill_no === "" ||
      line.item_code === "" ||
      line.shift === "" ||
      !/^\d{4}-\d{2}-\d{2}$/.test(line.business_date) ||
      !/^\d+(\.\d+)?$/.test(line.qty) ||
      Number(line.qty) <= 0 ||
      !/^\d+(\.\d+)?$/.test(line.unit_price) ||
      !/^\d+(\.\d+)?$/.test(line.amount)
    ) {
      return { ok: false, error: "bad_row", detail: String(r + 1) };
    }
    lines.push(line);
  }
  return { ok: true, lines };
}
