import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { formatMoney } from "@/components/common/money-text";
import {
  getRestaurantPerms,
  listBanquets,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

function vnToday(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

function banquetDocStatus(status: string) {
  if (status === "new") return "new" as const;
  if (status === "confirmed") return "confirmed" as const;
  if (status === "in_progress") return "in_progress" as const;
  if (status === "completed") return "completed" as const;
  return "cancelled" as const;
}

/** Danh sách đặt tiệc (M06): mặc định hôm nay → 60 ngày sau. */
export default async function BanquetsPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ from?: string; to?: string; status?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const today = vnToday();
  const toDate = new Date(today);
  toDate.setDate(toDate.getDate() + 60);
  const to = sp.to ?? toDate.toISOString().slice(0, 10);
  const from = sp.from ?? today;
  const status = sp.status ?? "";

  const [res, perms] = await Promise.all([
    listBanquets(propertyId, from, to, status || null),
    getRestaurantPerms(propertyId),
  ]);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  const banquets = res.data;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold">
            {vi.restaurant.banquetsTitle}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.restaurant.banquetsHint}
          </p>
        </div>
        {perms.canManageBanquet ? (
          <Link
            href={`/${propertyId}/restaurant/banquets/new`}
            className="inline-flex h-9 items-center justify-center rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground"
          >
            {vi.restaurant.newBanquet}
          </Link>
        ) : null}
      </div>

      <form method="get" className="flex flex-wrap items-end gap-3">
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.reports.from}</span>
          <input
            type="date"
            name="from"
            defaultValue={from}
            className="h-9 rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.reports.to}</span>
          <input
            type="date"
            name="to"
            defaultValue={to}
            className="h-9 rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.common.status}</span>
          <select
            name="status"
            defaultValue={status}
            className="h-9 rounded-lg border border-border bg-background px-2"
          >
            <option value="">{vi.restaurant.allStatuses}</option>
            <option value="new">{vi.components.docStatus.new}</option>
            <option value="confirmed">{vi.restaurant.banquetConfirmed}</option>
            <option value="in_progress">
              {vi.components.docStatus.inProgress}
            </option>
            <option value="completed">{vi.restaurant.banquetCompleted}</option>
            <option value="cancelled">{vi.restaurant.banquetCancelled}</option>
          </select>
        </label>
        <button
          type="submit"
          className="inline-flex h-9 items-center justify-center rounded-lg border border-border bg-background px-3 text-sm font-medium hover:bg-muted"
        >
          {vi.reports.applyFilter}
        </button>
      </form>

      {banquets.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          {vi.restaurant.noBanquets}
        </p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-left">
                <th className="px-3 py-2 font-medium">{vi.restaurant.docNo}</th>
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.eventDate}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.customerName}
                </th>
                <th className="px-3 py-2 font-medium">{vi.restaurant.hall}</th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.tablesCount}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.guestsCount}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.depositAmount}
                </th>
                <th className="px-3 py-2 font-medium">{vi.common.status}</th>
              </tr>
            </thead>
            <tbody>
              {banquets.map((b) => (
                <tr key={b.id} className="border-b last:border-0">
                  <td className="px-3 py-2 font-mono text-xs">
                    <Link
                      href={`/${propertyId}/restaurant/banquets/${b.id}`}
                      className="font-medium underline-offset-2 hover:underline"
                    >
                      {b.doc_no}
                    </Link>
                  </td>
                  <td className="px-3 py-2">
                    {b.event_date} {b.start_time}–{b.end_time}
                  </td>
                  <td className="px-3 py-2">{b.customer_name}</td>
                  <td className="px-3 py-2">{b.hall}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {b.tables_count ?? "—"}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {b.guests_count}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {formatMoney(b.deposit_amount)}
                  </td>
                  <td className="px-3 py-2">
                    <DocStatusBadge status={banquetDocStatus(b.status)} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
