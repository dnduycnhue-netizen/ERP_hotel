import { ErrorState } from "@/components/common/error-state";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import {
  MobileSaleForm,
  MobileVoidSaleButton,
} from "@/components/restaurant/mobile-sale-form";
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

/**
 * Bán theo món — mobile (W4): ghi bán tay trong ca + tổng hôm nay +
 * dòng bán trong ngày. Ghi/hủy chỉ qua RPC `dish_sale_record` /
 * `dish_sale_void`; tổng hợp do RPC `restaurant_sales_summary` tính.
 */
export default async function MobileSalesPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;
  const today = vnToday();

  const [summaryRes, salesRes, recipesRes, perms] = await Promise.all([
    getSalesSummary(propertyId, today, today),
    listDishSales(propertyId, today, today),
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
        <p className="mt-1 text-base text-muted-foreground">
          {vi.restaurant.salesHint}
        </p>
      </div>

      {perms.canRecordSale ? (
        <MobileSaleForm
          propertyId={propertyId}
          businessDate={today}
          recipes={activeRecipes}
        />
      ) : null}

      <section className="space-y-2">
        <h2 className="text-base font-semibold">
          {vi.restaurant.summaryTitle}
        </h2>
        <div className="grid grid-cols-2 gap-3">
          <div className="rounded-xl border bg-card p-4">
            <p className="text-base text-muted-foreground">
              {vi.restaurant.totalQty}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatNumber(summary.totals.qty)}
            </p>
          </div>
          <div className="rounded-xl border bg-card p-4">
            <p className="text-base text-muted-foreground">
              {vi.restaurant.totalRevenue}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatMoney(summary.totals.revenue)}
            </p>
          </div>
          <div className="rounded-xl border bg-card p-4">
            <p className="text-base text-muted-foreground">
              {vi.restaurant.totalFoodcost}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatMoney(summary.totals.foodcost)}
            </p>
          </div>
          <div className="rounded-xl border bg-card p-4">
            <p className="text-base text-muted-foreground">
              {vi.restaurant.totalGrossProfit}
            </p>
            <p className="mt-1 text-lg font-semibold tabular-nums">
              {formatMoney(summary.totals.gross_profit)}
            </p>
          </div>
        </div>
        {summary.totals.has_unknown_cost ? (
          <p className="text-base text-amber-700">
            {vi.restaurant.unknownCostNote}
          </p>
        ) : null}
      </section>

      <section className="space-y-2">
        <h2 className="text-base font-semibold">
          {vi.restaurant.mobile.todaySales}
        </h2>
        {sales.length === 0 ? (
          <p className="text-base text-muted-foreground">
            {vi.restaurant.noSales}
          </p>
        ) : (
          <ul className="flex flex-col gap-2">
            {sales.map((s) => (
              <li
                key={s.id}
                className="rounded-xl border bg-card p-4 text-base"
              >
                <p className="flex flex-wrap justify-between gap-2">
                  <span className="font-semibold">
                    {s.recipe_name ?? vi.restaurant.sourceBuffet}
                  </span>
                  <span className="font-semibold tabular-nums">
                    {formatMoney(s.amount)}
                  </span>
                </p>
                <p className="mt-1 text-muted-foreground">
                  {sourceLabel(s.source)} · {formatNumber(s.qty)} ×{" "}
                  {formatMoney(s.unit_price)}
                </p>
                {s.voided_at ? (
                  <p className="mt-1 text-muted-foreground">
                    {vi.restaurant.voided}
                  </p>
                ) : null}
                {perms.canRecordSale &&
                s.source === "manual" &&
                !s.voided_at ? (
                  <div className="mt-3">
                    <MobileVoidSaleButton
                      propertyId={propertyId}
                      saleId={s.id}
                    />
                  </div>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
