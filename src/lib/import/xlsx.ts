import { read, utils, writeFile, type WorkBook } from "xlsx";

/**
 * Doc/ghi file .xlsx phia client (T-014). Chi parse thanh JSON tho;
 * moi logic nghiep vu (chuan hoa, validate, ghi) nam trong SQL.
 */

export type SheetInfo = {
  name: string;
  rowCount: number;
  headers: (string | null)[];
};

export type ParsedWorkbook = {
  workbook: WorkBook;
  sheets: SheetInfo[];
};

/** Doc workbook tu ArrayBuffer; tra ve danh sach sheet + header dong dau. */
export function parseWorkbook(buffer: ArrayBuffer): ParsedWorkbook {
  const workbook = read(buffer, { type: "array" });
  const sheets: SheetInfo[] = workbook.SheetNames.map((name) => {
    const ws = workbook.Sheets[name];
    const grid = utils.sheet_to_json(ws, {
      header: 1,
      raw: true,
      defval: null,
    }) as unknown[][];
    return {
      name,
      rowCount: grid.length,
      headers: (grid[0] ?? []).map((h) =>
        h === null || h === undefined ? null : String(h),
      ),
    };
  });
  return { workbook, sheets };
}

/** Lay toan bo luoi o (raw) cua 1 sheet: hang = mang gia tri o. */
export function getSheetGrid(
  workbook: WorkBook,
  sheetName: string,
): unknown[][] {
  const ws = workbook.Sheets[sheetName];
  if (!ws) return [];
  return utils.sheet_to_json(ws, {
    header: 1,
    raw: true,
    defval: null,
  }) as unknown[][];
}

/** Tim dong tieu de: dong dau tien co >= 2 o chu khong rong. */
export function detectHeaderRow(grid: unknown[][]): number {
  for (let i = 0; i < Math.min(grid.length, 20); i++) {
    const row = grid[i] ?? [];
    const strings = row.filter(
      (c) => typeof c === "string" && c.trim() !== "",
    ).length;
    if (strings >= 2) return i;
  }
  return 0;
}

export function cellToString(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "number") return String(value);
  return String(value).trim();
}

export function cellToNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const s = value.trim();
    if (s === "") return null;
    const n = Number(s.replace(/\s/g, "").replace(",", "."));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

/**
 * Khoi phuc ma tu cot "Ma va ten" (vd. "CB025 sot mu tac vang" -> CB025).
 * Chi nhan khi token dau co ca chu va so (tranh doan nham ten thuong
 * nhu "laghim cat san" thanh ma).
 */
export function extractCodeFromCombined(value: unknown): {
  code: string | null;
  rest: string;
} {
  const text = cellToString(value);
  const match = text.match(/^([A-Za-z]{1,4}[-_]?\d{1,6})\s+(.+)$/);
  if (!match) return { code: null, rest: text };
  return { code: match[1].toUpperCase(), rest: match[2].trim() };
}

export type ImportResultRow = {
  rowNo: number;
  code: string;
  name: string;
  status: string;
  issues: string;
};

/** Xuat bao cao ket qua import (Excel) de tai ve sau buoc 4. */
export function downloadResultReport(
  fileName: string,
  summary: { created: number; skipped: number; merged: number },
  rows: ImportResultRow[],
): void {
  const wb = utils.book_new();
  const summarySheet = utils.json_to_sheet([
    { "Chỉ tiêu": "Tạo mới", "Số lượng": summary.created },
    { "Chỉ tiêu": "Bỏ qua", "Số lượng": summary.skipped },
    { "Chỉ tiêu": "Gộp", "Số lượng": summary.merged },
  ]);
  utils.book_append_sheet(wb, summarySheet, "Tóm tắt");
  const detailSheet = utils.json_to_sheet(
    rows.map((r) => ({
      Dòng: r.rowNo,
      Mã: r.code,
      Tên: r.name,
      "Trạng thái": r.status,
      "Vấn đề": r.issues,
    })),
  );
  utils.book_append_sheet(wb, detailSheet, "Chi tiết");
  writeFile(wb, fileName);
}
