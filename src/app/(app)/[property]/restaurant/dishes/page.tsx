import Link from "next/link";
import { Search } from "lucide-react";
import { ErrorState } from "@/components/common/error-state";
import { ToggleDishButton } from "@/components/restaurant/restaurant-actions";
import { formatMoney } from "@/components/common/money-text";
import { getRestaurantPerms, listRecipes } from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

/** Danh sách món ăn (M06): lọc theo loại + tìm theo tên/mã. */
export default async function DishesPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ kind?: string; search?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const kind = sp.kind ?? "";
  const search = sp.search ?? "";

  const [res, perms] = await Promise.all([
    listRecipes(propertyId, {
      kind: kind || null,
      search: search || null,
    }),
    getRestaurantPerms(propertyId),
  ]);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  const dishes = res.data;

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold">{vi.restaurant.dishesTitle}</h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.restaurant.dishesHint}
          </p>
        </div>
        {perms.canManageDish ? (
          <Link
            href={`/${propertyId}/restaurant/dishes/new`}
            className="inline-flex h-9 items-center justify-center rounded-lg bg-primary px-3 text-sm font-medium text-primary-foreground"
          >
            {vi.restaurant.newDish}
          </Link>
        ) : null}
      </div>

      <form method="get" className="flex flex-wrap items-end gap-3">
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.dishKind}</span>
          <select
            name="kind"
            defaultValue={kind}
            className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="">{vi.restaurant.allKinds}</option>
            <option value="dish">{vi.restaurant.kindDish}</option>
            <option value="buffet_batch">
              {vi.restaurant.kindBuffetBatch}
            </option>
            <option value="set_menu">{vi.restaurant.kindSetMenu}</option>
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.searchDish}</span>
          <span className="relative block w-56">
            <Search
              className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
              aria-hidden
            />
            <input
              type="search"
              name="search"
              defaultValue={search}
              placeholder={vi.restaurant.searchDish}
              aria-label={vi.restaurant.searchDish}
              className="h-9 w-full rounded-md border bg-background pr-3 pl-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
            />
          </span>
        </label>
        <button
          type="submit"
          className="inline-flex h-9 items-center justify-center rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.common.search}
        </button>
      </form>

      {dishes.length === 0 ? (
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
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.dishKind}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.dishGroup}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.salePrice}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.foodcost}
                </th>
                <th className="px-3 py-2 font-medium">{vi.common.status}</th>
                {perms.canManageDish ? (
                  <th className="px-3 py-2 font-medium">{vi.common.actions}</th>
                ) : null}
              </tr>
            </thead>
            <tbody>
              {dishes.map((d) => (
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
                  <td className="px-3 py-2">
                    {d.kind === "dish"
                      ? vi.restaurant.kindDish
                      : d.kind === "buffet_batch"
                        ? vi.restaurant.kindBuffetBatch
                        : vi.restaurant.kindSetMenu}
                  </td>
                  <td className="px-3 py-2">{d.group_name ?? "—"}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {d.sale_price !== null ? formatMoney(d.sale_price) : "—"}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {d.foodcost !== null
                      ? formatMoney(d.foodcost)
                      : vi.restaurant.foodcostUnknown}
                  </td>
                  <td className="px-3 py-2">
                    {d.is_active
                      ? vi.restaurant.active
                      : vi.restaurant.inactive}
                  </td>
                  {perms.canManageDish ? (
                    <td className="px-3 py-2">
                      <ToggleDishButton
                        propertyId={propertyId}
                        recipeId={d.id}
                        isActive={d.is_active}
                      />
                    </td>
                  ) : null}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
