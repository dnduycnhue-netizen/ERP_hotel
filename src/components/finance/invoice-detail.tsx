"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { PageHeader } from "@/components/shell/page-header";
import {
  approveInvoiceAction,
  matchInvoiceAction,
} from "@/features/finance/actions";
import type { InvoiceDetail } from "@/features/finance/queries";
import { vi } from "@/i18n/vi";

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
  const [errorCode, setErrorCode] = useState<string | null>(null);

  const { invoice, lines } = detail;
  const canMatch =
    canManageInvoice &&
    (invoice.status === "draft" || invoice.status === "on_hold");
  const canApprove = canApproveInvoice && invoice.status === "matched";

  async function handleMatch() {
    setPending("match");
    setMessage(null);
    setError(null);
    setErrorCode(null);
    const res = await matchInvoiceAction({
      propertyId,
      invoiceId: invoice.id,
    });
    setPending(null);
    if (!res.ok) {
      setError(res.error);
      setErrorCode(res.code ?? null);
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
    setErrorCode(null);
    const res = await approveInvoiceAction({
      propertyId,
      invoiceId: invoice.id,
    });
    setPending(null);
    if (!res.ok) {
      setError(res.error);
      setErrorCode(res.code ?? null);
      return;
    }
    setMessage(vi.finance.invoiceApproved);
    router.refresh();
  }

  return (
    <div className="space-y-6">
      <div className="rounded-lg border bg-card p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <PageHeader
            title={`${invoice.invoice_symbol} ${invoice.invoice_no}`}
            description={
              <>
                {invoice.supplier_name ?? vi.common.noData} ·{" "}
                {vi.finance.invoiceDate}: {invoice.invoice_date} ·{" "}
                <DocStatusBadge status={invoice.status} />
              </>
            }
          >
            {invoice.lookup_code ? (
              <p className="text-sm text-muted-foreground">
                {vi.finance.lookupCode}: {invoice.lookup_code}
              </p>
            ) : null}
          </PageHeader>
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
        {errorCode === "ERR_SERVICE_NOT_ACCEPTED" ? (
          <p className="mt-3 rounded-md bg-amber-50 p-3 text-sm text-amber-800">
            <span className="font-medium">{vi.service.blockedTitle}. </span>
            {vi.service.blockedHint}{" "}
            <Link
              href={`/${propertyId}/procurement/service-contracts/schedules`}
              className="font-medium underline"
            >
              {vi.service.goToSchedules}
            </Link>
          </p>
        ) : null}
      </div>

      <div className="rounded-lg border bg-card p-4">
        <h2 className="font-medium">{vi.finance.matchResultTitle}</h2>
        {lines.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.components.table.emptyDescription}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.itemDesc}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.invoiceQty}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.unitPrice}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.vatRate}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.lineAmount}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.matchResultTitle}
                  </th>
                </tr>
              </thead>
              <tbody>
                {lines.map((l) => {
                  const m = l.match_result;
                  return (
                    <tr key={l.id} className="border-t hover:bg-muted/40">
                      <td className="px-3 py-3 align-middle">
                        {l.item_name ?? l.item_code ?? vi.common.noData}
                      </td>
                      <td className="px-3 py-3 text-right align-middle">
                        {formatNumber(l.qty)}
                      </td>
                      <td className="px-3 py-3 text-right align-middle">
                        <MoneyText amount={l.unit_price} />
                      </td>
                      <td className="px-3 py-3 text-right align-middle">
                        {formatNumber(l.vat_rate)}%
                      </td>
                      <td className="px-3 py-3 text-right align-middle">
                        <MoneyText amount={l.amount} />
                      </td>
                      <td className="px-3 py-3 text-xs align-middle">
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
