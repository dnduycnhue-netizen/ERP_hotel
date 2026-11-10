"use client";

import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { addCountCounterAction } from "@/features/count/actions";
import type {
  CountCounter,
  CountItemDetail,
  CountRow,
  CountSheetRow,
} from "@/features/count/queries";
import { vi } from "@/i18n/vi";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";
import { cn } from "@/lib/utils";
import { CountSubmitDialog } from "./count-submit-dialog";
import { formatQty, formatYmd, interpolate } from "./count-utils";
import { MobileCountLineForm } from "./mobile-count-line-form";

const RECORDABLE_STATUSES = ["open", "counting", "recount"] as const;

/**
 * Màn đếm mù mobile (T-033, docs/06-UI-UX.md §3.2):
 * - Chỉ hiện mã/tên/ĐVT + số của chính mình; TUYỆT ĐỐI không hiện số sổ,
 *   số lý thuyết, chênh lệch (view v_count_sheet cũng không có các cột đó).
 * - Vòng đếm lại: chỉ dòng flag='recount' được ghi lại, hiện nổi bật vàng
 *   "Đếm lại lần cuối", số cũ đã bị server xóa nên không hiển thị.
 * - Nộp đợt: 1 PIN cho mỗi người đếm (dialog riêng). Submit chỉ online.
 */
export function MobileCountWorkspace({
  count,
  sheet,
  items,
  counters,
  eligibleCounters,
  isCounter,
  canOpen,
  canPerform,
  canViewVariance,
  propertyId,
}: {
  count: CountRow;
  sheet: CountSheetRow[];
  items: Record<string, CountItemDetail>;
  /** Tên người đếm (chỉ khi viewer có count.open). */
  counters: CountCounter[];
  /** Người đủ điều kiện đếm tại kho (chỉ khi viewer có count.open). */
  eligibleCounters: CountCounter[];
  isCounter: boolean;
  canOpen: boolean;
  canPerform: boolean;
  canViewVariance: boolean;
  propertyId: string;
}) {
  const router = useRouter();
  const { online } = useOfflineSync({
    onCountRecordSynced: () => router.refresh(),
  });
  const [selectedLineId, setSelectedLineId] = useState<string | null>(null);
  const [submitOpen, setSubmitOpen] = useState(false);
  const [submitResult, setSubmitResult] = useState<{
    recountLineIds: string[];
    redLineIds: string[];
  } | null>(null);
  const [addCounterId, setAddCounterId] = useState("");
  const [addingCounter, setAddingCounter] = useState(false);
  const [addCounterError, setAddCounterError] = useState<string | null>(null);

  const isRecordable = (RECORDABLE_STATUSES as readonly string[]).includes(
    count.status,
  );
  const canRecord = isRecordable && isCounter && canPerform;
  const canSubmit =
    (count.status === "counting" || count.status === "recount") && isCounter;

  const orderedSheet = useMemo(() => {
    if (count.status !== "recount") {
      return sheet;
    }
    return [...sheet].sort((a, b) => {
      const aRecount = a.flag === "recount" ? 0 : 1;
      const bRecount = b.flag === "recount" ? 0 : 1;
      if (aRecount !== bRecount) {
        return aRecount - bRecount;
      }
      return a.item_code.localeCompare(b.item_code);
    });
  }, [sheet, count.status]);

  const countedLines = sheet.filter((line) => line.has_counted).length;
  const counterNames = new Map(counters.map((c) => [c.id, c.full_name]));
  const addableCounters = eligibleCounters.filter(
    (c) => !count.counter_ids.includes(c.id),
  );

  function isLineRecordable(line: CountSheetRow): boolean {
    if (!canRecord) {
      return false;
    }
    if (count.status === "recount") {
      return line.flag === "recount";
    }
    return true;
  }

  async function handleAddCounter(): Promise<void> {
    if (!addCounterId || addingCounter) {
      return;
    }
    setAddingCounter(true);
    setAddCounterError(null);
    const res = await addCountCounterAction({
      countId: count.id,
      userId: addCounterId,
    });
    setAddingCounter(false);
    if (!res.ok) {
      setAddCounterError(res.error);
      return;
    }
    setAddCounterId("");
    router.refresh();
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-xl font-semibold">{count.doc_no}</h1>
          <p className="text-sm text-muted-foreground">
            {count.warehouse_name ?? vi.common.noData} ·{" "}
            {formatYmd(count.business_date)}
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
        <DocStatusBadge status={count.status} />
      </div>

      {count.kind === "monthly_full" && isRecordable ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          {vi.count.freezeNote}
        </p>
      ) : null}

      {count.status === "recount" ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800">
          {vi.count.recountHint}
        </p>
      ) : null}

      {submitResult ? (
        <div
          role="status"
          className="rounded-lg border border-green-200 bg-green-50 p-3 text-sm text-green-800"
        >
          <p>{vi.count.submitSuccess}</p>
          {submitResult.recountLineIds.length > 0 ? (
            <p>
              {interpolate(vi.count.submitRecount, {
                count: submitResult.recountLineIds.length,
              })}
            </p>
          ) : null}
          {submitResult.redLineIds.length > 0 ? (
            <p>
              {interpolate(vi.count.submitRed, {
                count: submitResult.redLineIds.length,
              })}
            </p>
          ) : null}
        </div>
      ) : null}

      {!isCounter && isRecordable ? (
        <p className="rounded-lg border p-3 text-sm text-muted-foreground">
          {vi.count.notCounter}
        </p>
      ) : null}

      <p className="text-sm text-muted-foreground">
        {vi.count.lineCounted}: {countedLines}/{sheet.length}
      </p>

      {sheet.length === 0 ? (
        <EmptyState title={vi.count.sheetEmpty} />
      ) : (
        <ul className="flex flex-col gap-2">
          {orderedSheet.map((line) => {
            const item = items[line.item_id];
            const recordable = isLineRecordable(line);
            const isRecountLine =
              count.status === "recount" && line.flag === "recount";
            const selected = selectedLineId === line.line_id;
            return (
              <li
                key={line.line_id}
                className={cn(
                  "rounded-xl border bg-card",
                  isRecountLine && "border-amber-300 bg-amber-50/60",
                )}
              >
                <button
                  type="button"
                  disabled={!recordable}
                  onClick={() =>
                    setSelectedLineId(selected ? null : line.line_id)
                  }
                  className="flex w-full items-start justify-between gap-3 p-4 text-left disabled:cursor-default"
                >
                  <span>
                    <span className="block font-medium">
                      {line.item_code} — {line.item_name}
                    </span>
                    <span className="block text-sm text-muted-foreground">
                      {vi.inventory.stockUom}: {line.stock_uom}
                      {line.has_counted && line.my_counted_qty !== null ? (
                        <>
                          {" · "}
                          {vi.count.lineCounted}:{" "}
                          {formatQty(line.my_counted_qty)} {line.stock_uom}
                        </>
                      ) : null}
                    </span>
                    {isRecountLine ? (
                      <span className="mt-1 inline-block rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800">
                        {vi.count.lineNeedsRecount}
                      </span>
                    ) : null}
                    {line.flag === "red" ? (
                      <span className="mt-1 inline-block rounded bg-red-100 px-2 py-0.5 text-xs font-medium text-red-800">
                        {vi.count.lineRed}
                      </span>
                    ) : null}
                  </span>
                  <span
                    className={cn(
                      "shrink-0 rounded px-2 py-0.5 text-xs font-medium",
                      line.has_counted && !isRecountLine
                        ? "bg-green-100 text-green-800"
                        : "bg-muted text-muted-foreground",
                    )}
                  >
                    {line.has_counted && !isRecountLine
                      ? vi.count.lineCounted
                      : vi.count.lineNotCounted}
                  </span>
                </button>
                {selected && item ? (
                  <div className="border-t p-3">
                    <MobileCountLineForm
                      line={line}
                      item={item}
                      countId={count.id}
                      propertyId={propertyId}
                      canPerform={canPerform}
                      onSaved={() => {
                        setSelectedLineId(null);
                        router.refresh();
                      }}
                      onQueued={() => {
                        setSelectedLineId(null);
                        router.refresh();
                      }}
                      onClose={() => setSelectedLineId(null)}
                    />
                  </div>
                ) : null}
              </li>
            );
          })}
        </ul>
      )}

      {canSubmit ? (
        <Button
          size="lg"
          className="h-14 text-base"
          disabled={!online}
          onClick={() => setSubmitOpen(true)}
        >
          {vi.count.submitButton}
        </Button>
      ) : null}
      {canSubmit && !online ? (
        <p className="text-sm text-muted-foreground">
          {vi.offline.startNeedsOnline}
        </p>
      ) : null}

      {canOpen && isRecordable && addableCounters.length > 0 ? (
        <div className="flex flex-col gap-2 rounded-xl border bg-card p-4">
          <p className="text-sm font-medium">{vi.count.addCounterTitle}</p>
          <div className="flex gap-2">
            <select
              value={addCounterId}
              onChange={(event) => setAddCounterId(event.target.value)}
              disabled={addingCounter}
              aria-label={vi.count.selectCounters}
              className="h-12 flex-1 rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
            >
              <option value="">{vi.count.selectCounters}</option>
              {addableCounters.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.full_name} ({c.employee_code})
                </option>
              ))}
            </select>
            <Button
              disabled={!addCounterId || addingCounter}
              onClick={() => void handleAddCounter()}
            >
              {addingCounter
                ? vi.count.addingCounter
                : vi.count.addCounterButton}
            </Button>
          </div>
          {addCounterError ? (
            <p role="alert" className="text-sm text-destructive">
              {addCounterError}
            </p>
          ) : null}
        </div>
      ) : null}

      {!isRecordable ? (
        <div className="rounded-xl border bg-card p-4">
          <p className="text-sm text-muted-foreground">
            {count.status === "submitted"
              ? vi.count.lockTitle
              : count.status === "locked"
                ? vi.count.adjustTitle
                : count.status === "adjusted"
                  ? vi.count.adjustmentApproved
                  : vi.count.cancelTitle}
          </p>
          {canViewVariance ? (
            <a
              href={`/${propertyId}/inventory/counts/${count.id}`}
              className="mt-2 inline-block text-sm font-medium text-primary underline"
            >
              {vi.count.viewReport}
            </a>
          ) : null}
        </div>
      ) : null}

      <CountSubmitDialog
        open={submitOpen}
        onOpenChange={setSubmitOpen}
        countId={count.id}
        docNo={count.doc_no}
        counterCount={count.counter_ids.length}
        onSubmitted={(result) => {
          setSubmitResult(result);
          router.refresh();
        }}
      />
    </div>
  );
}
