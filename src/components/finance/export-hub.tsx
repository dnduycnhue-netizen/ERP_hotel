"use client";

import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import type { PaymentRequestRow } from "@/features/finance/queries";
import {
  EXPORT_KINDS,
  getExportDefinition,
  type ExportKind,
} from "@/features/export/definitions";
import {
  buildAccountingExportUrl,
  buildBankTransferUrl,
  downloadExportFile,
  formatDateTimeVn,
  formatDateVn,
  monthStartOf,
  todayVn,
} from "@/features/export/hub";
import type { PropertyLegalEntity } from "@/features/export/queries";
import { vi } from "@/i18n/vi";

/**
 * Form xuất Excel kế toán T-043 (C4): chọn loại file + khoảng ngày rồi
 * tải qua GET /api/export/[kind]?entity=&from=&to=. Pháp nhân lấy theo
 * khách sạn đang chọn (không cho đổi — xuất T-043 theo pháp nhân).
 */
export function AccountingExportForm({
  entity,
}: {
  entity: PropertyLegalEntity;
}) {
  const [kind, setKind] = useState<ExportKind>("goods-receipts");
  const [from, setFrom] = useState(() => monthStartOf(todayVn()));
  const [to, setTo] = useState(() => todayVn());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onDownload() {
    if (from > to) {
      setError(vi.export.hub.invalidRange);
      return;
    }
    setError(null);
    setBusy(true);
    const result = await downloadExportFile(
      buildAccountingExportUrl(kind, entity.id, from, to),
      vi.export.exportFailed,
    );
    setBusy(false);
    if (!result.ok) setError(result.error);
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        {vi.export.meta.entity}: {entity.name} ({entity.code})
      </p>
      <div className="flex flex-wrap items-end gap-3">
        <label className="block text-sm">
          {vi.export.hub.kindLabel}
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value as ExportKind)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            {EXPORT_KINDS.map((k) => {
              const def = getExportDefinition(k);
              return (
                <option key={k} value={k}>
                  {def?.title ?? k}
                </option>
              );
            })}
          </select>
        </label>
        <label className="block text-sm">
          {vi.export.hub.fromLabel}
          <input
            type="date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <label className="block text-sm">
          {vi.export.hub.toLabel}
          <input
            type="date"
            value={to}
            onChange={(e) => setTo(e.target.value)}
            className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <Button onClick={onDownload} disabled={busy}>
          {busy ? vi.export.hub.downloading : vi.export.hub.downloadButton}
        </Button>
      </div>
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
}

/**
 * Chọn đề nghị thanh toán đã duyệt rồi xuất file chuyển khoản (C4):
 * GET /api/export/bank-transfer?ids=... (C3). Đề nghị đã xuất trước đây
 * chỉ cảnh báo (C3 không chặn xuất lại) — không chặn cứng.
 */
export function BankTransferExportPanel({
  requests,
  previouslyExported,
  historyAvailable,
}: {
  requests: PaymentRequestRow[];
  previouslyExported: Record<string, string>;
  historyAvailable: boolean;
}) {
  const [selected, setSelected] = useState<ReadonlySet<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const selectedRows = useMemo(
    () => requests.filter((r) => selected.has(r.id)),
    [requests, selected],
  );
  const selectedTotal = useMemo(
    () => selectedRows.reduce((s, r) => s + r.total, 0),
    [selectedRows],
  );
  const previouslyExportedSelected = useMemo(
    () => selectedRows.filter((r) => previouslyExported[r.id]),
    [selectedRows, previouslyExported],
  );

  function toggle(id: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function toggleAll() {
    setSelected((prev) =>
      prev.size === requests.length
        ? new Set()
        : new Set(requests.map((r) => r.id)),
    );
  }

  async function onExport() {
    if (selected.size === 0) {
      setError(vi.export.hub.selectAtLeastOne);
      return;
    }
    const url = buildBankTransferUrl([...selected]);
    if (!url) {
      setError(vi.export.hub.selectAtLeastOne);
      return;
    }
    setError(null);
    setBusy(true);
    const result = await downloadExportFile(url, vi.export.exportFailed);
    setBusy(false);
    if (!result.ok) setError(result.error);
  }

  if (requests.length === 0) {
    return (
      <p className="text-sm text-muted-foreground">
        {vi.export.hub.noApprovedRequests}
      </p>
    );
  }

  return (
    <div className="space-y-3">
      {!historyAvailable && (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          {vi.export.hub.historyUnknownWarning}
        </p>
      )}
      {previouslyExportedSelected.length > 0 && (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          {vi.export.hub.alreadyExportedWarning.replace(
            "{count}",
            String(previouslyExportedSelected.length),
          )}{" "}
          ({previouslyExportedSelected.map((r) => r.doc_no).join(", ")})
        </p>
      )}
      <div className="w-full overflow-x-auto rounded-lg border bg-card">
        <table className="w-full text-sm">
          <thead className="bg-muted/40 text-left">
            <tr>
              <th scope="col" className="px-3 py-2.5">
                <input
                  type="checkbox"
                  checked={
                    requests.length > 0 && selected.size === requests.length
                  }
                  onChange={toggleAll}
                  aria-label={vi.export.hub.selectAll}
                />
              </th>
              <th
                scope="col"
                className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase"
              >
                {vi.export.columns.docNo}
              </th>
              <th
                scope="col"
                className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase"
              >
                {vi.finance.supplier}
              </th>
              <th
                scope="col"
                className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase"
              >
                {vi.finance.dueDate}
              </th>
              <th
                scope="col"
                className="px-3 py-2.5 text-right text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase"
              >
                {vi.export.columns.amount}
              </th>
              <th
                scope="col"
                className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase"
              >
                {vi.export.hub.alreadyExported}
              </th>
            </tr>
          </thead>
          <tbody>
            {requests.map((r) => {
              const exportedAt = previouslyExported[r.id];
              return (
                <tr key={r.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 align-middle">
                    <input
                      type="checkbox"
                      checked={selected.has(r.id)}
                      onChange={() => toggle(r.id)}
                      aria-label={r.doc_no}
                    />
                  </td>
                  <td className="px-3 py-3 font-medium align-middle">
                    {r.doc_no}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {r.supplier_name ?? r.supplier_code ?? "—"}
                  </td>
                  <td className="px-3 py-3 whitespace-nowrap align-middle">
                    {formatDateVn(r.due_date) ?? "—"}
                  </td>
                  <td className="px-3 py-3 text-right whitespace-nowrap align-middle">
                    <MoneyText amount={r.total} />
                  </td>
                  <td className="px-3 py-3 whitespace-nowrap align-middle">
                    {exportedAt ? (
                      <span className="text-amber-800">
                        {formatDateTimeVn(exportedAt)}
                      </span>
                    ) : (
                      "—"
                    )}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      <div className="flex flex-wrap items-center gap-3">
        <Button onClick={onExport} disabled={busy || selected.size === 0}>
          {busy
            ? vi.export.hub.downloading
            : vi.export.hub.exportBankTransferButton}
        </Button>
        <p className="text-sm text-muted-foreground">
          {vi.export.hub.selectedCount.replace(
            "{count}",
            String(selected.size),
          )}{" "}
          · {vi.export.hub.totalAmount}: <MoneyText amount={selectedTotal} />
        </p>
      </div>
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
