import Link from "next/link";
import { notFound } from "next/navigation";
import { ChevronLeft, ChevronRight, TriangleAlert } from "lucide-react";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { LocksDayCalendar } from "@/components/inventory/locks-day-calendar";
import { LocksPeriodPanel } from "@/components/inventory/locks-period-panel";
import { PageHeader } from "@/components/shell/page-header";
import { shiftMonth, todayInVietnam } from "@/features/locks/date-utils";
import { getLocksOverview } from "@/features/locks/queries";
import { vi } from "@/i18n/vi";

/**
 * Màn khóa ngày / khóa kỳ (C1, M05): lịch tháng khóa ngày theo từng kho,
 * trạng thái đóng băng kiểm kê, khóa kỳ với 3 điều kiện tiên quyết
 * (05 §10). Quyền xem: `day.lock` / `day.unlock` / `period.close` /
 * `period.reopen` / `count.view_variance` — Q35/Q38 vẫn mở nên không
 * tự gán thêm quyền cho ai (xem docs/OPEN-QUESTIONS.md).
 */
const VIEW_PERMS = [
  "day.lock",
  "day.unlock",
  "period.close",
  "period.reopen",
  "count.view_variance",
] as const;

export default async function LocksPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ year?: string; month?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;

  const today = todayInVietnam();
  const fallbackYear = Number(today.slice(0, 4));
  const fallbackMonth = Number(today.slice(5, 7));
  const parsedYear = Number.parseInt(sp.year ?? "", 10);
  const parsedMonth = Number.parseInt(sp.month ?? "", 10);
  const year =
    Number.isInteger(parsedYear) && parsedYear >= 1 && parsedYear <= 9999
      ? parsedYear
      : fallbackYear;
  const month =
    Number.isInteger(parsedMonth) && parsedMonth >= 1 && parsedMonth <= 12
      ? parsedMonth
      : fallbackMonth;

  const res = await getLocksOverview({ propertyId, year, month });
  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  const overview = res.data;

  const perms = new Set(overview.permissions);
  const canView = VIEW_PERMS.some((code) => perms.has(code));
  if (!canView) {
    notFound();
  }
  const canLock = perms.has("day.lock");
  const canUnlock = perms.has("day.unlock");
  const canClose = perms.has("period.close");
  const canReopen = perms.has("period.reopen");

  const prev = shiftMonth(year, month, -1);
  const next = shiftMonth(year, month, 1);
  const monthLabel = `${vi.locks.monthLabel} ${String(month).padStart(2, "0")}/${year}`;

  function hrefFor(y: number, m: number): string {
    return `/${propertyId}/inventory/locks?year=${y}&month=${m}`;
  }

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={vi.locks.title} description={vi.locks.description} />

      <div className="flex flex-wrap items-center gap-2">
        <Link
          href={hrefFor(prev.year, prev.month)}
          aria-label={vi.locks.prevMonth}
          className="inline-flex h-9 items-center gap-1 rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          <ChevronLeft className="size-4" aria-hidden />
          {vi.locks.prevMonth}
        </Link>
        <span className="min-w-28 text-center text-sm font-semibold">
          {monthLabel}
        </span>
        <Link
          href={hrefFor(next.year, next.month)}
          aria-label={vi.locks.nextMonth}
          className="inline-flex h-9 items-center gap-1 rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.locks.nextMonth}
          <ChevronRight className="size-4" aria-hidden />
        </Link>
      </div>

      {overview.check.frozen_warehouses.length > 0 ? (
        <div
          role="status"
          className="flex flex-col gap-1 rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm dark:border-amber-900 dark:bg-amber-950/40"
        >
          <p className="flex items-center gap-2 font-semibold text-amber-800 dark:text-amber-200">
            <TriangleAlert className="size-4" aria-hidden />
            {vi.locks.frozenTitle}
          </p>
          <p className="text-amber-700 dark:text-amber-300">
            {vi.locks.frozenHint}
          </p>
          <ul className="list-disc pl-5 text-amber-700 dark:text-amber-300">
            {overview.check.frozen_warehouses.map((frozen) => (
              <li key={frozen.warehouse_id}>
                {frozen.warehouse_name} — {vi.locks.frozenCount}{" "}
                {frozen.count_doc_no}
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {!canLock && !canUnlock ? (
        <p className="text-sm text-muted-foreground">
          {vi.locks.needsLockPermission}
        </p>
      ) : null}

      {overview.warehouses.length === 0 ? (
        <EmptyState title={vi.locks.noWarehouses} />
      ) : (
        <LocksDayCalendar
          propertyId={propertyId}
          year={year}
          month={month}
          warehouses={overview.warehouses}
          locks={overview.locks}
          frozenWarehouses={overview.check.frozen_warehouses}
          canLock={canLock}
          canUnlock={canUnlock}
        />
      )}

      <h2 className="mt-2 text-base font-semibold">{vi.locks.periodTitle}</h2>
      <LocksPeriodPanel
        propertyId={propertyId}
        entityId={overview.entityId}
        year={year}
        month={month}
        check={overview.check}
        periods={overview.periods}
        canClose={canClose}
        canReopen={canReopen}
      />
    </div>
  );
}
