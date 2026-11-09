"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { ApprovalTimeline } from "@/components/procurement/approval-timeline";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import {
  cancelPoAction,
  closePoAction,
  decideApprovalAction,
  sendPoAction,
  submitPoAction,
} from "@/features/procurement/actions";
import type {
  ApprovalStepRow,
  PoLineRow,
  PoRow,
} from "@/features/procurement/queries";

function priceSourceLabel(source: PoLineRow["price_source"]): string {
  switch (source) {
    case "agreement":
      return vi.procurement.priceSource.agreement;
    case "quote":
      return vi.procurement.priceSource.quote;
    case "ceiling":
      return vi.procurement.priceSource.ceiling;
    case "manual":
      return vi.procurement.priceSource.manual;
    default:
      return source;
  }
}

/**
 * Chi tiết đơn mua (T-021): dòng hàng kèm nguồn giá + giá trần + cảnh
 * báo vượt trần/giá tay, timeline duyệt, và các thao tác theo trạng
 * thái + quyền: sửa nháp, gửi duyệt, duyệt/từ chối theo bước, gửi cho
 * NCC, đóng phần còn thiếu, hủy. Vượt giá trần mà thiếu lý do thì nút
 * Gửi duyệt bị khóa (server vẫn chặn bằng `ERR_OVER_CEILING_NO_REASON`
 * — AC của T-021).
 */
export function PoDetail({
  propertyId,
  po,
  lines,
  steps,
}: {
  propertyId: string;
  po: PoRow;
  lines: PoLineRow[];
  steps: ApprovalStepRow[];
}) {
  const router = useRouter();
  const canPoCreate = useCan("po.create");
  const canPoClose = useCan("po.close");

  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Hủy / đóng PO (lý do bắt buộc)
  const [reasonDialog, setReasonDialog] = useState<"cancel" | "close" | null>(
    null,
  );
  const [reason, setReason] = useState("");

  const overCeilingLines = lines.filter((line) => line.over_ceiling);
  const manualLines = lines.filter((line) => line.price_source === "manual");
  const manualPriceMissing = manualLines.some((line) => !(line.unit_price > 0));
  const overCeilingBlocked =
    overCeilingLines.length > 0 &&
    (!po.over_ceiling_reason || !po.over_ceiling_reason.trim());
  const submitBlocked = overCeilingBlocked || manualPriceMissing;

  async function handleSubmit() {
    if (!confirm(vi.procurement.detail.confirmSubmit)) return;
    setBusy(true);
    setError(null);
    const res = await submitPoAction({ propertyId, poId: po.id });
    setBusy(false);
    if (res.ok) {
      setNotice(vi.procurement.form.submitSuccess);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleSend() {
    if (!confirm(vi.procurement.detail.confirmSend)) return;
    setBusy(true);
    setError(null);
    const res = await sendPoAction({ propertyId, poId: po.id });
    setBusy(false);
    if (res.ok) {
      setNotice(vi.procurement.form.sentSuccess);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleReasonSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!reasonDialog || !reason.trim()) {
      setError(vi.procurement.detail.reasonRequired);
      return;
    }
    setBusy(true);
    setError(null);
    const res =
      reasonDialog === "cancel"
        ? await cancelPoAction({
            propertyId,
            poId: po.id,
            reason: reason.trim(),
          })
        : await closePoAction({
            propertyId,
            poId: po.id,
            reason: reason.trim(),
          });
    setBusy(false);
    if (res.ok) {
      setReasonDialog(null);
      setReason("");
      setNotice(
        reasonDialog === "cancel"
          ? vi.procurement.form.cancelledSuccess
          : vi.procurement.form.closedSuccess,
      );
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  const isDraftLike = po.status === "draft" || po.status === "rejected";
  const canCancel =
    po.status === "draft" ||
    po.status === "submitted" ||
    po.status === "approved";
  const canClose = po.status === "sent" || po.status === "partially_received";

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
            href={`/${propertyId}/procurement/po`}
            className="text-sm text-primary hover:underline"
          >
            ← {vi.procurement.list.backToList}
          </Link>
          <div className="mt-2 flex items-center gap-3 flex-wrap">
            <h2 className="text-lg font-semibold font-mono">{po.doc_no}</h2>
            <DocStatusBadge status={po.status} />
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            {po.supplier_name ?? vi.procurement.po.marketSupplier} ·{" "}
            {po.channel === "contract"
              ? vi.procurement.po.channelContract
              : po.channel === "quote"
                ? vi.procurement.po.channelQuote
                : vi.procurement.po.channelMarket}
            {` · ${vi.procurement.po.orderDate}: ${new Date(po.order_date).toLocaleDateString("vi-VN")}`}
            {po.expected_date
              ? ` · ${vi.procurement.po.expectedDate}: ${new Date(po.expected_date).toLocaleDateString("vi-VN")}`
              : ""}
          </p>
          <p className="mt-1 text-sm">
            {vi.procurement.po.totalAmount}:{" "}
            <MoneyText amount={po.total_amount} className="font-semibold" />
          </p>
        </div>

        <div className="flex gap-2 flex-wrap">
          {isDraftLike && canPoCreate ? (
            <>
              <Button
                size="sm"
                variant="outline"
                onClick={() =>
                  router.push(`/${propertyId}/procurement/po/${po.id}/edit`)
                }
              >
                {vi.procurement.detail.editDraft}
              </Button>
              <Button
                size="sm"
                onClick={handleSubmit}
                disabled={busy || submitBlocked}
                title={
                  submitBlocked
                    ? vi.procurement.detail.overCeilingReasonMissing
                    : undefined
                }
              >
                {vi.procurement.po.submit}
              </Button>
            </>
          ) : null}
          {po.status === "approved" &&
          po.channel !== "market" &&
          canPoCreate ? (
            <Button size="sm" onClick={handleSend} disabled={busy}>
              {vi.procurement.po.send}
            </Button>
          ) : null}
          {canClose && canPoClose ? (
            <Button
              size="sm"
              variant="outline"
              onClick={() => {
                setReason("");
                setReasonDialog("close");
              }}
            >
              {vi.procurement.po.close}
            </Button>
          ) : null}
          {canCancel && canPoCreate ? (
            <Button
              size="sm"
              variant="outline"
              className="text-destructive hover:bg-destructive/10"
              onClick={() => {
                setReason("");
                setReasonDialog("cancel");
              }}
            >
              {vi.procurement.po.cancel}
            </Button>
          ) : null}
        </div>
      </div>

      {overCeilingLines.length > 0 ? (
        <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3 text-sm">
          <p className="font-medium">
            {vi.procurement.detail.overCeilingWarning}
          </p>
          {overCeilingBlocked ? (
            <p className="mt-1 text-amber-800">
              {vi.procurement.detail.overCeilingReasonMissing}
            </p>
          ) : (
            <p className="mt-1">
              {vi.procurement.detail.overCeilingReasonPresent}:{" "}
              {po.over_ceiling_reason}
            </p>
          )}
        </div>
      ) : null}
      {manualLines.length > 0 ? (
        <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3 text-sm">
          <p>{vi.procurement.detail.manualPriceWarning}</p>
          {manualPriceMissing ? (
            <p className="mt-1 font-medium text-amber-800">
              {vi.procurement.detail.priceNotSetWarning}
            </p>
          ) : null}
        </div>
      ) : null}

      <div className="rounded-xl border p-4">
        <h3 className="font-semibold text-sm mb-3">
          {vi.procurement.list.lines} ({lines.length})
        </h3>
        {lines.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.procurement.list.noLines}
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-xs text-muted-foreground">
                  <th className="py-2 pr-2">{vi.procurement.form.item}</th>
                  <th className="py-2 pr-2 text-right">
                    {vi.procurement.form.qty}
                  </th>
                  <th className="py-2 pr-2">{vi.procurement.form.uom}</th>
                  <th className="py-2 pr-2 text-right">
                    {vi.procurement.detail.unitPrice}
                  </th>
                  <th className="py-2 pr-2">
                    {vi.procurement.detail.priceSource}
                  </th>
                  <th className="py-2 pr-2 text-right">
                    {vi.procurement.detail.ceilingPrice}
                  </th>
                  <th className="py-2 pr-2 text-right">
                    {vi.procurement.detail.receivedQty}
                  </th>
                  <th className="py-2 pr-2 text-right">
                    {vi.procurement.detail.amount}
                  </th>
                </tr>
              </thead>
              <tbody>
                {lines.map((line) => (
                  <tr key={line.id} className="border-b last:border-0">
                    <td className="py-2 pr-2">
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
                      {line.over_ceiling ? (
                        <p className="mt-0.5 inline-flex rounded-full bg-red-100 px-2 py-0.5 text-[11px] font-medium text-red-800">
                          {vi.procurement.detail.overCeiling}
                        </p>
                      ) : null}
                      {line.price_source === "manual" ? (
                        <p className="mt-0.5 inline-flex rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-medium text-amber-800">
                          {vi.procurement.detail.manualPrice}
                        </p>
                      ) : null}
                    </td>
                    <td className="py-2 pr-2 text-right tabular-nums">
                      {formatNumber(line.qty)}
                    </td>
                    <td className="py-2 pr-2">{line.uom}</td>
                    <td className="py-2 pr-2 text-right tabular-nums">
                      <MoneyText amount={line.unit_price} />
                    </td>
                    <td className="py-2 pr-2">
                      {priceSourceLabel(line.price_source)}
                    </td>
                    <td className="py-2 pr-2 text-right tabular-nums">
                      {line.ceiling_price !== null ? (
                        <MoneyText amount={line.ceiling_price} />
                      ) : (
                        "—"
                      )}
                    </td>
                    <td className="py-2 pr-2 text-right tabular-nums">
                      {formatNumber(line.received_qty_stock)}
                    </td>
                    <td className="py-2 pr-2 text-right tabular-nums">
                      <MoneyText amount={line.qty * line.unit_price} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <ApprovalTimeline
        steps={steps}
        onDecide={async (decision, comment) =>
          decideApprovalAction({
            propertyId,
            docType: "po",
            docId: po.id,
            decision,
            comment,
          })
        }
      />

      {reasonDialog ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {reasonDialog === "cancel"
                  ? vi.procurement.po.cancel
                  : vi.procurement.po.close}
              </h3>
              <Button
                variant="ghost"
                size="sm"
                onClick={() => setReasonDialog(null)}
              >
                ✕
              </Button>
            </div>
            <form onSubmit={handleReasonSubmit} className="mt-4 space-y-3">
              <p className="text-sm text-muted-foreground">
                {reasonDialog === "cancel"
                  ? vi.procurement.detail.confirmCancel
                  : vi.procurement.detail.confirmClose}
              </p>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {reasonDialog === "cancel"
                    ? vi.procurement.detail.cancelReason
                    : vi.procurement.detail.closeReason}{" "}
                  *
                </label>
                <textarea
                  required
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder={vi.procurement.detail.reasonPlaceholder}
                  className="mt-1 min-h-20 w-full rounded-md border bg-background px-3 py-2 text-sm"
                />
              </div>
              <div className="flex justify-end gap-2 border-t pt-4">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setReasonDialog(null)}
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
    </div>
  );
}
