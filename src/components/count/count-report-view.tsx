"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { ConfirmPostDialog } from "@/components/common/confirm-post-dialog";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { MoneyText } from "@/components/common/money-text";
import {
  adjustCountAction,
  cancelCountAction,
  lockCountAction,
} from "@/features/count/actions";
import type {
  CountAdjustmentRow,
  CountCounter,
  CountKind,
  CountResultRow,
  CountRow,
} from "@/features/count/queries";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";
import { CountExportButton } from "./count-export-button";
import { formatQty, formatYmd, interpolate } from "./count-utils";

type ReasonCode =
  | "lost"
  | "damaged"
  | "expired"
  | "theft"
  | "miscount"
  | "supplier_short"
  | "other";

function kindLabel(kind: CountKind): string {
  switch (kind) {
    case "monthly_full":
      return vi.count.kindMonthlyFull;
    case "cycle":
      return vi.count.kindCycle;
    case "shift_key":
      return vi.count.kindShiftKey;
    case "trolley":
      return vi.count.kindTrolley;
    case "minibar_audit":
      return vi.count.kindMinibarAudit;
  }
}

function flagLabel(flag: CountResultRow["flag"]): string {
  if (flag === "ok") return vi.count.flags.ok;
  if (flag === "recount") return vi.count.flags.recount;
  if (flag === "red") return vi.count.flags.red;
  return vi.common.noData;
}

function reasonLabel(code: string | null): string {
  switch (code) {
    case "lost":
      return vi.count.reasonCodes.lost;
    case "damaged":
      return vi.count.reasonCodes.damaged;
    case "expired":
      return vi.count.reasonCodes.expired;
    case "theft":
      return vi.count.reasonCodes.theft;
    case "miscount":
      return vi.count.reasonCodes.miscount;
    case "supplier_short":
      return vi.count.reasonCodes.supplierShort;
    case "other":
      return vi.count.reasonCodes.other;
    default:
      return vi.common.noData;
  }
}

const REASON_CODES: ReasonCode[] = [
  "lost",
  "damaged",
  "expired",
  "theft",
  "miscount",
  "supplier_short",
  "other",
];

/**
 * Biên bản chênh lệch desktop (T-033): bảng v_count_result (chỉ người có
 * `count.view_variance` và không phải người đếm mới đọc được — view chặn ở
 * tầng dữ liệu), form khóa đợt (lý do dòng đỏ), ghi điều chỉnh, hủy đợt,
 * xuất Excel.
 */
export function CountReportView({
  count,
  result,
  adjustment,
  counters,
  canLock,
  canAdjustApprove,
  canOpen,
  canViewVariance,
  canViewValue,
  propertyId,
}: {
  count: CountRow;
  result: CountResultRow[];
  adjustment: CountAdjustmentRow | null;
  counters: CountCounter[];
  canLock: boolean;
  canAdjustApprove: boolean;
  canOpen: boolean;
  canViewVariance: boolean;
  canViewValue: boolean;
  propertyId: string;
}) {
  const router = useRouter();
  const counterNames = new Map(counters.map((c) => [c.id, c.full_name]));
  const redLines = useMemo(
    () => result.filter((row) => row.flag === "red"),
    [result],
  );
  const [reasons, setReasons] = useState<
    Record<string, { reasonCode: string; explanation: string }>
  >({});
  const [locking, setLocking] = useState(false);
  const [lockError, setLockError] = useState<string | null>(null);
  const [adjustOpen, setAdjustOpen] = useState(false);
  const [adjusting, setAdjusting] = useState(false);
  const [adjustError, setAdjustError] = useState<string | null>(null);
  const [adjustResult, setAdjustResult] = useState<{
    movesPosted: number;
    totalValue: number;
  } | null>(null);
  const [cancelReason, setCancelReason] = useState("");
  const [cancelling, setCancelling] = useState(false);
  const [cancelError, setCancelError] = useState<string | null>(null);

  const canLockNow = count.status === "submitted" && canLock;
  const canAdjustNow = count.status === "locked" && canAdjustApprove;
  const canCancelNow =
    ["open", "counting", "recount", "submitted"].includes(count.status) &&
    canOpen;
  const lockValid = redLines.every((line) => reasons[line.line_id]?.reasonCode);

  async function handleLock(): Promise<void> {
    if (!lockValid || locking) {
      return;
    }
    setLocking(true);
    setLockError(null);
    const res = await lockCountAction({
      countId: count.id,
      reasons: redLines.map((line) => ({
        lineId: line.line_id,
        reasonCode: reasons[line.line_id]?.reasonCode as ReasonCode,
        explanation: reasons[line.line_id]?.explanation || null,
      })),
    });
    setLocking(false);
    if (!res.ok) {
      setLockError(res.error);
      return;
    }
    router.refresh();
  }

  async function handleAdjust(): Promise<void> {
    if (adjusting) {
      return;
    }
    setAdjusting(true);
    setAdjustError(null);
    const res = await adjustCountAction({ countId: count.id });
    setAdjusting(false);
    setAdjustOpen(false);
    if (!res.ok) {
      setAdjustError(res.error);
      return;
    }
    setAdjustResult({
      movesPosted: res.data.moves_posted,
      totalValue: res.data.total_value,
    });
    router.refresh();
  }

  async function handleCancel(): Promise<void> {
    if (!cancelReason.trim() || cancelling) {
      return;
    }
    setCancelling(true);
    setCancelError(null);
    const res = await cancelCountAction({
      countId: count.id,
      reason: cancelReason.trim(),
    });
    setCancelling(false);
    if (!res.ok) {
      setCancelError(res.error);
      return;
    }
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">{count.doc_no}</h1>
          <p className="text-sm text-muted-foreground">
            {count.warehouse_name ?? vi.common.noData} ·{" "}
            {formatYmd(count.business_date)} · {kindLabel(count.kind)}
          </p>
          <p className="text-sm text-muted-foreground">
            {interpolate(vi.count.countersCount, {
              count: count.counter_ids.length,
            })}
            {counters.length > 0
              ? `: ${count.counter_ids
                  .map((id) => counterNames.get(id) ?? id)
                  .join(", ")}`
              : ""}
          </p>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          <DocStatusBadge status={count.status} />
          {result.length > 0 ? (
            <CountExportButton rows={result} docNo={count.doc_no} />
          ) : null}
        </div>
      </div>

      <a
        href={`/${propertyId}/inventory/counts`}
        className="text-sm font-medium text-primary underline"
      >
        ← {vi.count.backToList}
      </a>

      {!canViewVariance ? (
        <p className="rounded-lg border p-3 text-sm text-muted-foreground">
          {vi.count.noViewVarianceHint}
        </p>
      ) : result.length === 0 ? (
        <EmptyState title={vi.count.reportEmpty} />
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-3 py-2 font-medium">
                  {vi.count.exportColumns.itemCode}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.count.exportColumns.itemName}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.count.exportColumns.uom}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.count.countedQty1}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.count.countedQty2}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.count.finalQty}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.count.bookQty}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.count.varianceQty}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.count.variancePct}
                </th>
                <th className="px-3 py-2 font-medium">{vi.count.flag}</th>
                <th className="px-3 py-2 font-medium">{vi.count.reasonCode}</th>
                <th className="px-3 py-2 font-medium">
                  {vi.count.explanation}
                </th>
              </tr>
            </thead>
            <tbody>
              {result.map((row) => (
                <tr
                  key={row.line_id}
                  className={cn(
                    "border-b last:border-0",
                    row.flag === "red" && "bg-red-50/60",
                    row.flag === "recount" && "bg-amber-50/60",
                  )}
                >
                  <td className="px-3 py-2 font-medium">{row.item_code}</td>
                  <td className="px-3 py-2">{row.item_name}</td>
                  <td className="px-3 py-2">{row.stock_uom}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {row.counted_qty_1 === null
                      ? vi.common.noData
                      : formatQty(row.counted_qty_1)}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {row.counted_qty_2 === null
                      ? vi.common.noData
                      : formatQty(row.counted_qty_2)}
                  </td>
                  <td className="px-3 py-2 text-right font-medium tabular-nums">
                    {row.final_qty === null
                      ? vi.common.noData
                      : formatQty(row.final_qty)}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {row.book_qty === null
                      ? vi.common.noData
                      : formatQty(row.book_qty)}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {row.variance_qty === null
                      ? vi.common.noData
                      : formatQty(row.variance_qty)}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {row.variance_pct === null
                      ? vi.common.noData
                      : `${formatQty(row.variance_pct)}%`}
                  </td>
                  <td className="px-3 py-2">
                    <span
                      className={cn(
                        "rounded px-2 py-0.5 text-xs font-medium",
                        row.flag === "ok" && "bg-green-100 text-green-800",
                        row.flag === "recount" && "bg-amber-100 text-amber-800",
                        row.flag === "red" && "bg-red-100 text-red-800",
                      )}
                    >
                      {flagLabel(row.flag)}
                    </span>
                  </td>
                  <td className="px-3 py-2">{reasonLabel(row.reason_code)}</td>
                  <td className="px-3 py-2">
                    {row.explanation ?? vi.common.noData}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {adjustment ? (
        <div className="rounded-xl border bg-card p-4">
          <p className="text-sm font-medium">{vi.count.adjustment}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {adjustment.status === "approved"
              ? vi.count.adjustmentApproved
              : vi.count.adjustmentPending}
            {" · "}
            {vi.count.movesPosted}: {adjustment.moves_posted ?? 0}
            {canViewValue && adjustment.total_value !== null ? (
              <>
                {" · "}
                {vi.count.totalValue}:{" "}
                <MoneyText amount={adjustment.total_value} />
              </>
            ) : null}
          </p>
        </div>
      ) : null}

      {adjustResult ? (
        <p
          role="status"
          className="rounded-lg border border-green-200 bg-green-50 p-3 text-sm text-green-800"
        >
          {interpolate(vi.count.adjustSuccess, {
            moves: adjustResult.movesPosted,
          })}
        </p>
      ) : null}
      {adjustError ? (
        <p role="alert" className="text-sm text-destructive">
          {adjustError}
        </p>
      ) : null}

      {canLockNow ? (
        <div className="flex flex-col gap-3 rounded-xl border bg-card p-4">
          <p className="text-sm font-medium">{vi.count.lockTitle}</p>
          <p className="text-xs text-muted-foreground">{vi.count.lockHint}</p>
          {redLines.length === 0 ? (
            <p className="text-sm text-muted-foreground">{vi.count.flags.ok}</p>
          ) : (
            redLines.map((line) => (
              <div
                key={line.line_id}
                className="flex flex-col gap-2 border-t pt-3"
              >
                <p className="text-sm font-medium">
                  {line.item_code} — {line.item_name} · {vi.count.varianceQty}:{" "}
                  {line.variance_qty === null
                    ? vi.common.noData
                    : formatQty(line.variance_qty)}{" "}
                  {line.stock_uom}
                </p>
                <label className="flex flex-col gap-1.5 text-sm font-medium">
                  {vi.count.reasonCode} *
                  <select
                    value={reasons[line.line_id]?.reasonCode ?? ""}
                    onChange={(event) =>
                      setReasons((prev) => ({
                        ...prev,
                        [line.line_id]: {
                          reasonCode: event.target.value,
                          explanation: prev[line.line_id]?.explanation ?? "",
                        },
                      }))
                    }
                    disabled={locking}
                    className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
                  >
                    <option value="">{vi.count.reasonCode}</option>
                    {REASON_CODES.map((code) => (
                      <option key={code} value={code}>
                        {reasonLabel(code)}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="flex flex-col gap-1.5 text-sm font-medium">
                  {vi.count.explanation}
                  <input
                    value={reasons[line.line_id]?.explanation ?? ""}
                    onChange={(event) =>
                      setReasons((prev) => ({
                        ...prev,
                        [line.line_id]: {
                          reasonCode: prev[line.line_id]?.reasonCode ?? "",
                          explanation: event.target.value,
                        },
                      }))
                    }
                    disabled={locking}
                    maxLength={1000}
                    className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
                  />
                </label>
              </div>
            ))
          )}
          {lockError ? (
            <p role="alert" className="text-sm text-destructive">
              {lockError}
            </p>
          ) : null}
          <Button
            disabled={!lockValid || locking}
            onClick={() => void handleLock()}
          >
            {locking ? vi.count.locking : vi.count.lockButton}
          </Button>
        </div>
      ) : null}

      {canAdjustNow ? (
        <div className="flex flex-col gap-2 rounded-xl border bg-card p-4">
          <p className="text-sm font-medium">{vi.count.adjustTitle}</p>
          <Button disabled={adjusting} onClick={() => setAdjustOpen(true)}>
            {adjusting ? vi.count.adjusting : vi.count.adjustButton}
          </Button>
        </div>
      ) : null}

      {canCancelNow ? (
        <div className="flex flex-col gap-2 rounded-xl border bg-card p-4">
          <p className="text-sm font-medium">{vi.count.cancelTitle}</p>
          <label className="flex flex-col gap-1.5 text-sm font-medium">
            {vi.count.cancelReason} *
            <input
              value={cancelReason}
              onChange={(event) => setCancelReason(event.target.value)}
              disabled={cancelling}
              maxLength={1000}
              className="h-12 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
            />
          </label>
          {cancelError ? (
            <p role="alert" className="text-sm text-destructive">
              {cancelError}
            </p>
          ) : null}
          <Button
            variant="destructive"
            disabled={!cancelReason.trim() || cancelling}
            onClick={() => void handleCancel()}
          >
            {cancelling ? vi.count.cancelling : vi.count.cancelButton}
          </Button>
        </div>
      ) : null}

      <ConfirmPostDialog
        open={adjustOpen}
        onOpenChange={setAdjustOpen}
        title={vi.count.adjustTitle}
        docNo={count.doc_no}
        consequences={[vi.count.adjustButton]}
        confirmLabel={vi.count.adjustButton}
        onConfirm={() => void handleAdjust()}
        confirming={adjusting}
      />
    </div>
  );
}
