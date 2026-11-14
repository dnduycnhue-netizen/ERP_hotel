"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { recordDishSaleAction } from "@/features/restaurant/actions";
import { vi } from "@/i18n/vi";

/** Form ghi bán tay (M06, RPC `dish_sale_record`). */
export function SaleForm({
  propertyId,
  defaultDate,
  recipes,
}: {
  propertyId: string;
  defaultDate: string;
  recipes: Array<{
    id: string;
    code: string;
    name: string;
    sale_price: number | null;
  }>;
}) {
  const router = useRouter();
  const [businessDate, setBusinessDate] = useState(defaultDate);
  const [recipeId, setRecipeId] = useState("");
  const [qty, setQty] = useState("");
  const [unitPrice, setUnitPrice] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [done, setDone] = useState<string | null>(null);

  function onRecipeChange(id: string) {
    setRecipeId(id);
    const recipe = recipes.find((r) => r.id === id);
    setUnitPrice(
      recipe?.sale_price !== null && recipe?.sale_price !== undefined
        ? String(recipe.sale_price)
        : "",
    );
  }

  const canSubmit =
    !pending &&
    businessDate !== "" &&
    recipeId !== "" &&
    qty !== "" &&
    Number(qty) > 0 &&
    unitPrice !== "" &&
    Number(unitPrice) >= 0;

  async function handleSubmit() {
    setPending(true);
    setError(null);
    setDone(null);
    const res = await recordDishSaleAction({
      propertyId,
      businessDate,
      recipeId,
      qty: Number(qty),
      unitPrice: Number(unitPrice),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    const short = res.data.stock_short_lines ?? 0;
    setDone(
      short > 0
        ? `${vi.restaurant.saleRecorded} ${vi.restaurant.saleStockWarning.replace("{count}", String(short))}`
        : vi.restaurant.saleRecorded,
    );
    setQty("");
    router.refresh();
  }

  return (
    <div className="space-y-2 rounded-lg border p-4">
      <h2 className="text-sm font-semibold">{vi.restaurant.recordSale}</h2>
      <div className="flex flex-wrap items-end gap-3">
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.businessDate}
          </span>
          <input
            type="date"
            value={businessDate}
            onChange={(e) => setBusinessDate(e.target.value)}
            className="h-9 rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.dishName}</span>
          <select
            value={recipeId}
            onChange={(e) => onRecipeChange(e.target.value)}
            className="h-9 min-w-56 rounded-lg border border-border bg-background px-2"
          >
            <option value="">{vi.restaurant.selectRecipe}</option>
            {recipes.map((r) => (
              <option key={r.id} value={r.id}>
                {r.code} — {r.name}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.saleQty}</span>
          <input
            type="number"
            min={0}
            step="any"
            value={qty}
            onChange={(e) => setQty(e.target.value)}
            className="h-9 w-28 rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.unitPrice}</span>
          <input
            type="number"
            min={0}
            step={1000}
            value={unitPrice}
            onChange={(e) => setUnitPrice(e.target.value)}
            className="h-9 w-36 rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <Button type="button" disabled={!canSubmit} onClick={handleSubmit}>
          {vi.restaurant.recordSale}
        </Button>
      </div>
      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      {done ? <p className="text-sm text-green-700">{done}</p> : null}
    </div>
  );
}
