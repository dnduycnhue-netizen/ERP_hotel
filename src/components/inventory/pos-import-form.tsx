"use client";

import { useMemo, useState } from "react";
import { read } from "xlsx";
import { Button } from "@/components/ui/button";
import { importPosAction } from "@/features/pos-import/actions";
import { vi } from "@/i18n/vi";
import {
  cellToString,
  detectHeaderRow,
  getSheetGrid,
} from "@/lib/import/xlsx";
import {
  guessPosMapping,
  loadSavedPosMapping,
  mapRowsToLines,
  savePosMapping,
  POS_REQUIRED_FIELDS,
  POS_TARGET_FIELDS,
  type PosColumnMapping,
  type PosTargetField,
} from "@/lib/pos/column-mapping";
import { splitCsv, type PosCsvLine } from "@/lib/pos/parse-csv";

async function sha256Hex(buffer: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", buffer);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

type RawCell = string | number | null;

function toRawCell(value: unknown): RawCell {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") return value;
  return String(value);
}

const PREVIEW_FIELDS: PosTargetField[] = [
  "bill_no",
  "business_date",
  "shift",
  "item_code",
  "qty",
  "unit_price",
  "amount",
];

/**
 * Form nạp file POS của ca (Q34, M-01): đọc CSV/XLSX phía trình duyệt,
 * cho người dùng ánh xạ cột nguồn sang trường đích, xem trước 20 dòng,
 * rồi gọi RPC qua `importPosAction` (không đổi server action / RPC).
 */
export function PosImportForm({ propertyId }: { propertyId: string }) {
  const t = vi.inventory.posImport;
  const [fileName, setFileName] = useState<string | null>(null);
  const [sha, setSha] = useState<string | null>(null);
  const [headers, setHeaders] = useState<string[]>([]);
  const [rawRows, setRawRows] = useState<RawCell[][]>([]);
  const [mapping, setMapping] = useState<PosColumnMapping | null>(null);
  const [reading, setReading] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [unmapped, setUnmapped] = useState<string[]>([]);

  const mapped = useMemo(() => {
    if (!mapping || headers.length === 0) return null;
    return mapRowsToLines(headers, rawRows, mapping);
  }, [headers, rawRows, mapping]);

  const lines: PosCsvLine[] = mapped?.ok ? mapped.lines : [];
  const mapError =
    mapped && !mapped.ok
      ? mapped.error === "empty"
        ? t.parseEmpty
        : mapped.error === "missing_columns"
          ? t.parseMissingColumns.replace("{columns}", mapped.detail)
          : t.parseBadRow.replace("{row}", mapped.detail)
      : null;

  function reset() {
    setError(null);
    setNotice(null);
    setUnmapped([]);
    setSha(null);
    setFileName(null);
    setHeaders([]);
    setRawRows([]);
    setMapping(null);
  }

  async function handleFile(file: File | undefined) {
    reset();
    if (!file) return;
    setReading(true);
    try {
      const buffer = await file.arrayBuffer();
      const lower = file.name.toLowerCase();
      let heads: string[] = [];
      let rows: RawCell[][] = [];
      if (lower.endsWith(".csv") || lower.endsWith(".txt")) {
        const text = new TextDecoder("utf-8").decode(buffer);
        const parsed = splitCsv(text);
        if (parsed.length < 2) {
          setError(t.parseEmpty);
          return;
        }
        heads = parsed[0] ?? [];
        rows = parsed.slice(1);
      } else if (lower.endsWith(".xlsx") || lower.endsWith(".xls")) {
        const workbook = read(buffer, { type: "array" });
        const first = workbook.SheetNames[0];
        if (!first) {
          setError(t.parseEmpty);
          return;
        }
        const grid = getSheetGrid(workbook, first);
        if (grid.length < 2) {
          setError(t.parseEmpty);
          return;
        }
        const headerRow = detectHeaderRow(grid);
        heads = (grid[headerRow] ?? []).map((c) => cellToString(c));
        rows = grid
          .slice(headerRow + 1)
          .map((r) => (r ?? []).map((c) => toRawCell(c)));
      } else {
        setError(t.invalidFile);
        return;
      }
      if (heads.every((h) => h.trim() === "")) {
        setError(t.parseEmpty);
        return;
      }
      const guessed = guessPosMapping(heads);
      const saved = loadSavedPosMapping();
      if (saved) {
        for (const field of POS_TARGET_FIELDS) {
          const name = saved[field];
          if (name && heads.some((h) => h.trim() === name.trim())) {
            guessed[field] = name;
          }
        }
      }
      setFileName(file.name);
      setSha(await sha256Hex(buffer));
      setHeaders(heads);
      setRawRows(rows);
      setMapping(guessed);
    } catch {
      setError(t.invalidFile);
    } finally {
      setReading(false);
    }
  }

  async function handleUpload() {
    if (!fileName || !sha || !mapping || !mapped?.ok || lines.length === 0) {
      return;
    }
    setBusy(true);
    setError(null);
    setNotice(null);
    savePosMapping(mapping);
    const res = await importPosAction({
      propertyId,
      fileName,
      sha256: sha,
      lines,
    });
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setNotice(
      t.success
        .replace("{rows}", String(res.data.rows))
        .replace("{imports}", String(res.data.imports)),
    );
    setUnmapped(res.data.unmappedCodes);
    setHeaders([]);
    setRawRows([]);
    setMapping(null);
    setSha(null);
    setFileName(null);
  }

  const usedByOther = (field: PosTargetField, value: string): boolean =>
    mapping !== null &&
    POS_TARGET_FIELDS.some((f) => f !== field && mapping[f] === value);

  return (
    <div className="max-w-2xl space-y-4">
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
      {error || mapError ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error ?? mapError}
        </div>
      ) : null}
      {notice ? (
        <div className="rounded-md border border-emerald-500/20 bg-emerald-500/10 p-3 text-sm text-emerald-700">
          {notice}
        </div>
      ) : null}
      {mapping ? (
        <div className="space-y-4">
          <div>
            <p className="text-sm font-medium">{t.mappingTitle}</p>
            <p className="text-sm text-muted-foreground">{t.mappingHint}</p>
            <div className="mt-2 space-y-2">
              {POS_TARGET_FIELDS.map((field) => (
                <label
                  key={field}
                  className="grid grid-cols-2 items-center gap-2 text-sm"
                >
                  <span>
                    {t.fields[field]}
                    {POS_REQUIRED_FIELDS.includes(field) ? " *" : ""}
                  </span>
                  <select
                    value={mapping[field] ?? ""}
                    onChange={(e) =>
                      setMapping({
                        ...mapping,
                        [field]: e.target.value === "" ? null : e.target.value,
                      })
                    }
                    className="rounded-md border px-2 py-1 text-sm"
                  >
                    <option value="">{t.notUsed}</option>
                    {headers.map((h) => (
                      <option
                        key={h}
                        value={h}
                        disabled={usedByOther(field, h)}
                      >
                        {h}
                      </option>
                    ))}
                  </select>
                </label>
              ))}
            </div>
            {mapped && !mapped.ok && mapped.error === "missing_columns" ? (
              <p className="mt-2 text-sm text-destructive">
                {t.mappingIncomplete.replace("{columns}", mapped.detail)}
              </p>
            ) : null}
          </div>
          {mapped?.ok ? (
            <div>
              <p className="text-sm font-medium">
                {t.previewTitle
                  .replace("{shown}", String(Math.min(20, lines.length)))
                  .replace("{rows}", String(lines.length))}
              </p>
              {lines.length === 0 ? (
                <p className="text-sm text-muted-foreground">
                  {t.previewEmpty}
                </p>
              ) : (
                <div className="mt-2 overflow-x-auto">
                  <table className="w-full text-left text-xs">
                    <thead>
                      <tr className="border-b">
                        {PREVIEW_FIELDS.map((f) => (
                          <th key={f} className="px-2 py-1 font-medium">
                            {t.fields[f]}
                          </th>
                        ))}
                      </tr>
                    </thead>
                    <tbody>
                      {lines.slice(0, 20).map((line, i) => (
                        <tr key={`${line.bill_no}-${i}`} className="border-b">
                          {PREVIEW_FIELDS.map((f) => (
                            <td key={f} className="px-2 py-1">
                              {line[f]}
                            </td>
                          ))}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          ) : null}
        </div>
      ) : null}
      {unmapped.length > 0 ? (
        <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3 text-sm">
          <p className="font-medium">{t.unmappedTitle}</p>
          <p className="mt-1 font-mono">{unmapped.join(", ")}</p>
        </div>
      ) : null}
      <Button
        onClick={handleUpload}
        disabled={busy || reading || !mapped?.ok || lines.length === 0}
      >
        {busy ? t.uploading : t.upload}
      </Button>
    </div>
  );
}
