"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { MoneyText } from "@/components/common/money-text";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import {
  decideAdvanceAction,
  disburseAdvanceAction,
} from "@/features/procurement/actions";
import type { AdvanceDetail } from "@/features/procurement/queries";

function formatDateTime(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("vi-VN");
}

/**
 * Chi tiết tạm ứng (T-022): thông tin đề nghị/duyệt/chi + hạn quyết
 * toán + PO liên kết. Duyệt/từ chối (gm, `advance.approve`) khi
 * `requested`; chi tiền (kế toán, `advance.disburse`) khi `approved`.
 * Quyết toán thuộc T-040 — màn này chưa có nút quyết toán.
 */
export function AdvanceDetail({
  propertyId,
  detail,
}: {
  propertyId: string;
  detail: AdvanceDetail;
}) {
  const router = useRouter();
  const canApprove = useCan("advance.approve");
  const canDisburse = useCan("advance.disburse");

  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Từ chối / chi tiền (lý do bắt buộc khi từ chối)
  const [reasonDialog, setReasonDialog] = useState<
    "reject" | "disburse" | null
  >(null);
  const [reason, setReason] = useState("");

  const { advance, po } = detail;
  // Moc thoi gian lay 1 lan khi mount (tranh goi Date.now() trong render).
  const [now] = useState(() => Date.now());
  const isOverdue =
    advance.status === "overdue" ||
    ((advance.status === "disbursed" || advance.status === "settling") &&
      advance.due_settle_at !== null &&
      new Date(advance.due_settle_at).getTime() < now);

  async function handleDecide(approved: boolean, reasonText: string | null) {
    setBusy(true);
    setError(null);
    const res = await decideAdvanceAction({
      propertyId,
      advanceId: advance.id,
      approved,
      reason: reasonText,
    });
    setBusy(false);
    if (res.ok) {
      setReasonDialog(null);
      setReason("");
      setNotice(
        approved
          ? vi.procurement.advances.decideSuccess
          : vi.procurement.advances.rejectSuccess,
      );
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDisburse(note: string | null) {
    setBusy(true);
    setError(null);
    const res = await disburseAdvanceAction({
      propertyId,
      advanceId: advance.id,
      note,
    });
    setBusy(false);
    if (res.ok) {
      setReasonDialog(null);
      setReason("");
      setNotice(vi.procurement.advances.disburseSuccess);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  async function handleReasonSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!reasonDialog) return;
    if (reasonDialog === "reject" && !reason.trim()) {
      setError(vi.procurement.advances.reasonRequiredForReject);
      return;
    }
    if (reasonDialog === "reject") {
      await handleDecide(false, reason.trim());
    } else {
      await handleDisburse(reason.trim() ? reason.trim() : null);
    }
  }

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
            href={`/${propertyId}/procurement/advances`}
            className="text-sm text-primary hover:underline"
          >
            ← {vi.procurement.list.backToList}
          </Link>
          <div className="mt-2 flex items-center gap-3 flex-wrap">
            <h2 className="text-lg font-semibold font-mono">
              {advance.doc_no}
            </h2>
            <DocStatusBadge status={advance.status} />
          </div>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.procurement.advances.employee}: {advance.employee_name ?? "—"} ·{" "}
            {vi.procurement.advances.requestedAt}:{" "}
            {formatDateTime(advance.requested_at)}
          </p>
          <p className="mt-1 text-sm">
            {vi.procurement.advances.amount}:{" "}
            <MoneyText amount={advance.amount} className="font-semibold" />
          </p>
        </div>

        <div className="flex gap-2 flex-wrap">
          {advance.status === "requested" && canApprove ? (
            <>
              <Button
                size="sm"
                onClick={() => {
                  if (!confirm(vi.procurement.advances.confirmApprove)) return;
                  handleDecide(true, null);
                }}
                disabled={busy}
              >
                {vi.procurement.advances.approve}
              </Button>
              <Button
                size="sm"
                variant="outline"
                className="text-destructive hover:bg-destructive/10"
                onClick={() => {
                  setReason("");
                  setReasonDialog("reject");
                }}
              >
                {vi.procurement.advances.reject}
              </Button>
            </>
          ) : null}
          {advance.status === "approved" && canDisburse ? (
            <Button
              size="sm"
              onClick={() => {
                setReason("");
                setReasonDialog("disburse");
              }}
              disabled={busy}
            >
              {vi.procurement.advances.disburse}
            </Button>
          ) : null}
        </div>
      </div>

      {isOverdue ? (
        <div className="rounded-md border border-red-500/30 bg-red-500/10 p-3 text-sm">
          <p className="font-medium text-red-800">
            {vi.procurement.advances.overdueWarning}
          </p>
        </div>
      ) : null}

      <div className="rounded-lg border p-4">
        <h3 className="font-semibold text-sm mb-3">
          {vi.procurement.detail.info}
        </h3>
        <dl className="grid grid-cols-1 gap-x-6 gap-y-2 text-sm sm:grid-cols-2">
          <div className="flex justify-between gap-4">
            <dt className="text-muted-foreground">
              {vi.procurement.advances.purpose}
            </dt>
            <dd className="text-right font-medium">{advance.purpose}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-muted-foreground">
              {vi.procurement.advances.linkedPo}
            </dt>
            <dd className="text-right">
              {po ? (
                <Link
                  href={`/${propertyId}/procurement/po/${po.id}`}
                  className="font-mono text-xs font-bold text-primary hover:underline"
                >
                  {po.doc_no} ({po.status})
                </Link>
              ) : (
                vi.procurement.advances.noLinkedPo
              )}
            </dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-muted-foreground">
              {vi.procurement.advances.decidedAt}
            </dt>
            <dd className="text-right">{formatDateTime(advance.decided_at)}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-muted-foreground">
              {vi.procurement.advances.decideReason}
            </dt>
            <dd className="text-right">{advance.decide_reason ?? "—"}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-muted-foreground">
              {vi.procurement.advances.disbursedAt}
            </dt>
            <dd className="text-right">
              {formatDateTime(advance.disbursed_at)}
            </dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-muted-foreground">
              {vi.procurement.advances.disbursedNote}
            </dt>
            <dd className="text-right">{advance.disbursed_note ?? "—"}</dd>
          </div>
          <div className="flex justify-between gap-4">
            <dt className="text-muted-foreground">
              {vi.procurement.advances.dueSettleAt}
            </dt>
            <dd className="text-right font-medium">
              {formatDateTime(advance.due_settle_at)}
            </dd>
          </div>
        </dl>
      </div>

      {reasonDialog ? (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="w-full max-w-md rounded-xl border bg-background p-6 shadow-lg">
            <div className="flex items-center justify-between border-b pb-3">
              <h3 className="font-semibold">
                {reasonDialog === "reject"
                  ? vi.procurement.advances.reject
                  : vi.procurement.advances.disburse}
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
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {reasonDialog === "reject"
                    ? vi.procurement.advances.decideReason
                    : vi.procurement.advances.disburseNote}{" "}
                  {reasonDialog === "reject" ? "*" : ""}
                </label>
                <textarea
                  required={reasonDialog === "reject"}
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
