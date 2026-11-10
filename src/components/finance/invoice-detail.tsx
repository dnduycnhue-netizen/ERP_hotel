"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import {
  approveInvoiceAction,
  matchInvoiceAction,
} from "@/features/finance/actions";
import type { InvoiceDetail } from "@/features/finance/queries";
import { vi } from "@/i18n/vi";

const STATUS_LABELS: Record<string, string> = {
  draft: vi.components.docStatus.draft,
  matched: vi.components.docStatus.matched,
  on_hold: vi.components.docStatus.onHold,
  approved: vi.components.docStatus.approved,
  partially_paid: vi.components.docStatus.partiallyPaid,
  paid: vi.components.docStatus.paid,
  cancelled: vi.components.docStatus.cancelled,
};

/**
 * Chi tiết hóa đơn (T-041): dòng hóa đơn + kết quả khớp 3 chiều từng
 * dòng + nút Khớp / Duyệt. Nút Duyệt chỉ hiện khi hóa đơn `matched`;
 * SoD (người tạo không tự duyệt) do RPC kiểm tra — UI nhắc trước bằng
 * ghi chú.
 */
export function InvoiceDetailView({
  propertyId,
  detail,
  canManageInvoice,
  canApproveInvoice,
  isCreator,
}: {
  propertyId: string;
  detail: InvoiceDetail;
  canManageInvoice: boolean;
  canApproveInvoice: boolean;
  isCreator: boolean;
}) {
  const router = useRouter();
  const [pending, setPending] = useState<"match" | "approve" | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const { invoice, lines } = detail;
  const canMatch =
    canManageInvoice &&
    (invoice.status === "draft" || invoice.status === "on_hold");
  const canApprove = canApproveInvoice && invoice.status === "matched";

  async function handleMatch() {
    setPending("match");
    setMessage(null);
    setError(null);
    const res = await matchInvoiceAction({
      propertyId,
      invoiceId: invoice.id,
    });
    setPending(null);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(
      res.data.status === "matched"
        ? vi.finance.matchedMessage
        : vi.finance.onHoldMessage,
    );
    router.refresh();
  }

  async function handleApprove() {
    setPending("approve");
    setMessage(null);
    setError(null);
    const res = await approveInvoiceAction({
      propertyId,
      invoiceId: invoice.id,
    });
    setPending(null);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(vi.finance.invoiceApproved);
    router.refresh();
  }

  return (
    <div className="space-y-6">
      <div className="rounded-xl border bg-card p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-xl font-semibold">
              {invoice.invoice_symbol} {invoice.invoice_no}
            </h1>
            <p className="mt-1 text-sm text-muted-foreground">
              {invoice.supplier_name ?? vi.common.noData} ·{" "}
              {vi.finance.invoiceDate}: {invoice.invoice_date} ·{" "}
              {STATUS_LABELS[invoice.status] ?? invoice.status}
            </p>
            {invoice.lookup_code ? (
              <p className="mt-1 text-sm text-muted-foreground">
                {vi.finance.lookupCode}: {invoice.lookup_code}
              </p>
            ) : null}
          </div>
          <div className="text-right text-sm">
            <p>
              {vi.finance.totalBeforeTax}:{" "}
              <MoneyText amount={invoice.amount_before_tax} />
            </p>
            <p>
              {vi.finance.vatAmount}: <MoneyText amount={invoice.vat_amount} />
            </p>
            <p className="font-semibold">
              {vi.finance.totalAmount}: <MoneyText amount={invoice.total} />
            </p>
          </div>
        </div>
        {invoice.status === "on_hold" ? (
          <p className="mt-3 rounded-md bg-red-50 p-3 text-sm text-red-800">
            {vi.finance.onHoldMessage}
          </p>
        ) : null}
        <div className="mt-4 flex flex-wrap gap-2">
          {canMatch ? (
            <Button
              type="button"
              disabled={pending !== null}
              onClick={handleMatch}
            >
              {pending === "match"
                ? vi.finance.matching
                : vi.finance.matchButton}
            </Button>
          ) : null}
          {canApprove ? (
            <Button
              type="button"
              variant="default"
              disabled={pending !== null}
              onClick={handleApprove}
            >
              {pending === "approve"
                ? vi.finance.approving
                : vi.finance.approveButton}
            </Button>
          ) : null}
        </div>
        {isCreator && invoice.status === "matched" ? (
          <p className="mt-3 text-sm text-muted-foreground">
            {vi.finance.sodApproveWarning}
          </p>
        ) : null}
        {message ? (
          <p className="mt-3 text-sm font-medium text-green-800">{message}</p>
        ) : null}
        {error ? (
          <p className="mt-3 text-sm font-medium text-red-800">{error}</p>
        ) : null}
      </div>

      <div className="rounded-xl border bg-card p-4">
        <h2 className="font-medium">{vi.finance.matchResultTitle}</h2>
        {lines.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.components.table.emptyDescription}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-3 py-2">{vi.finance.itemDesc}</th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.invoiceQty}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.unitPrice}
                  </th>
                  <th className="px-3 py-2 text-right">{vi.finance.vatRate}</th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.lineAmount}
                  </th>
                  <th className="px-3 py-2">{vi.finance.matchResultTitle}</th>
                </tr>
              </thead>
              <tbody>
                {lines.map((l) => {
                  const m = l.match_result;
                  return (
                    <tr key={l.id} className="border-b last:border-0">
                      <td className="px-3 py-2">
                        {l.item_name ?? l.item_code ?? vi.common.noData}
                      </td>
                      <td className="px-3 py-2 text-right">
                        {formatNumber(l.qty)}
                      </td>
                      <td className="px-3 py-2 text-right">
                        <MoneyText amount={l.unit_price} />
                      </td>
                      <td className="px-3 py-2 text-right">
                        {formatNumber(l.vat_rate)}%
                      </td>
                      <td className="px-3 py-2 text-right">
                        <MoneyText amount={l.amount} />
                      </td>
                      <td className="px-3 py-2 text-xs">
                        {!m ? (
                          <span className="text-muted-foreground">
                            {vi.finance.matchNotRun}
                          </span>
                        ) : (
                          <div className="space-y-0.5">
                            <p
                              className={
                                m.qty_ok ? "text-green-800" : "text-red-800"
                              }
                            >
                              {m.qty_ok
                                ? vi.finance.matchQtyOk
                                : vi.finance.matchQtyOver}
                              {" · "}
                              {vi.finance.matchReceivedQty}:{" "}
                              {formatNumber(m.received_qty)} /{" "}
                              {vi.finance.matchAvailableQty}:{" "}
                              {formatNumber(m.available_qty)}
                            </p>
                            <p
                              className={
                                m.price_ok ? "text-green-800" : "text-red-800"
                              }
                            >
                              {m.price_ok
                                ? vi.finance.matchPriceOk
                                : vi.finance.matchPriceOver}
                              {" · "}
                              {vi.finance.matchPoPrice}:{" "}
                              <MoneyText amount={m.po_unit_price} />
                              {" → "}
                              {vi.finance.matchInvoicePrice}:{" "}
                              <MoneyText amount={m.invoice_unit_price} />
                              {m.price_diff_pct !== null &&
                              m.price_diff_pct !== undefined
                                ? ` (${vi.finance.matchDiffPct}: ${formatNumber(m.price_diff_pct)}%, ${vi.finance.matchTolerance}: ${formatNumber(m.tolerance_pct)}%)`
                                : ""}
                            </p>
                          </div>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
