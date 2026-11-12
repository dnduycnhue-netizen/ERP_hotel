import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import {
  getRestaurantPerms,
  listBuffetSessions,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

function vnToday(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

function mealLabel(meal: string): string {
  if (meal === "breakfast") return vi.restaurant.mealBreakfast;
  if (meal === "lunch") return vi.restaurant.mealLunch;
  return vi.restaurant.mealDinner;
}

function sessionDocStatus(status: string) {
  if (status === "planned") return "new" as const;
  if (status === "open") return "in_progress" as const;
  if (status === "closed") return "completed" as const;
  return "cancelled" as const;
}

/** Danh sách phiên buffet (M06), mặc định tháng hiện tại. */
export default async function BuffetPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const today = vnToday();
  const from = sp.from ?? `${today.slice(0, 7)}-01`;
  const to = sp.to ?? today;

  const [res, perms] = await Promise.all([
    listBuffetSessions(propertyId, from, to),
    getRestaurantPerms(propertyId),
  ]);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  const sessions = res.data;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold">{vi.restaurant.buffetTitle}</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.restaurant.buffetHint}
          </p>
        </div>
        {perms.canManageBuffet ? (
          <Link
            href={`/${propertyId}/restaurant/buffet/new`}
            className="inline-flex h-9 items-center justify-center rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground"
          >
            {vi.restaurant.newSession}
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
            className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.reports.to}</span>
          <input
            type="date"
            name="to"
            defaultValue={to}
            className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <button
          type="submit"
          className="inline-flex h-9 items-center justify-center rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.reports.applyFilter}
        </button>
      </form>

      {sessions.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          {vi.restaurant.noSessions}
        </p>
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-left">
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.sessionDate}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.sessionMeal}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.guestCount}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.sessionDishes}
                </th>
                <th className="px-3 py-2 font-medium">{vi.common.status}</th>
              </tr>
            </thead>
            <tbody>
              {sessions.map((s) => (
                <tr key={s.id} className="border-b last:border-0">
                  <td className="px-3 py-2">
                    <Link
                      href={`/${propertyId}/restaurant/buffet/${s.id}`}
                      className="font-medium underline-offset-2 hover:underline"
                    >
                      {s.business_date}
                    </Link>
                  </td>
                  <td className="px-3 py-2">{mealLabel(s.meal)}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {s.guest_count}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {s.dish_count}
                  </td>
                  <td className="px-3 py-2">
                    <DocStatusBadge status={sessionDocStatus(s.status)} />
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
