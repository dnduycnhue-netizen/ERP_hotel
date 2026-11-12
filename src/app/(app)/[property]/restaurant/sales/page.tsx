import { ErrorState } from "@/components/common/error-state";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { SaleForm } from "@/components/restaurant/sale-form";
import { VoidSaleButton } from "@/components/restaurant/restaurant-actions";
import {
  getRestaurantPerms,
  getSalesSummary,
  listDishSales,
  listRecipes,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

function vnToday(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

function sourceLabel(source: string): string {
  if (source === "buffet") return vi.restaurant.sourceBuffet;
  if (source === "banquet") return vi.restaurant.sourceBanquet;
  return vi.restaurant.sourceManual;
}

/** Bán hàng theo món (M06): ghi bán tay + tổng hợp kỳ + dòng bán. */
export default async function SalesPage({
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

  const [summaryRes, salesRes, recipesRes, perms] = await Promise.all([
    getSalesSummary(propertyId, from, to),
    listDishSales(propertyId, from, to),
    listRecipes(propertyId),
    getRestaurantPerms(propertyId),
  ]);

  if (!summaryRes.ok) {
    return <ErrorState description={summaryRes.error} />;
  }
  if (!salesRes.ok) {
    return <ErrorState description={salesRes.error} />;
  }
  const summary = summaryRes.data;
  const sales = salesRes.data;
  const activeRecipes = (recipesRes.ok ? recipesRes.data : [])
    .filter((r) => r.is_active)
    .map((r) => ({
      id: r.id,
      code: r.code,
      name: r.name,
      sale_price: r.sale_price,
    }));

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.salesTitle}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.restaurant.salesHint}
        </p>
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

      {perms.canRecordSale ? (
        <SaleForm
          propertyId={propertyId}
          defaultDate={today}
          recipes={activeRecipes}
        />
      ) : null}

      <section className="space-y-2">
        <h2 className="text-base font-semibold">
          {vi.restaurant.summaryTitle}
        </h2>
        <div className="grid gap-3 sm:grid-cols-4">
          <div className="rounded-lg border p-3">
            <p className="text-sm text-muted-foreground">
              {vi.restaurant.totalQty}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatNumber(summary.totals.qty)}
            </p>
          </div>
          <div className="rounded-lg border p-3">
            <p className="text-sm text-muted-foreground">
              {vi.restaurant.totalRevenue}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatMoney(summary.totals.revenue)}
            </p>
          </div>
          <div className="rounded-lg border p-3">
            <p className="text-sm text-muted-foreground">
              {vi.restaurant.totalFoodcost}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatMoney(summary.totals.foodcost)}
            </p>
          </div>
          <div className="rounded-lg border p-3">
            <p className="text-sm text-muted-foreground">
              {vi.restaurant.totalGrossProfit}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatMoney(summary.totals.gross_profit)}
            </p>
          </div>
        </div>
        {summary.totals.has_unknown_cost ? (
          <p className="text-sm text-amber-700">
            {vi.restaurant.unknownCostNote}
          </p>
        ) : null}
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">{vi.restaurant.byDish}</h2>
        {summary.by_dish.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noSales}
          </p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-left">
                  <th className="px-3 py-2 font-medium">
                    {vi.restaurant.dishName}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.saleQty}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.totalRevenue}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.totalFoodcost}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.totalGrossProfit}
                  </th>
                </tr>
              </thead>
              <tbody>
                {summary.by_dish.map((d) => (
                  <tr
                    key={d.recipe_id ?? "buffet"}
                    className="border-b last:border-0"
                  >
                    <td className="px-3 py-2">{d.recipe_name}</td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {formatNumber(d.qty)}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {formatMoney(d.revenue)}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {d.foodcost !== null ? formatMoney(d.foodcost) : "—"}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {d.gross_profit !== null
                        ? formatMoney(d.gross_profit)
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
        <h2 className="text-base font-semibold">{vi.restaurant.salesTitle}</h2>
        {sales.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noSales}
          </p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-left">
                  <th className="px-3 py-2 font-medium">
                    {vi.restaurant.businessDate}
                  </th>
                  <th className="px-3 py-2 font-medium">
                    {vi.restaurant.dishName}
                  </th>
                  <th className="px-3 py-2 font-medium">
                    {vi.restaurant.saleSource}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.saleQty}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.unitPrice}
                  </th>
                  <th className="px-3 py-2 text-right font-medium">
                    {vi.restaurant.saleAmount}
                  </th>
                  <th className="px-3 py-2 font-medium">{vi.common.status}</th>
                  {perms.canRecordSale ? (
                    <th className="px-3 py-2 font-medium">
                      {vi.common.actions}
                    </th>
                  ) : null}
                </tr>
              </thead>
              <tbody>
                {sales.map((s) => (
                  <tr key={s.id} className="border-b last:border-0">
                    <td className="px-3 py-2">{s.business_date}</td>
                    <td className="px-3 py-2">
                      {s.recipe_name ?? vi.restaurant.sourceBuffet}
                    </td>
                    <td className="px-3 py-2">{sourceLabel(s.source)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {formatNumber(s.qty)}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {formatMoney(s.unit_price)}
                    </td>
                    <td className="px-3 py-2 text-right tabular-nums">
                      {formatMoney(s.amount)}
                    </td>
                    <td className="px-3 py-2">
                      {s.voided_at ? (
                        <DocStatusBadge status="cancelled" />
                      ) : (
                        <span className="text-muted-foreground">—</span>
                      )}
                    </td>
                    {perms.canRecordSale ? (
                      <td className="px-3 py-2">
                        {s.source === "manual" && !s.voided_at ? (
                          <VoidSaleButton
                            propertyId={propertyId}
                            saleId={s.id}
                          />
                        ) : null}
                      </td>
                    ) : null}
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
