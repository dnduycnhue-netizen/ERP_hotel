"use client";

import { useRouter } from "next/navigation";
import { useMemo, useRef, useState } from "react";
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
import {
  formatQty,
  formatYmd,
  interpolate,
  normalizeSearch,
} from "./count-utils";
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
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<
    "all" | "uncounted" | "counted" | "recount"
  >("all");
  const lineElementsRef = useRef(new Map<string, HTMLLIElement>());
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
  const progressPct =
    sheet.length === 0 ? 0 : (countedLines / sheet.length) * 100;
  const uncountedCount = sheet.filter((line) => !line.has_counted).length;
  const recountCount = sheet.filter((line) => line.flag === "recount").length;

  const normalizedQuery = normalizeSearch(query.trim());
  const visibleSheet = useMemo(() => {
    let rows = orderedSheet;
    if (filter === "uncounted") {
      rows = rows.filter((line) => !line.has_counted);
    } else if (filter === "counted") {
      rows = rows.filter((line) => line.has_counted);
    } else if (filter === "recount") {
      rows = rows.filter((line) => line.flag === "recount");
    }
    if (normalizedQuery !== "") {
      rows = rows.filter((line) =>
        normalizeSearch(`${line.item_code} ${line.item_name}`).includes(
          normalizedQuery,
        ),
      );
    }
    return rows;
  }, [orderedSheet, filter, normalizedQuery]);
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

  const nextUncountedLine = orderedSheet.find(
    (line) => isLineRecordable(line) && !line.has_counted,
  );

  /** Nhảy tới dòng chưa đếm đầu tiên (xóa lọc/tìm kiếm trước để dòng hiện ra). */
  function scrollToNextUncounted() {
    if (!nextUncountedLine) {
      return;
    }
    const targetId = nextUncountedLine.line_id;
    setFilter("all");
    setQuery("");
    window.setTimeout(() => {
      lineElementsRef.current
        .get(targetId)
        ?.scrollIntoView({ behavior: "smooth", block: "start" });
    }, 0);
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
          <p className="text-base text-muted-foreground">
            {count.warehouse_name ?? vi.common.noData} ·{" "}
            {formatYmd(count.business_date)}
          </p>
          <p className="text-base text-muted-foreground">
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

      <div>
        <div
          role="progressbar"
          aria-valuenow={countedLines}
          aria-valuemin={0}
          aria-valuemax={sheet.length}
          aria-label={interpolate(vi.count.countProgress, {
            done: countedLines,
            total: sheet.length,
          })}
          className="h-2.5 overflow-hidden rounded-full bg-muted"
        >
          <div
            className="h-full rounded-full bg-brand transition-all"
            style={{ width: `${progressPct}%` }}
          />
        </div>
        <p className="mt-2 text-base font-medium">
          {interpolate(vi.count.countProgress, {
            done: countedLines,
            total: sheet.length,
          })}
        </p>
        {nextUncountedLine ? (
          <Button
            type="button"
            variant="outline"
            onClick={scrollToNextUncounted}
            className="mt-3 min-h-11 w-full text-base"
          >
            {vi.count.nextUncounted}
          </Button>
        ) : null}
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
        <p className="rounded-lg border p-3 text-base text-muted-foreground">
          {vi.count.notCounter}
        </p>
      ) : null}

      {isRecordable ? (
        <>
          <label className="flex flex-col gap-1.5">
            <span className="sr-only">{vi.common.search}</span>
            <input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={vi.count.searchCountPlaceholder}
              aria-label={vi.count.searchCountPlaceholder}
              className="h-12 w-full rounded-lg border bg-background px-3 text-base outline-none focus:border-ring"
            />
          </label>

          <div
            className="flex flex-wrap gap-2"
            role="group"
            aria-label={vi.count.title}
          >
            {(
              [
                ["all", vi.common.all, sheet.length],
                ["uncounted", vi.count.filterUncounted, uncountedCount],
                ["counted", vi.count.filterCounted, countedLines],
                ...(count.status === "recount"
                  ? ([
                      ["recount", vi.count.filterRecount, recountCount],
                    ] as const)
                  : []),
              ] as const
            ).map(([value, label, chipCount]) => {
              const active = filter === value;
              return (
                <button
                  key={value}
                  type="button"
                  onClick={() => setFilter(value)}
                  aria-pressed={active}
                  className={cn(
                    "min-h-11 rounded-full border px-3 py-2 text-base font-medium",
                    active
                      ? "border-brand bg-brand text-brand-foreground"
                      : "bg-background",
                  )}
                >
                  {label} ({chipCount})
                </button>
              );
            })}
          </div>
        </>
      ) : null}

      {sheet.length === 0 ? (
        <EmptyState title={vi.count.sheetEmpty} />
      ) : visibleSheet.length === 0 ? (
        <EmptyState
          title={vi.count.countsTitle}
          description={vi.count.noMatchingLines}
        />
      ) : (
        <ul className="flex flex-col gap-2">
          {visibleSheet.map((line) => {
            const item = items[line.item_id];
            const recordable = isLineRecordable(line);
            const isRecountLine =
              count.status === "recount" && line.flag === "recount";
            const selected = selectedLineId === line.line_id;
            return (
              <li
                key={line.line_id}
                ref={(el) => {
                  if (el) {
                    lineElementsRef.current.set(line.line_id, el);
                  } else {
                    lineElementsRef.current.delete(line.line_id);
                  }
                }}
                className={cn(
                  "scroll-mt-24 rounded-xl border bg-card",
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
                    <span className="block text-base font-medium">
                      {line.item_code} — {line.item_name}
                    </span>
                    <span className="block text-base text-muted-foreground">
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

      {/* Thanh hành động dính đáy: nút Nộp đợt luôn thấy được mà không cần
          cuộn hết phiếu đếm. Submit chỉ online (T-033) — giữ nguyên.
          Sau khi gộp với shell của W1 (bottom tab cố định), shell cần
          chừa khoảng trống phía dưới — xem Q180. */}
      {canSubmit ? (
        <div className="sticky bottom-0 z-10 -mx-4 flex flex-col gap-2 border-t bg-background/95 px-4 pt-3 pb-[max(1rem,env(safe-area-inset-bottom))] backdrop-blur">
          <p className="text-base font-medium" aria-live="polite">
            {interpolate(vi.count.countProgress, {
              done: countedLines,
              total: sheet.length,
            })}
          </p>
          {!online ? (
            <p className="text-sm text-muted-foreground">
              {vi.offline.startNeedsOnline}
            </p>
          ) : null}
          <Button
            size="lg"
            className="h-14 w-full text-base"
            disabled={!online}
            onClick={() => setSubmitOpen(true)}
          >
            {vi.count.submitButton}
          </Button>
        </div>
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
              className="min-h-11"
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
