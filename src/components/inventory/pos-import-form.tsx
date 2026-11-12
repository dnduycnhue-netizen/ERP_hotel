"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { importPosAction } from "@/features/pos-import/actions";
import { vi } from "@/i18n/vi";
import { parsePosCsv, type PosCsvLine } from "@/lib/pos/parse-csv";

async function sha256Hex(buffer: ArrayBuffer): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", buffer);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/** Form nạp file POS của ca (Q34): đọc CSV phía trình duyệt rồi gọi RPC. */
export function PosImportForm({ propertyId }: { propertyId: string }) {
  const t = vi.inventory.posImport;
  const [fileName, setFileName] = useState<string | null>(null);
  const [sha, setSha] = useState<string | null>(null);
  const [lines, setLines] = useState<PosCsvLine[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [unmapped, setUnmapped] = useState<string[]>([]);

  async function handleFile(file: File | undefined) {
    setError(null);
    setNotice(null);
    setUnmapped([]);
    setLines([]);
    setSha(null);
    setFileName(null);
    if (!file) return;
    const buffer = await file.arrayBuffer();
    const parsed = parsePosCsv(new TextDecoder("utf-8").decode(buffer));
    if (!parsed.ok) {
      setError(
        parsed.error === "empty"
          ? t.parseEmpty
          : parsed.error === "missing_columns"
            ? t.parseMissingColumns.replace("{columns}", parsed.detail)
            : t.parseBadRow.replace("{row}", parsed.detail),
      );
      return;
    }
    setFileName(file.name);
    setSha(await sha256Hex(buffer));
    setLines(parsed.lines);
    setNotice(t.readyRows.replace("{rows}", String(parsed.lines.length)));
  }

  async function handleUpload() {
    if (!fileName || !sha || lines.length === 0) return;
    setBusy(true);
    setError(null);
    setNotice(null);
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
    setLines([]);
    setSha(null);
  }

  return (
    <div className="max-w-2xl space-y-4">
      <p className="text-sm text-muted-foreground">{t.description}</p>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">{t.chooseFile}</span>
        <input
          type="file"
          accept=".csv,text/csv"
          onChange={(e) => void handleFile(e.target.files?.[0])}
          className="block w-full text-sm"
        />
      </label>
      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}
      {notice ? (
        <div className="rounded-md border border-emerald-500/20 bg-emerald-500/10 p-3 text-sm text-emerald-700">
          {notice}
        </div>
      ) : null}
      {unmapped.length > 0 ? (
        <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3 text-sm">
          <p className="font-medium">{t.unmappedTitle}</p>
          <p className="mt-1 font-mono">{unmapped.join(", ")}</p>
        </div>
      ) : null}
      <Button onClick={handleUpload} disabled={busy || lines.length === 0}>
        {busy ? t.uploading : t.upload}
      </Button>
    </div>
  );
}
