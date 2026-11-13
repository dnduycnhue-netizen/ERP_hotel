import { read } from "xlsx";
import { cellToString, detectHeaderRow, getSheetGrid } from "@/lib/import/xlsx";
import { splitCsv } from "@/lib/pos/parse-csv";

import {
  normalizeHeaderName,
  normalizePosDate,
  normalizePosNumber,
} from "@/lib/pos/column-mapping";

/**
 * Bulk import for master data (M-02).
 *
 * Rooms, room types, ceiling prices and minibar prices can be entered one
 * by one in the UI but have no Excel import (the import wizard only
 * handles items and suppliers). This module parses a CSV/XLSX file,
 * validates every row and resolves codes (room type, item, UoM) against
 * lists the page already loads. Each valid row is then saved through the
 * EXISTING single-row server action — no new RPC, no migration.
 */

export type BulkKind =
  | "rooms"
  | "room_types"
  | "ceiling_prices"
  | "minibar_prices";

export type BulkRowErrorCode =
  | "required"
  | "unknown_code"
  | "duplicate"
  | "bad_date"
  | "bad_number"
  | "bad_value"
  | "unknown_uom"
  | "bad_scope";

export type BulkColumnSpec = {
  key: string;
  aliases: string[];
  required: boolean;
};

export const BULK_COLUMNS: Record<BulkKind, BulkColumnSpec[]> = {
  rooms: [
    {
      key: "room_no",
      aliases: ["roomno", "sophong", "phong", "maphong", "roomnumber"],
      required: true,
    },
    { key: "floor", aliases: ["floor", "tang", "lau"], required: false },
    {
      key: "room_type_code",
      aliases: ["roomtypecode", "maloaiphong", "loaiphong", "roomtype"],
      required: true,
    },
  ],
  room_types: [
    { key: "code", aliases: ["code", "ma", "maloaiphong"], required: true },
    { key: "name", aliases: ["name", "ten", "tenloaiphong"], required: true },
    {
      key: "max_guests",
      aliases: ["maxguests", "sokhachtoida", "sokhach", "maxguest"],
      required: false,
    },
  ],
  ceiling_prices: [
    {
      key: "item_code",
      aliases: ["itemcode", "mavat", "mavattu", "mahang", "code"],
      required: true,
    },
    {
      key: "uom",
      aliases: ["uom", "dvt", "donvitinh", "donvi"],
      required: true,
    },
    {
      key: "price",
      aliases: ["price", "gia", "giatran", "dongia"],
      required: true,
    },
    {
      key: "valid_from",
      aliases: ["validfrom", "tungay", "ngayhieuluc", "fromdate"],
      required: true,
    },
    {
      key: "valid_to",
      aliases: ["validto", "denngay", "ngayhethan", "todate"],
      required: true,
    },
    {
      key: "scope",
      aliases: ["scope", "phamvi", "cap"],
      required: false,
    },
  ],
  minibar_prices: [
    {
      key: "item_code",
      aliases: ["itemcode", "mamon", "mavat", "mahang", "code"],
      required: true,
    },
    {
      key: "price",
      aliases: ["price", "gia", "giaban", "dongia"],
      required: true,
    },
    {
      key: "valid_from",
      aliases: ["validfrom", "tungay", "ngayhieuluc", "fromdate"],
      required: true,
    },
    {
      key: "valid_to",
      aliases: ["validto", "denngay", "ngayhethan", "todate"],
      required: false,
    },
  ],
};

export type BulkLookups = {
  roomTypes?: { code: string; id: string }[];
  items?: { code: string; id: string }[];
  uoms?: { code: string }[];
  existingRoomNos?: string[];
  existingRoomTypeCodes?: string[];
};

export type BulkRowError = { field: string; code: BulkRowErrorCode };

export type BulkRow = {
  rowNo: number;
  values: Record<string, string>;
  resolved: Record<string, string | number | null>;
  errors: BulkRowError[];
};

export type BulkFileResult =
  | {
      ok: true;
      headers: string[];
      rows: (string | number | null)[][];
      headerRowNo: number;
    }
  | { ok: false; error: "empty" | "invalid_file" };

export type BulkValidateResult =
  | { ok: true; rows: BulkRow[] }
  | { ok: false; error: "missing_columns"; detail: string };

type RawCell = string | number | null;

function toRawCell(value: unknown): RawCell {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") return value;
  return String(value);
}

/**
 * Read the first sheet (XLSX) or the whole file (CSV) into headers + rows.
 * Returns the 1-based header row number so validation can report the
 * real file row of each bad row.
 */
export function readBulkFile(
  buffer: ArrayBuffer,
  fileName: string,
): BulkFileResult {
  try {
    const lower = fileName.toLowerCase();
    if (lower.endsWith(".csv") || lower.endsWith(".txt")) {
      const text = new TextDecoder("utf-8").decode(buffer);
      const parsed = splitCsv(text);
      if (parsed.length < 2) return { ok: false, error: "empty" };
      return { ok: true, headers: parsed[0] ?? [], rows: parsed.slice(1), headerRowNo: 1 };
    }
    if (lower.endsWith(".xlsx") || lower.endsWith(".xls")) {
      const workbook = read(buffer, { type: "array" });
      const first = workbook.SheetNames[0];
      if (!first) return { ok: false, error: "empty" };
      const grid = getSheetGrid(workbook, first);
      if (grid.length < 2) return { ok: false, error: "empty" };
      const headerRow = detectHeaderRow(grid);
      const headers = (grid[headerRow] ?? []).map((c) => cellToString(c));
      const rows = grid
        .slice(headerRow + 1)
        .map((r) => (r ?? []).map((c) => toRawCell(c)));
      return { ok: true, headers, rows, headerRowNo: headerRow + 1 };
    }
    return { ok: false, error: "invalid_file" };
  } catch {
    return { ok: false, error: "invalid_file" };
  }
}

/** Match file headers to the kind's columns (first unused alias wins). */
export function matchBulkColumns(
  kind: BulkKind,
  headers: string[],
): Record<string, string | null> {
  const used = new Set<number>();
  const out: Record<string, string | null> = {};
  for (const spec of BULK_COLUMNS[kind]) {
    const accepted = new Set([
      normalizeHeaderName(spec.key),
      ...spec.aliases,
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
    out[spec.key] = found;
  }
  return out;
}

function cellText(value: RawCell): string {
  if (value === null) return "";
  if (typeof value === "number") return String(value);
  return value.trim();
}

function findCode<T extends { code: string }>(
  list: T[] | undefined,
  code: string,
): T | undefined {
  const norm = code.trim().toLowerCase();
  return list?.find((x) => x.code.trim().toLowerCase() === norm);
}

/**
 * Validate every row of a bulk file. Returns one `BulkRow` per non-blank
 * row with resolved ids and a list of per-field errors (empty = valid).
 */
export function validateBulkRows(
  kind: BulkKind,
  headers: string[],
  rows: (string | number | null)[][],
  headerRowNo: number,
  lookups: BulkLookups,
): BulkValidateResult {
  const matched = matchBulkColumns(kind, headers);
  const missing = BULK_COLUMNS[kind]
    .filter((s) => s.required && !matched[s.key])
    .map((s) => s.key);
  if (missing.length > 0) {
    return { ok: false, error: "missing_columns", detail: missing.join(", ") };
  }
  const colIndex = (key: string): number => {
    const name = matched[key];
    if (!name) return -1;
    return headers.findIndex((h) => h.trim() === name.trim());
  };
  const idx: Record<string, number> = {};
  for (const spec of BULK_COLUMNS[kind]) idx[spec.key] = colIndex(spec.key);
  const get = (row: RawCell[], key: string): RawCell =>
    idx[key] >= 0 ? (row[idx[key]] ?? null) : null;

  const seenRoomNos = new Set<string>();
  const seenTypeCodes = new Set<string>();
  const out: BulkRow[] = [];
  for (let r = 0; r < rows.length; r++) {
    const row = rows[r] ?? [];
    if (row.every((c) => cellText(c) === "")) continue;
    const values: Record<string, string> = {};
    for (const spec of BULK_COLUMNS[kind]) {
      values[spec.key] = cellText(get(row, spec.key));
    }
    const resolved: Record<string, string | number | null> = {};
    const errors: BulkRowError[] = [];
    const need = (key: string): boolean => {
      if (values[key] === "") {
        errors.push({ field: key, code: "required" });
        return false;
      }
      return true;
    };

    if (kind === "rooms") {
      if (need("room_no") && values.room_no.length > 20) {
        errors.push({ field: "room_no", code: "bad_value" });
      }
      if (values.floor !== "" && values.floor.length > 20) {
        errors.push({ field: "floor", code: "bad_value" });
      }
      const noNorm = values.room_no.trim().toLowerCase();
      if (
        values.room_no !== "" &&
        (seenRoomNos.has(noNorm) ||
          (lookups.existingRoomNos ?? []).some(
            (n) => n.trim().toLowerCase() === noNorm,
          ))
      ) {
        errors.push({ field: "room_no", code: "duplicate" });
      }
      seenRoomNos.add(noNorm);
      if (need("room_type_code")) {
        const found = findCode(lookups.roomTypes, values.room_type_code);
        if (!found) {
          errors.push({ field: "room_type_code", code: "unknown_code" });
        } else {
          resolved.roomTypeId = found.id;
        }
      }
    }

    if (kind === "room_types") {
      if (need("code") && values.code.length > 20) {
        errors.push({ field: "code", code: "bad_value" });
      }
      if (need("name") && values.name.length > 100) {
        errors.push({ field: "name", code: "bad_value" });
      }
      const codeNorm = values.code.trim().toLowerCase();
      if (
        values.code !== "" &&
        (seenTypeCodes.has(codeNorm) ||
          (lookups.existingRoomTypeCodes ?? []).some(
            (c) => c.trim().toLowerCase() === codeNorm,
          ))
      ) {
        errors.push({ field: "code", code: "duplicate" });
      }
      seenTypeCodes.add(codeNorm);
      if (values.max_guests !== "") {
        const n = normalizePosNumber(values.max_guests);
        if (n === null || !/^\d+$/.test(n) || Number(n) < 0) {
          errors.push({ field: "max_guests", code: "bad_number" });
        } else {
          resolved.maxGuests = Number(n);
        }
      }
    }

    if (kind === "ceiling_prices" || kind === "minibar_prices") {
      if (need("item_code")) {
        const found = findCode(lookups.items, values.item_code);
        if (!found) {
          errors.push({ field: "item_code", code: "unknown_code" });
        } else {
          resolved.itemId = found.id;
        }
      }
      if (need("price")) {
        const n = normalizePosNumber(values.price);
        const min = kind === "minibar_prices" ? 1 : 0;
        if (n === null || Number(n) < min) {
          errors.push({ field: "price", code: "bad_number" });
        } else {
          resolved.price = Number(n);
        }
      }
      if (need("valid_from")) {
        const d = normalizePosDate(values.valid_from);
        if (d === null) {
          errors.push({ field: "valid_from", code: "bad_date" });
        } else {
          resolved.validFrom = d;
        }
      }
      const checkValidTo = (raw: string): void => {
        const d = normalizePosDate(raw);
        if (d === null) {
          errors.push({ field: "valid_to", code: "bad_date" });
        } else if (
          typeof resolved.validFrom === "string" &&
          d < resolved.validFrom
        ) {
          errors.push({ field: "valid_to", code: "bad_date" });
        } else {
          resolved.validTo = d;
        }
      };
      // Ceiling prices require valid_to (same contract as the single form);
      // minibar prices accept an open-ended validity.
      if (kind === "ceiling_prices") {
        if (need("valid_to")) checkValidTo(values.valid_to);
      } else if (values.valid_to !== "") {
        checkValidTo(values.valid_to);
      }
    }

    if (kind === "ceiling_prices") {
      if (need("uom")) {
        const found = findCode(lookups.uoms, values.uom);
        if (!found) {
          errors.push({ field: "uom", code: "unknown_uom" });
        } else {
          resolved.uom = found.code;
        }
      }
      if (values.scope !== "") {
        const norm = normalizeHeaderName(values.scope);
        if (norm === "chuoi" || norm === "chain") {
          resolved.scope = "chain";
        } else if (norm === "khachsan" || norm === "property") {
          resolved.scope = "property";
        } else {
          errors.push({ field: "scope", code: "bad_scope" });
        }
      } else {
        resolved.scope = "property";
      }
    }

    out.push({
      rowNo: headerRowNo + r + 1,
      values,
      resolved,
      errors,
    });
  }
  return { ok: true, rows: out };
}
