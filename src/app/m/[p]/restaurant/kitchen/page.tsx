import { ErrorState } from "@/components/common/error-state";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import { MobileRestaurantNav } from "@/components/restaurant/mobile-restaurant-nav";
import { getKitchenToday } from "@/features/restaurant/queries";
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

/**
 * Màn bếp mobile (W4): thực đơn hôm nay + buffet + tiệc + NVL chuẩn bị.
 * Đọc qua RPC `restaurant_kitchen_today` (đã kiểm `restaurant.view`);
 * foodcost hiện như bản desktop (cùng quyền xem — xem Q193).
 */
export default async function MobileKitchenPage({
  params,
  searchParams,
}: {
  params: Promise<{ p: string }>;
  searchParams: Promise<{ date?: string }>;
}) {
  const { p: propertyId } = await params;
  const sp = await searchParams;
  const date = sp.date ?? vnToday();

  const res = await getKitchenToday(propertyId, date);
  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  const kitchen = res.data;

  return (
    <div className="space-y-6">
      <MobileRestaurantNav propertyId={propertyId} />
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.kitchenTitle}</h1>
        <p className="mt-1 text-base text-muted-foreground">
          {vi.restaurant.kitchenHint}
        </p>
      </div>

      <form method="get" className="flex items-end gap-2">
        <label className="grow text-base">
          <span className="block font-medium">{vi.common.today}</span>
          <input
            type="date"
            name="date"
            defaultValue={date}
            className="mt-1 min-h-11 w-full rounded-lg border border-border bg-background px-2.5 text-base"
          />
        </label>
        <button
          type="submit"
          className="inline-flex min-h-11 items-center justify-center rounded-lg border border-border bg-background px-4 text-base font-medium hover:bg-muted"
        >
          {vi.reports.applyFilter}
        </button>
      </form>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">{vi.restaurant.todayMenu}</h2>
        {kitchen.dishes.length === 0 ? (
          <p className="text-base text-muted-foreground">
            {vi.restaurant.noDishes}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {kitchen.dishes.map((d) => (
              <li
                key={d.id}
                className="rounded-xl border bg-card p-4 text-base"
              >
                <p className="font-semibold">{d.name}</p>
                <p className="mt-1 flex flex-wrap justify-between gap-2 text-muted-foreground">
                  <span className="font-mono text-sm">{d.code}</span>
                  <span className="tabular-nums">
                    {d.sale_price !== null ? formatMoney(d.sale_price) : "—"}
                  </span>
                </p>
                <p className="mt-1 text-muted-foreground">
                  {vi.restaurant.foodcost}:{" "}
                  {d.foodcost !== null
                    ? formatMoney(d.foodcost)
                    : vi.restaurant.foodcostUnknown}
                </p>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">{vi.restaurant.todayBuffet}</h2>
        {kitchen.buffet_sessions.length === 0 ? (
          <p className="text-base text-muted-foreground">
            {vi.restaurant.mobile.noBuffetToday}
          </p>
        ) : (
          kitchen.buffet_sessions.map((s) => (
            <article
              key={s.id}
              className="rounded-xl border bg-card p-4 text-base"
            >
              <h3 className="font-semibold">
                {mealLabel(s.meal)} · {s.guest_count}{" "}
                {vi.restaurant.guestCount.toLowerCase()}
              </h3>
              <ul className="mt-2 list-disc space-y-1 pl-5">
                {s.dishes.map((d) => (
                  <li key={d.recipe_id}>
                    {d.recipe_name} — {formatNumber(d.planned_qty)}{" "}
                    {vi.restaurant.servings.toLowerCase()}
                  </li>
                ))}
              </ul>
            </article>
          ))
        )}
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">
          {vi.restaurant.todayBanquets}
        </h2>
        {kitchen.banquets.length === 0 ? (
          <p className="text-base text-muted-foreground">
            {vi.restaurant.noBanquets}
          </p>
        ) : (
          kitchen.banquets.map((b) => (
            <article
              key={b.id}
              className="rounded-xl border bg-card p-4 text-base"
            >
              <h3 className="font-semibold">
                {b.doc_no} — {b.customer_name} · {b.hall} · {b.start_time}–
                {b.end_time}
              </h3>
              <ul className="mt-2 list-disc space-y-1 pl-5">
                {b.dishes.map((d) => (
                  <li key={d.recipe_id}>
                    {d.recipe_name} — {formatNumber(d.qty)}{" "}
                    {vi.restaurant.servings.toLowerCase()}
                  </li>
                ))}
              </ul>
            </article>
          ))
        )}
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">{vi.restaurant.prepTitle}</h2>
        <p className="text-base text-muted-foreground">
          {vi.restaurant.prepHint}
        </p>
        {kitchen.prep.length === 0 ? (
          <p className="text-base text-muted-foreground">
            {vi.restaurant.noPrep}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {kitchen.prep.map((p) => (
              <li
                key={`${p.item_id}-${p.uom}`}
                className="flex items-center justify-between gap-2 rounded-xl border bg-card p-4 text-base"
              >
                <span>
                  <span className="block font-medium">{p.item_name}</span>
                  <span className="block font-mono text-sm text-muted-foreground">
                    {p.item_code} · {p.uom}
                  </span>
                </span>
                <span className="shrink-0 font-semibold tabular-nums">
                  {formatNumber(p.total_qty)}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
