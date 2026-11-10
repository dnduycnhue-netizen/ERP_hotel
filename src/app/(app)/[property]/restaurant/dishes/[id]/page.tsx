import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { DishForm } from "@/components/restaurant/dish-form";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import { getRecipe, listRecipes } from "@/features/restaurant/queries";
import { listItems, listUoms } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/** Chi tiết + sửa món ăn (M06). */
export default async function DishDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: recipeId } = await params;

  const [res, recipesRes, itemsRes, uoms] = await Promise.all([
    getRecipe(propertyId, recipeId),
    listRecipes(propertyId),
    listItems({ propertyId, pageSize: 200 }),
    listUoms(),
  ]);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  if (!res.data) {
    notFound();
  }
  const recipe = res.data;

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">
          {recipe.code} — {recipe.name}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.restaurant.foodcost}:{" "}
          {recipe.foodcost !== null
            ? formatMoney(recipe.foodcost)
            : vi.restaurant.foodcostUnknown}
          {recipe.version_no !== null ? ` · version ${recipe.version_no}` : ""}
          {recipe.portions_per_batch !== null
            ? ` · ${recipe.portions_per_batch} ${vi.restaurant.portionsPerBatch}`
            : ""}
        </p>
      </div>

      {recipe.lines.length > 0 ? (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-left">
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.lineItem}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.lineQty}
                </th>
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.lineUom}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.lineLossPct}
                </th>
              </tr>
            </thead>
            <tbody>
              {recipe.lines.map((l) => (
                <tr key={l.id} className="border-b last:border-0">
                  <td className="px-3 py-2">
                    {l.item_name ?? l.sub_recipe_name ?? "—"}
                    <span className="ml-2 font-mono text-xs text-muted-foreground">
                      {l.item_code ?? l.sub_recipe_code ?? ""}
                    </span>
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {formatNumber(l.qty)}
                  </td>
                  <td className="px-3 py-2">{l.uom}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {formatNumber(l.loss_pct)}%
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : null}

      <DishForm
        propertyId={propertyId}
        recipe={recipe}
        items={itemsRes.items}
        uoms={uoms}
        recipes={(recipesRes.ok ? recipesRes.data : []).map((r) => ({
          id: r.id,
          code: r.code,
          name: r.name,
        }))}
      />
    </div>
  );
}
