"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { CheckCircle2, XCircle } from "lucide-react";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { DataTable } from "@/components/common/data-table";
import { Button } from "@/components/ui/button";
import {
  closePeriodAction,
  reopenPeriodAction,
} from "@/features/locks/actions";
import type {
  AccountingPeriodRow,
  PeriodCloseCheck,
} from "@/features/locks/queries";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

function formatClosedAt(value: string | null): string {
  if (!value) {
    return vi.common.noData;
  }
  return new Intl.DateTimeFormat("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

/**
 * Khóa kỳ kế toán (C1, 05 §10): checklist 3 điều kiện tiên quyết của
 * `period_close` (đọc từ RPC `period_close_check`), nút khóa kỳ khi
 * đủ điều kiện, mở lại kỳ kèm lý do, lịch sử các kỳ.
 */
export function LocksPeriodPanel({
  propertyId,
  entityId,
  year,
  month,
  check,
  periods,
  canClose,
  canReopen,
}: {
  propertyId: string;
  entityId: string;
  year: number;
  month: number;
  check: PeriodCloseCheck;
  periods: AccountingPeriodRow[];
  canClose: boolean;
  canReopen: boolean;
}) {
  const router = useRouter();
  const [showReopen, setShowReopen] = useState(false);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const currentPeriod = periods.find(
    (p) => p.year === year && p.month === month,
  );
  const isClosed = check.already_closed;
  const blocked =
    check.count_blocked || check.po_blocked || check.advance_blocked;

  const conditions: {
    key: string;
    label: string;
    met: boolean;
    detail: string;
  }[] = [
    {
      key: "count",
      label: vi.locks.conditionCount,
      met: !check.count_blocked,
      detail: check.count_blocked
        ? `${vi.locks.conditionCountBlocked} ${check.missing_counts
            .map((w) => w.warehouse_name)
            .join(", ")}`
        : vi.locks.conditionCountOk,
    },
    {
      key: "po",
      label: vi.locks.conditionPo,
      met: !check.po_blocked,
      detail: check.po_blocked
        ? `${check.po_count} ${vi.locks.conditionPoBlocked}`
        : vi.locks.conditionPoOk,
    },
    {
      key: "advance",
      label: vi.locks.conditionAdvance,
      met: !check.advance_blocked,
      detail: check.advance_blocked
        ? `${check.advance_count} ${vi.locks.conditionAdvanceBlocked}`
        : vi.locks.conditionAdvanceOk,
    },
  ];

  async function handleClose(): Promise<void> {
    if (busy) {
      return;
    }
    setBusy(true);
    setError(null);
    const res = await closePeriodAction({
      propertyId,
      entityId,
      year,
      month,
    });
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.refresh();
  }

  async function handleReopen(): Promise<void> {
    if (busy || !currentPeriod) {
      return;
    }
    if (reason.trim() === "") {
      setError(vi.locks.reopenReasonLabel);
      return;
    }
    setBusy(true);
    setError(null);
    const res = await reopenPeriodAction({
      propertyId,
      periodId: currentPeriod.id,
      reason: reason.trim(),
    });
    setBusy(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setShowReopen(false);
    setReason("");
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="rounded-lg border bg-card p-4">
        <p className="text-sm text-muted-foreground">{vi.locks.periodHint}</p>

        <ul className="mt-3 flex flex-col gap-2">
          {conditions.map((condition) => (
            <li key={condition.key} className="flex items-start gap-2 text-sm">
              {condition.met ? (
                <CheckCircle2
                  className="mt-0.5 size-4 shrink-0 text-green-600"
                  aria-hidden
                />
              ) : (
                <XCircle
                  className="mt-0.5 size-4 shrink-0 text-destructive"
                  aria-hidden
                />
              )}
              <span>
                <span className="font-medium">{condition.label}</span>{" "}
                <span
                  className={cn(
                    "rounded-full px-2 py-0.5 text-[11px] font-semibold",
                    condition.met
                      ? "bg-green-100 text-green-800 dark:bg-green-900/40 dark:text-green-200"
                      : "bg-red-100 text-red-800 dark:bg-red-900/40 dark:text-red-200",
                  )}
                >
                  {condition.met
                    ? vi.locks.conditionMet
                    : vi.locks.conditionBlocked}
                </span>
                <span className="block text-muted-foreground">
                  {condition.detail}
                </span>
              </span>
            </li>
          ))}
        </ul>

        {error ? (
          <p role="alert" className="mt-3 text-sm text-destructive">
            {error}
          </p>
        ) : null}

        <div className="mt-4 flex flex-wrap items-center gap-2">
          {isClosed ? (
            <>
              <DocStatusBadge status="closed" />
              <span className="text-sm text-muted-foreground">
                {vi.locks.alreadyClosedNote}
              </span>
              {canReopen && currentPeriod && !showReopen ? (
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => setShowReopen(true)}
                >
                  {vi.locks.reopenPeriod}
                </Button>
              ) : null}
              {!canReopen ? (
                <span className="text-sm text-muted-foreground">
                  {vi.locks.needsClosePermission}
                </span>
              ) : null}
            </>
          ) : (
            <>
              <DocStatusBadge status="open" />
              {canClose ? (
                <Button
                  size="sm"
                  disabled={busy || blocked}
                  onClick={() => void handleClose()}
                >
                  {busy ? vi.locks.closing : vi.locks.closePeriod}
                </Button>
              ) : (
                <span className="text-sm text-muted-foreground">
                  {vi.locks.needsClosePermission}
                </span>
              )}
            </>
          )}
        </div>

        {showReopen && isClosed ? (
          <div className="mt-4 rounded-lg border p-4">
            <p className="text-sm font-semibold">{vi.locks.reopenConfirm}</p>
            <label className="mt-3 flex flex-col gap-1.5 text-sm font-medium">
              {vi.locks.reopenReasonLabel} *
              <input
                type="text"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder={vi.locks.reopenReasonPlaceholder}
                maxLength={500}
                className="h-9 rounded-md border bg-background px-3 text-sm font-normal outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
              />
            </label>
            <div className="mt-3 flex gap-2">
              <Button
                size="sm"
                disabled={busy}
                onClick={() => void handleReopen()}
              >
                {busy ? vi.locks.reopening : vi.locks.confirm}
              </Button>
              <Button
                size="sm"
                variant="outline"
                disabled={busy}
                onClick={() => {
                  setShowReopen(false);
                  setReason("");
                  setError(null);
                }}
              >
                {vi.locks.cancel}
              </Button>
            </div>
          </div>
        ) : null}
      </div>

      <div className="flex flex-col gap-2">
        <h2 className="text-base font-semibold">{vi.locks.periodHistory}</h2>
        <DataTable
          columns={[
            {
              key: "label",
              header: vi.locks.monthLabel,
              cell: (row) => row.label,
            },
            {
              key: "status",
              header: vi.locks.status,
              cell: (row) => <DocStatusBadge status={row.status} />,
            },
            {
              key: "closedAt",
              header: vi.locks.closedAt,
              cell: (row) => formatClosedAt(row.closedAt),
            },
          ]}
          rows={periods.map((p) => ({
            id: p.id,
            label: `${String(p.month).padStart(2, "0")}/${p.year}`,
            status: p.status,
            closedAt: p.closed_at,
          }))}
          emptyTitle={vi.locks.noPeriodYet}
        />
      </div>
    </div>
  );
}
