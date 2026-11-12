"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import {
  BULK_COLUMNS,
  readBulkFile,
  validateBulkRows,
  type BulkKind,
  type BulkLookups,
  type BulkRow,
  type BulkRowError,
} from "@/lib/master/bulk-import";

type SaveResult = { ok: true } | { ok: false; error: string };

/**
 * Dialog nhập hàng loạt danh mục (M-02): chọn file CSV/XLSX, xem trước
 * từng dòng + lỗi từng dòng, rồi lưu từng dòng hợp lệ qua action lưu
 * từng dòng đã có (không RPC mới, không migration).
 */
export function BulkImportDialog({
  kind,
  lookups,
  saveRow,
  onClose,
  onDone,
}: {
  kind: BulkKind;
  lookups: BulkLookups;
  saveRow: (row: BulkRow) => Promise<SaveResult>;
  onClose: () => void;
  onDone: () => void;
}) {
  const t = vi.master.bulkImport;
  const columns = BULK_COLUMNS[kind];
  const labels = t.columns[kind];
  const [reading, setReading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [rows, setRows] = useState<BulkRow[] | null>(null);
  const [results, setResults] = useState<
    { rowNo: number; ok: boolean; error?: string }[] | null
  >(null);

  function formatError(e: BulkRowError): string {
    const field = (labels as Record<string, string>)[e.field] ?? e.field;
    switch (e.code) {
      case "required":
        return t.errRequired.replace("{field}", field);
      case "unknown_code":
        return t.errUnknownCode.replace("{field}", field);
      case "duplicate":
        return t.errDuplicate.replace("{field}", field);
      case "bad_date":
        return t.errBadDate.replace("{field}", field);
      case "bad_number":
        return t.errBadNumber.replace("{field}", field);
      case "unknown_uom":
        return t.errUnknownUom.replace("{field}", field);
      case "bad_scope":
        return t.errBadScope.replace("{field}", field);
      default:
        return t.errBadValue.replace("{field}", field);
    }
  }

  async function handleFile(file: File | undefined) {
    setError(null);
    setRows(null);
    setResults(null);
    if (!file) return;
    setReading(true);
    try {
      const buffer = await file.arrayBuffer();
      const readRes = readBulkFile(buffer, file.name);
      if (!readRes.ok) {
        setError(
          readRes.error === "empty" ? t.parseEmpty : t.invalidFile,
        );
        return;
      }
      const validated = validateBulkRows(
        kind,
        readRes.headers,
        readRes.rows,
        readRes.headerRowNo,
        lookups,
      );
      if (!validated.ok) {
        const names = validated.detail
          .split(", ")
          .map((k) => (labels as Record<string, string>)[k] ?? k)
          .join(", ");
        setError(t.parseMissingColumns.replace("{columns}", names));
        return;
      }
      setRows(validated.rows);
    } catch {
      setError(t.invalidFile);
    } finally {
      setReading(false);
    }
  }

  const validRows = (rows ?? []).filter((r) => r.errors.length === 0);
  const okCount = (results ?? []).filter((r) => r.ok).length;
  const failCount = (results ?? []).filter((r) => !r.ok).length;

  async function handleImport() {
    if (validRows.length === 0 || submitting) return;
    setSubmitting(true);
    const out: { rowNo: number; ok: boolean; error?: string }[] = [];
    for (const row of validRows) {
      try {
        const res = await saveRow(row);
        out.push(
          res.ok
            ? { rowNo: row.rowNo, ok: true }
            : { rowNo: row.rowNo, ok: false, error: res.error },
        );
      } catch {
        out.push({ rowNo: row.rowNo, ok: false, error: t.saveFailed });
      }
    }
    setResults(out);
    setSubmitting(false);
  }

  return (
    <div className="space-y-4 rounded-lg border bg-card p-4">
      <div className="flex items-center justify-between gap-2">
        <p className="font-medium">{t.titles[kind]}</p>
        <Button variant="ghost" size="sm" onClick={onClose}>
          {t.close}
        </Button>
      </div>
      <p className="text-sm text-muted-foreground">{t.description}</p>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">{t.chooseFile}</span>
        <input
          type="file"
          accept=".csv,text/csv,.xlsx,.xls,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,application/vnd.ms-excel"
          onChange={(e) => void handleFile(e.target.files?.[0])}
          className="block w-full text-sm"
        />
      </label>
      {reading ? (
        <p className="text-sm text-muted-foreground">{t.readingFile}</p>
      ) : null}
      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}
      {rows ? (
        <div>
          <p className="text-sm font-medium">
            {t.previewTitle
              .replace("{shown}", String(Math.min(20, rows.length)))
              .replace("{rows}", String(rows.length))}
          </p>
          {rows.length === 0 ? (
            <p className="mt-2 text-sm text-muted-foreground">{t.noRows}</p>
          ) : (
            <div className="mt-2 overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b">
                    <th className="px-2 py-1 font-medium">{t.rowCol}</th>
                    {columns.map((c) => (
                      <th key={c.key} className="px-2 py-1 font-medium">
                        {(labels as Record<string, string>)[c.key] ?? c.key}
                      </th>
                    ))}
                    <th className="px-2 py-1 font-medium">{t.errorsCol}</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.slice(0, 20).map((row) => (
                    <tr key={row.rowNo} className="border-b align-top">
                      <td className="px-2 py-1">{row.rowNo}</td>
                      {columns.map((c) => (
                        <td key={c.key} className="px-2 py-1">
                          {row.values[c.key] ?? ""}
                        </td>
                      ))}
                      <td className="px-2 py-1 text-destructive">
                        {row.errors.map(formatError).join("; ")}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      ) : null}
      {results ? (
        <div className="rounded-md border p-3 text-sm">
          <p className="font-medium">
            {t.doneSummary
              .replace("{ok}", String(okCount))
              .replace("{fail}", String(failCount))}
          </p>
          {failCount > 0 ? (
            <ul className="mt-2 list-disc pl-5 text-destructive">
              {results
                .filter((r) => !r.ok)
                .map((r) => (
                  <li key={r.rowNo}>
                    {t.rowCol} {r.rowNo}: {r.error}
                  </li>
                ))}
            </ul>
          ) : null}
          <Button className="mt-3" onClick={onDone}>
            {t.close}
          </Button>
        </div>
      ) : (
        <Button
          onClick={handleImport}
          disabled={submitting || reading || validRows.length === 0}
        >
          {submitting
            ? t.importing
            : t.import.replace("{count}", String(validRows.length))}
        </Button>
      )}
    </div>
  );
}
