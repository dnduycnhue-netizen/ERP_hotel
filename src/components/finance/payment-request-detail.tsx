"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import {
  decidePaymentRequestAction,
  markPaymentPaidAction,
} from "@/features/finance/actions";
import type { PaymentRequestDetail } from "@/features/finance/queries";
import { vi } from "@/i18n/vi";

const STATUS_LABELS: Record<string, string> = {
  draft: vi.components.docStatus.draft,
  matched: vi.components.docStatus.matched,
  on_hold: vi.components.docStatus.onHold,
  submitted: vi.components.docStatus.submitted,
  approved: vi.components.docStatus.approved,
  partially_paid: vi.components.docStatus.partiallyPaid,
  paid: vi.components.docStatus.paid,
  cancelled: vi.components.docStatus.cancelled,
};

/**
 * Chi tiết đề nghị thanh toán (T-041): dòng hóa đơn + tiến trình duyệt
 * theo trạng thái + nút Duyệt/Từ chối + ghi nhận đã trả.
 *
 * LƯU Ý (Q73): bước duyệt chi tiết (ai duyệt bước nào, có bước owner
 * không) KHÔNG đọc được từ client — policy `approvals_select` và RPC
 * `approval_timeline` chỉ hỗ trợ chứng từ PR/PO. Màn này chỉ hiện tiến
 * trình theo trạng thái đề nghị + ghi chú; nút Duyệt/Từ chối chỉ hiện
 * với người có `payment.approve`, RPC kiểm tra lại người duyệt được
 * giao ở bước đang chờ (`ERR_NOT_APPROVER` nếu không phải).
 */
export function PaymentRequestDetailView({
  propertyId,
  detail,
  canApprovePayment,
  canMarkPaid,
  bankChangedRecently,
}: {
  propertyId: string;
  detail: PaymentRequestDetail;
  canApprovePayment: boolean;
  canMarkPaid: boolean;
  bankChangedRecently: boolean;
}) {
  const router = useRouter();
  const [decision, setDecision] = useState<"approved" | "rejected" | null>(
    null,
  );
  const [comment, setComment] = useState("");
  const [bankRef, setBankRef] = useState("");
  const [pending, setPending] = useState<"decide" | "paid" | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const { request, lines } = detail;
  const canDecide = canApprovePayment && request.status === "submitted";
  const canPay = canMarkPaid && request.status === "approved";

  const steps: Array<{ label: string; done: boolean; current: boolean }> = [
    {
      label: vi.finance.timelineCreated,
      done: true,
      current: false,
    },
    {
      label: vi.finance.timelineWaiting,
      done:
        request.status === "approved" ||
        request.status === "paid" ||
        request.status === "cancelled",
      current: request.status === "submitted",
    },
    {
      label:
        request.status === "cancelled"
          ? vi.finance.timelineRejected
          : vi.finance.timelineApproved,
      done: request.status === "approved" || request.status === "paid",
      current: false,
    },
    {
      label: vi.finance.timelinePaid,
      done: request.status === "paid",
      current: request.status === "approved",
    },
  ];

  async function handleDecide() {
    if (!decision) return;
    setPending("decide");
    setMessage(null);
    setError(null);
    const res = await decidePaymentRequestAction({
      propertyId,
      requestId: request.id,
      decision,
      comment: comment.trim() || null,
    });
    setPending(null);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(vi.finance.decidedMessage);
    setDecision(null);
    setComment("");
    router.refresh();
  }

  async function handleMarkPaid() {
    setPending("paid");
    setMessage(null);
    setError(null);
    const res = await markPaymentPaidAction({
      propertyId,
      requestId: request.id,
      bankRef: bankRef.trim(),
    });
    setPending(null);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(vi.finance.paidMessage);
    router.refresh();
  }

  return (
    <div className="space-y-6">
      <div className="rounded-xl border bg-card p-4">
        <div className="flex flex-wrap items-start justify-between gap-3">
          <div>
            <h1 className="text-xl font-semibold">{request.doc_no}</h1>
            <p className="mt-1 text-sm text-muted-foreground">
              {request.supplier_name ?? vi.common.noData} ·{" "}
              {STATUS_LABELS[request.status] ?? request.status}
            </p>
            {bankChangedRecently && request.status === "submitted" ? (
              <p className="mt-2 rounded-md bg-amber-50 p-3 text-sm text-amber-900">
                {vi.finance.bankChangedNote}
              </p>
            ) : null}
          </div>
          <div className="text-right text-sm">
            <p className="font-semibold">
              {vi.finance.totalAmount}: <MoneyText amount={request.total} />
            </p>
            <p>
              {vi.finance.dueDate}: {request.due_date ?? vi.common.noData}
            </p>
            {request.paid_at ? (
              <p>
                {vi.finance.paidAt}: {request.paid_at}
              </p>
            ) : null}
            {request.bank_ref ? (
              <p>
                {vi.finance.bankRef}: {request.bank_ref}
              </p>
            ) : null}
          </div>
        </div>

        <div className="mt-4">
          <h2 className="font-medium">{vi.finance.timelineTitle}</h2>
          <ol className="mt-2 space-y-1 text-sm">
            {steps.map((s, i) => (
              <li
                key={i}
                className={
                  s.done
                    ? "text-green-800"
                    : s.current
                      ? "font-medium text-amber-800"
                      : "text-muted-foreground"
                }
              >
                {s.done ? "✓ " : s.current ? "• " : "○ "}
                {s.label}
              </li>
            ))}
          </ol>
          <p className="mt-2 text-xs text-muted-foreground">
            {vi.finance.timelineStepsNote}
          </p>
        </div>

        {canDecide ? (
          <div className="mt-4 space-y-2">
            <div className="flex gap-2">
              <Button
                type="button"
                variant={decision === "approved" ? "default" : "outline"}
                onClick={() => setDecision("approved")}
              >
                {vi.finance.approveRequestButton}
              </Button>
              <Button
                type="button"
                variant={decision === "rejected" ? "destructive" : "outline"}
                onClick={() => setDecision("rejected")}
              >
                {vi.finance.rejectRequestButton}
              </Button>
            </div>
            {decision ? (
              <div className="space-y-2">
                <label className="block text-sm">
                  {decision === "rejected"
                    ? vi.finance.rejectReason
                    : vi.common.note}
                  <input
                    value={comment}
                    onChange={(e) => setComment(e.target.value)}
                    className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                  />
                </label>
                <Button
                  type="button"
                  disabled={
                    pending !== null ||
                    (decision === "rejected" && comment.trim() === "")
                  }
                  onClick={handleDecide}
                >
                  {pending === "decide" ? vi.common.loading : vi.common.confirm}
                </Button>
              </div>
            ) : null}
          </div>
        ) : null}

        {canPay ? (
          <div className="mt-4 space-y-2">
            <label className="block max-w-sm text-sm">
              {vi.finance.bankRef}
              <input
                value={bankRef}
                onChange={(e) => setBankRef(e.target.value)}
                className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
                placeholder="VD: FT260110123456"
              />
            </label>
            <Button
              type="button"
              disabled={pending !== null || bankRef.trim() === ""}
              onClick={handleMarkPaid}
            >
              {pending === "paid"
                ? vi.finance.markingPaid
                : vi.finance.markPaidButton}
            </Button>
          </div>
        ) : null}

        {message ? (
          <p className="mt-3 text-sm font-medium text-green-800">{message}</p>
        ) : null}
        {error ? (
          <p className="mt-3 text-sm font-medium text-red-800">{error}</p>
        ) : null}
      </div>

      <div className="rounded-xl border bg-card p-4">
        <h2 className="font-medium">{vi.finance.selectInvoices}</h2>
        {lines.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.components.table.emptyDescription}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-3 py-2">{vi.finance.invoiceSymbol}</th>
                  <th className="px-3 py-2">{vi.finance.invoiceNo}</th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.totalAmount}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.requestAmount}
                  </th>
                  <th className="px-3 py-2">{vi.common.status}</th>
                </tr>
              </thead>
              <tbody>
                {lines.map((l) => (
                  <tr key={l.id} className="border-b last:border-0">
                    <td className="px-3 py-2">
                      {l.invoice_symbol ?? vi.common.noData}
                    </td>
                    <td className="px-3 py-2">
                      {l.invoice_no ?? vi.common.noData}
                    </td>
                    <td className="px-3 py-2 text-right">
                      <MoneyText amount={l.invoice_total} />
                    </td>
                    <td className="px-3 py-2 text-right">
                      <MoneyText amount={l.amount} />
                    </td>
                    <td className="px-3 py-2">
                      {l.invoice_status
                        ? (STATUS_LABELS[l.invoice_status] ?? l.invoice_status)
                        : vi.common.noData}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
