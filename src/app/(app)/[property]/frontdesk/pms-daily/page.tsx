import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { PmsDailyForm } from "@/components/pms-daily/pms-daily-form";
import {
  getPmsDailyHistory,
  getPmsDailyPerms,
  getPmsDailyStats,
  type PmsDailyHistoryEntry,
  type PmsDailyStatsValues,
} from "@/features/pms-daily/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

type HistoryFieldKey = keyof PmsDailyStatsValues;

const HISTORY_FIELDS: HistoryFieldKey[] = [
  "rooms_available",
  "rooms_sold",
  "guests",
  "breakfast_pax",
  "extra_beds",
  "checkouts",
];

function fieldLabel(key: HistoryFieldKey): string {
  switch (key) {
    case "rooms_available":
      return vi.pmsDaily.fields.roomsAvailable;
    case "rooms_sold":
      return vi.pmsDaily.fields.roomsSold;
    case "guests":
      return vi.pmsDaily.fields.guests;
    case "breakfast_pax":
      return vi.pmsDaily.fields.breakfastPax;
    case "extra_beds":
      return vi.pmsDaily.fields.extraBeds;
    case "checkouts":
      return vi.pmsDaily.fields.checkouts;
  }
}

function shiftDate(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function formatTime(at: string): string {
  return new Date(at).toLocaleString("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

/** 1 mục lịch sử: ai, lúc nào, đổi gì (chỉ liệt kê trường thay đổi). */
function HistoryItem({ entry }: { entry: PmsDailyHistoryEntry }) {
  const changes = HISTORY_FIELDS.filter(
    (key) =>
      entry.action === "INSERT" ||
      entry.old_stats?.[key] !== entry.new_stats?.[key],
  );
  return (
    <li className="rounded-md border px-3 py-2 text-sm">
      <p className="font-medium">
        {entry.action === "INSERT"
          ? vi.pmsDaily.historyCreated
          : vi.pmsDaily.historyUpdated}
        {" — "}
        {entry.actor_name || "—"}
        {" · "}
        {formatTime(entry.at)}
      </p>
      <ul className="mt-1 list-disc space-y-0.5 pl-5 text-muted-foreground">
        {changes.map((key) => (
          <li key={key}>
            {fieldLabel(key)}
            {": "}
            {entry.action === "INSERT"
              ? (entry.new_stats?.[key] ?? "—")
              : `${entry.old_stats?.[key] ?? "—"} → ${entry.new_stats?.[key] ?? "—"}`}
          </li>
        ))}
      </ul>
    </li>
  );
}

/** Màn lễ tân — số liệu PMS ngày (T-036). */
export default async function FrontdeskPmsDailyPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ date?: string | string[] }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
  const rawDate = typeof sp.date === "string" ? sp.date : "";
  const businessDate = /^\d{4}-\d{2}-\d{2}$/.test(rawDate) ? rawDate : today;
  const isFuture = businessDate > today;

  const [statsRes, histRes, perms] = await Promise.all([
    getPmsDailyStats(propertyId, businessDate),
    getPmsDailyHistory(propertyId, businessDate),
    getPmsDailyPerms(propertyId),
  ]);

  if (!statsRes.ok) {
    return <ErrorState description={statsRes.error} />;
  }
  if (!histRes.ok) {
    return <ErrorState description={histRes.error} />;
  }

  return (
    <div className="space-y-4">
      <PageHeader title={vi.pmsDaily.frontdeskTitle} />

      <form method="get" className="flex flex-wrap items-end gap-2">
        <label className="block text-sm">
          {vi.pmsDaily.dateLabel}
          <input
            type="date"
            name="date"
            defaultValue={businessDate}
            max={today}
            className="mt-1 block h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <Link
          href={`/${propertyId}/frontdesk/pms-daily?date=${shiftDate(businessDate, -1)}`}
          className="inline-flex h-9 items-center rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          ← {vi.pmsDaily.prevDay}
        </Link>
        <Link
          href={`/${propertyId}/frontdesk/pms-daily?date=${shiftDate(businessDate, 1)}`}
          className="inline-flex h-9 items-center rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.pmsDaily.nextDay} →
        </Link>
        <button
          type="submit"
          className="inline-flex h-9 items-center rounded-md bg-primary px-3 text-sm font-medium text-primary-foreground outline-none transition-colors hover:bg-primary/90 focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.pmsDaily.viewButton}
        </button>
      </form>

      <PmsDailyForm
        propertyId={propertyId}
        businessDate={businessDate}
        initial={statsRes.data}
        canEnter={perms.canEnter}
        isFuture={isFuture}
      />

      <section className="space-y-2">
        <h2 className="text-base font-semibold">{vi.pmsDaily.historyTitle}</h2>
        {histRes.data.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.pmsDaily.historyEmpty}
          </p>
        ) : (
          <ul className="space-y-2">
            {histRes.data.map((entry, i) => (
              <HistoryItem key={`${entry.at}-${i}`} entry={entry} />
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
