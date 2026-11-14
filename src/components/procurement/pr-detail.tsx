"use client";

import { InlineConfirmButton } from "@/components/common/inline-confirm-button";
import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { ApprovalTimeline } from "@/components/procurement/approval-timeline";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import {
  cancelPrAction,
  createPoFromPrAction,
  decidePrAction,
  submitPrAction,
} from "@/features/procurement/actions";
import type {
  ApprovalStepRow,
  PrLineRow,
  PrRow,
} from "@/features/procurement/queries";
import type { SupplierRow } from "@/features/master/queries";
import { formatNumber } from "@/components/common/money-text";

/**
 * Chi tiết yêu cầu mua (T-021): thông tin, dòng hàng (kèm số lượng đã
 * chuyển PO), timeline duyệt, và các thao tác theo trạng thái + quyền:
 * sửa nháp, gửi duyệt, duyệt/từ chối theo bước, hủy, tạo đơn mua từ
 * dòng đã duyệt. Giá dòng PO tự lấy theo hợp đồng → giá trần → giá tay
 * (RPC `po_create_from_pr`, T-020) nên form tạo PO chỉ chọn dòng, NCC,
 * kênh mua.
 */
export function PrDetail({
  propertyId,
  pr,
  lines,
  steps,
  suppliers,
}: {
  propertyId: string;
  pr: PrRow;
  lines: PrLineRow[];
  steps: ApprovalStepRow[];
  suppliers: SupplierRow[];
}) {
  const router = useRouter();
  const canPrCreate = useCan("pr.create");
  const canPoCreate = useCan("po.create");

  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Hủy PR
  const [cancelOpen, setCancelOpen] = useState(false);
  const [cancelReason, setCancelReason] = useState("");

  // Tạo PO từ PR
  const [poOpen, setPoOpen] = useState(false);
  const [selectedLineIds, setSelectedLineIds] = useState<string[]>([]);
  const [supplierId, setSupplierId] = useState("");
  const [channel, setChannel] = useState<"contract" | "quote" | "market">(
    "contract",
  );

  const convertibleLines = lines.filter(
    (line) => line.qty - line.converted_qty > 0,
  );

  async function handleSubmit() {
    setBusy(true);
    setError(null);
    const res = await submitPrAction({ propertyId, prId: pr.id });
    setBusy(false);
    if (res.ok) {
      setNotice(vi.procurement.form.submitSuccess);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleCancel(e: React.FormEvent) {
    e.preventDefault();
    if (!cancelReason.trim()) {
      setError(vi.procurement.detail.reasonRequired);
      return;
    }
    setBusy(true);
    setError(null);
    const res = await cancelPrAction({
      propertyId,
      prId: pr.id,
      reason: cancelReason.trim(),
    });
    setBusy(false);
    if (res.ok) {
      setCancelOpen(false);
      setNotice(vi.procurement.form.cancelledSuccess);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  function toggleLine(lineId: string) {
    setSelectedLineIds((prev) =>
      prev.includes(lineId)
        ? prev.filter((id) => id !== lineId)
        : [...prev, lineId],
    );
  }

  async function handleCreatePo(e: React.FormEvent) {
    e.preventDefault();
    if (selectedLineIds.length === 0) {
      setError(vi.procurement.form.selectAtLeastOneLine);
      return;
    }
    if (!supplierId) {
      setError(vi.procurement.form.selectSupplierFirst);
      return;
    }
    setBusy(true);
    setError(null);
    const res = await createPoFromPrAction({
      propertyId,
      prLineIds: selectedLineIds,
      supplierId,
      channel,
    });
    setBusy(false);
    if (res.ok) {
      setPoOpen(false);
      router.push(`/${propertyId}/procurement/po/${res.data.id}`);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const isDraftLike = pr.status === "draft" || pr.status === "rejected";

  return (
    <div className="space-y-4">
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

      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div>
          <Link
            href={`/${propertyId}/procurement/pr`}
            className="text-sm text-primary hover:underline"
          >
            ← {vi.procurement.list.backToList}
          </Link>
          <div className="mt-2 flex items-center gap-3 flex-wrap">
            <h2 className="text-lg font-semibold font-mono">{pr.doc_no}</h2>
            <DocStatusBadge status={pr.status} />
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            {pr.kind === "service"
              ? vi.procurement.pr.kindService
              : vi.procurement.pr.kindStock}
            {pr.outlet_name ? ` · ${pr.outlet_name}` : ""}
            {pr.need_date
              ? ` · ${vi.procurement.pr.needDate}: ${new Date(pr.need_date).toLocaleDateString("vi-VN")}`
              : ""}
          </p>
          {pr.note ? <p className="mt-1 text-sm">{pr.note}</p> : null}
        </div>

        <div className="flex gap-2 flex-wrap">
          {isDraftLike && canPrCreate ? (
            <>
              <Button
                size="sm"
                variant="outline"
                onClick={() =>
                  router.push(`/${propertyId}/procurement/pr/${pr.id}/edit`)
                }
              >
                {vi.procurement.detail.editDraft}
              </Button>
              <InlineConfirmButton
                size="sm"
                label={vi.procurement.pr.submit}
                confirmText={vi.procurement.detail.confirmSubmit}
                onConfirm={handleSubmit}
                disabled={busy}
              />
              <Button
                size="sm"
                variant="outline"
                className="text-destructive hover:bg-destructive/10"
                onClick={() => {
                  setCancelReason("");
                  setCancelOpen(true);
                }}
              >
                {vi.procurement.pr.cancel}
              </Button>
            </>
          ) : null}
          {pr.status === "approved" && canPoCreate ? (
            <Button
              size="sm"
              onClick={() => {
                setSelectedLineIds(convertibleLines.map((l) => l.id));
                setSupplierId("");
                setChannel("contract");
                setError(null);
                setPoOpen(true);
              }}
            >
              {vi.procurement.pr.createPo}
            </Button>
          ) : null}
        </div>
      </div>

      <div className="rounded-lg border p-4">
        <h3 className="font-semibold text-sm mb-3">
          {vi.procurement.list.lines} ({lines.length})
        </h3>
        {lines.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.procurement.list.noLines}
          </p>
        ) : (
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.procurement.form.item}
                </th>
                <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.procurement.form.qty}
                </th>
                <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.procurement.form.uom}
                </th>
                <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.procurement.detail.convertedQty}
                </th>
                <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.procurement.detail.remainingQty}
                </th>
                <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.procurement.form.reason}
                </th>
              </tr>
            </thead>
            <tbody>
              {lines.map((line) => (
                <tr key={line.id} className="border-t hover:bg-muted/40">
                  <td className="py-3 pr-3 align-middle">
                    {line.item_code ? (
                      <>
                        <span className="font-mono text-xs font-bold">
                          {line.item_code}
                        </span>{" "}
                        <span className="font-medium">{line.item_name}</span>
                      </>
                    ) : (
                      <span>{line.description}</span>
                    )}
                    {line.description && line.item_code ? (
                      <p className="text-xs text-muted-foreground">
                        {line.description}
                      </p>
                    ) : null}
                  </td>
                  <td className="py-3 pr-3 text-right tabular-nums align-middle">
                    {formatNumber(line.qty)}
                  </td>
                  <td className="py-3 pr-3 align-middle">{line.uom}</td>
                  <td className="py-3 pr-3 text-right tabular-nums align-middle">
                    {formatNumber(line.converted_qty)}
                  </td>
                  <td className="py-3 pr-3 text-right tabular-nums align-middle">
                    {formatNumber(line.qty - line.converted_qty)}
                  </td>
                  <td className="py-3 pr-3 text-muted-foreground align-middle">
                    {line.reason ?? "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      <ApprovalTimeline
        steps={steps}
        onDecide={async (decision, comment) =>
          decidePrAction({
            propertyId,
            prId: pr.id,
            decision,
            comment,
          })
        }
      />

      {cancelOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">{vi.procurement.pr.cancel}</h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setCancelOpen(false)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleCancel} className="mt-4 space-y-3">
              <p className="text-sm text-muted-foreground">
                {vi.procurement.detail.confirmCancel}
              </p>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.detail.cancelReason} *
                </label>
                <textarea
                  required
                  value={cancelReason}
                  onChange={(e) => setCancelReason(e.target.value)}
                  placeholder={vi.procurement.detail.reasonPlaceholder}
                  className="mt-1 min-h-20 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setCancelOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={busy}>
                  {busy ? vi.common.loading : vi.common.confirm}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}

      {poOpen ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-lg rounded-xl border bg-background p-6 shadow-lg max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">{vi.procurement.pr.createPo}</h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setPoOpen(false)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleCreatePo} className="mt-4 space-y-3">
              <p className="text-xs text-muted-foreground">
                {vi.procurement.detail.channelHint}
              </p>
              <div>
                <p className="text-xs font-medium text-muted-foreground mb-1">
                  {vi.procurement.detail.selectLines}
                </p>
                {convertibleLines.length === 0 ? (
                  <p className="text-sm text-muted-foreground">
                    {vi.procurement.list.noLines}
                  </p>
                ) : (
                  <div className="space-y-1">
                    <label className="flex items-center gap-2 rounded-md border px-3 py-2 text-sm cursor-pointer hover:bg-muted/50 font-medium">
                      <input
                        type="checkbox"
                        checked={
                          selectedLineIds.length === convertibleLines.length
                        }
                        onChange={() =>
                          setSelectedLineIds(
                            selectedLineIds.length === convertibleLines.length
                              ? []
                              : convertibleLines.map((l) => l.id),
                          )
                        }
                      />
                      {vi.procurement.detail.selectAll}
                    </label>
                    {convertibleLines.map((line) => (
                      <label
                        key={line.id}
                        className="flex items-center gap-2 rounded-md border px-3 py-2 text-sm cursor-pointer hover:bg-muted/50"
                      >
                        <input
                          type="checkbox"
                          checked={selectedLineIds.includes(line.id)}
                          onChange={() => toggleLine(line.id)}
                        />
                        <span className="min-w-0 flex-1">
                          {line.item_code ? (
                            <>
                              <span className="font-mono text-xs font-bold">
                                {line.item_code}
                              </span>{" "}
                              {line.item_name}
                            </>
                          ) : (
                            line.description
                          )}
                        </span>
                        <span className="text-xs text-muted-foreground whitespace-nowrap">
                          {formatNumber(line.qty - line.converted_qty)}{" "}
                          {line.uom}
                        </span>
                      </label>
                    ))}
                  </div>
                )}
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.po.supplier} *
                </label>
                <select
                  required
                  value={supplierId}
                  onChange={(e) => setSupplierId(e.target.value)}
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">—</option>
                  {suppliers.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.code} · {s.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.po.channel} *
                </label>
                <select
                  value={channel}
                  onChange={(e) =>
                    setChannel(
                      e.target.value as "contract" | "quote" | "market",
                    )
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="contract">
                    {vi.procurement.po.channelContract}
                  </option>
                  <option value="quote">
                    {vi.procurement.po.channelQuote}
                  </option>
                  <option value="market">
                    {vi.procurement.po.channelMarket}
                  </option>
                </select>
                {channel === "market" ? (
                  <p className="mt-1 text-xs text-amber-700">
                    {vi.procurement.detail.marketChannelWarning}
                  </p>
                ) : null}
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setPoOpen(false)}
                >
                  {vi.common.cancel}
                </Button>
                <Button type="submit" disabled={busy}>
                  {busy ? vi.common.loading : vi.procurement.pr.createPo}
                </Button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  );
}
