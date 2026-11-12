import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { formatMoney, formatNumber } from "@/components/common/money-text";
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

/** Màn bếp (M06): thực đơn hôm nay + buffet + tiệc + NVL chuẩn bị. */
export default async function KitchenPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ date?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const date = sp.date ?? vnToday();

  const res = await getKitchenToday(propertyId, date);
  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  const kitchen = res.data;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold">
            {vi.restaurant.kitchenTitle}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.restaurant.kitchenHint}
          </p>
        </div>
        <form method="get" className="flex items-end gap-2">
          <label className="space-y-1 text-sm">
            <span className="block font-medium">{vi.common.today}</span>
            <input
              type="date"
              name="date"
              defaultValue={date}
              className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
            />
          </label>
          <button
            type="submit"
            className="inline-flex h-9 items-center justify-center rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            {vi.common.search}
          </button>
        </form>
      </div>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">{vi.restaurant.todayMenu}</h2>
        {kitchen.dishes.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noDishes}
          </p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-left">
                  <th className="px-3 py-2 font-medium">
                    {vi.restaurant.dishCode}
                  </th>
                  <th className="px-3 py-2 font-medium">
                    {vi.restaurant.dishName}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.salePrice}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.foodcost}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.portionsPerBatch}
                  </th>
                </tr>
              </thead>
              <tbody>
                {kitchen.dishes.map((d) => (
                  <tr key={d.id} className="border-b last:border-0">
                    <td className="px-3 py-2 font-mono text-xs">{d.code}</td>
                    <td className="px-3 py-2">
                      <Link
                        href={`/${propertyId}/restaurant/dishes/${d.id}`}
                        className="font-medium underline-offset-2 hover:underline"
                      >
                        {d.name}
                      </Link>
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {d.sale_price !== null ? formatMoney(d.sale_price) : "—"}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {d.foodcost !== null
                        ? formatMoney(d.foodcost)
                        : vi.restaurant.foodcostUnknown}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {d.portions_per_batch !== null
                        ? formatNumber(d.portions_per_batch)
                        : "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">{vi.restaurant.todayBuffet}</h2>
        {kitchen.buffet_sessions.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noSessions}
          </p>
        ) : (
          kitchen.buffet_sessions.map((s) => (
            <article key={s.id} className="rounded-lg border p-4">
              <h3 className="font-semibold">
                {mealLabel(s.meal)} · {s.guest_count}{" "}
                {vi.restaurant.guestCount.toLowerCase()}
              </h3>
              <ul className="mt-2 list-disc space-y-1 pl-5 text-sm">
                {s.dishes.map((d) => (
                  <li key={d.recipe_id}>
                    {d.recipe_name} — {formatNumber(d.planned_qty)}{" "}
                    {vi.restaurant.servings.toLowerCase()}
                    {d.batches !== null
                      ? ` · ${formatNumber(d.batches)} ${vi.restaurant.batchUnit}`
                      : ""}
                  </li>
                ))}
              </ul>
              <Link
                href={`/${propertyId}/restaurant/buffet/${s.id}`}
                className="mt-2 inline-block text-sm underline-offset-2 hover:underline"
              >
                {vi.restaurant.sessionDishes} →
              </Link>
            </article>
          ))
        )}
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">
          {vi.restaurant.todayBanquets}
        </h2>
        {kitchen.banquets.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noBanquets}
          </p>
        ) : (
          kitchen.banquets.map((b) => (
            <article key={b.id} className="rounded-lg border p-4">
              <h3 className="font-semibold">
                {b.doc_no} — {b.customer_name} · {b.hall} · {b.start_time}–
                {b.end_time}
              </h3>
              <ul className="mt-2 list-disc space-y-1 pl-5 text-sm">
                {b.dishes.map((d) => (
                  <li key={d.recipe_id}>
                    {d.recipe_name} — {formatNumber(d.qty)}{" "}
                    {vi.restaurant.servings.toLowerCase()}
                    {d.batches !== null
                      ? ` · ${formatNumber(d.batches)} ${vi.restaurant.batchUnit}`
                      : ""}
                  </li>
                ))}
              </ul>
              <Link
                href={`/${propertyId}/restaurant/banquets/${b.id}`}
                className="mt-2 inline-block text-sm underline-offset-2 hover:underline"
              >
                {vi.restaurant.banquetDishes} →
              </Link>
            </article>
          ))
        )}
      </section>

      <section className="space-y-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <h2 className="text-base font-semibold">{vi.restaurant.prepTitle}</h2>
          <Link
            href={`/${propertyId}/inventory/requisitions`}
            className="inline-flex h-9 items-center justify-center rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground"
          >
            {vi.restaurant.goToRequisitions}
          </Link>
        </div>
        <p className="text-sm text-muted-foreground">
          {vi.restaurant.prepHint}
        </p>
        {kitchen.prep.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noPrep}
          </p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-left">
                  <th className="px-3 py-2 font-medium">
                    {vi.reports.columns.itemCode}
                  </th>
                  <th className="px-3 py-2 font-medium">
                    {vi.reports.columns.itemName}
                  </th>
                  <th className="px-3 py-2 font-medium">
                    {vi.restaurant.dishUom}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.reports.columns.qty}
                  </th>
                </tr>
              </thead>
              <tbody>
                {kitchen.prep.map((p) => (
                  <tr
                    key={`${p.item_id}-${p.uom}`}
                    className="border-b last:border-0"
                  >
                    <td className="px-3 py-2 font-mono text-xs">
                      {p.item_code}
                    </td>
                    <td className="px-3 py-2">{p.item_name}</td>
                    <td className="px-3 py-2">{p.uom}</td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {formatNumber(p.total_qty)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
