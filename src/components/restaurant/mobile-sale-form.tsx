"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import {
  recordDishSaleAction,
  voidDishSaleAction,
} from "@/features/restaurant/actions";
import { vi } from "@/i18n/vi";

export type MobileRecipeOption = {
  id: string;
  code: string;
  name: string;
  sale_price: number | null;
};

/**
 * Ghi bán tay theo món — mobile (W4). Ghi qua RPC `dish_sale_record`
 * (đã kiểm quyền `restaurant.sale.record` + chặn ngày tương lai ở
 * server); thành tiền chỉ hiện tạm tính, số thật do Postgres tính.
 */
export function MobileSaleForm({
  propertyId,
  businessDate,
  recipes,
}: {
  propertyId: string;
  businessDate: string;
  recipes: MobileRecipeOption[];
}) {
  const router = useRouter();
  const [recipeId, setRecipeId] = useState("");
  const [qty, setQty] = useState("");
  const [unitPrice, setUnitPrice] = useState("");
  const [pending, setPending] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const selected = recipes.find((r) => r.id === recipeId) ?? null;
  const preview = useMemo(() => {
    const q = Number(qty);
    const p = Number(unitPrice);
    if (!Number.isFinite(q) || !Number.isFinite(p) || q <= 0 || p < 0) {
      return null;
    }
    return q * p;
  }, [qty, unitPrice]);

  const canSubmit =
    !pending &&
    recipeId !== "" &&
    qty !== "" &&
    Number(qty) > 0 &&
    unitPrice !== "" &&
    Number(unitPrice) >= 0;

  function handleRecipeChange(value: string) {
    setRecipeId(value);
    const recipe = recipes.find((r) => r.id === value) ?? null;
    setUnitPrice(
      recipe?.sale_price !== null && recipe?.sale_price !== undefined
        ? String(recipe.sale_price)
        : "",
    );
  }

  async function handleSubmit() {
    setPending(true);
    setMessage(null);
    setError(null);
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
    setMessage(
      short > 0
        ? `${vi.restaurant.saleRecorded} ${vi.restaurant.saleStockWarning.replace("{count}", String(short))}`
        : vi.restaurant.saleRecorded,
    );
    setQty("");
    router.refresh();
  }

  return (
    <section className="space-y-3 rounded-xl border bg-card p-4">
      <h2 className="text-base font-semibold">{vi.restaurant.recordSale}</h2>
      {message ? (
        <p className="rounded-md border border-green-200 bg-green-50 px-3 py-2 text-base text-green-800">
          {message}
        </p>
      ) : null}
      {error ? (
        <p className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-base text-red-800">
          {error}
        </p>
      ) : null}
      <label className="block text-base">
        {vi.restaurant.mobile.selectDish}
        <select
          value={recipeId}
          onChange={(e) => handleRecipeChange(e.target.value)}
          className="mt-1 min-h-11 w-full rounded-md border bg-background px-3 py-2 text-base"
        >
          <option value="">{vi.restaurant.mobile.selectDish}</option>
          {recipes.map((r) => (
            <option key={r.id} value={r.id}>
              {r.name} ({r.code})
            </option>
          ))}
        </select>
      </label>
      <div className="grid grid-cols-2 gap-3">
        <label className="block text-base">
          {vi.restaurant.saleQty}
          <input
            type="number"
            inputMode="decimal"
            min="0"
            step="0.01"
            value={qty}
            onChange={(e) => setQty(e.target.value)}
            className="mt-1 min-h-11 w-full rounded-md border bg-background px-3 py-2 text-base"
          />
        </label>
        <label className="block text-base">
          {vi.restaurant.unitPrice}
          <input
            type="number"
            inputMode="decimal"
            min="0"
            step="1000"
            value={unitPrice}
            onChange={(e) => setUnitPrice(e.target.value)}
            className="mt-1 min-h-11 w-full rounded-md border bg-background px-3 py-2 text-base"
          />
        </label>
      </div>
      <p className="flex items-center justify-between text-base">
        <span className="text-muted-foreground">
          {vi.restaurant.mobile.amountPreview}
        </span>
        <span className="font-semibold tabular-nums">
          {preview !== null ? formatMoney(preview) : "—"}
        </span>
      </p>
      {selected?.sale_price !== null && selected?.sale_price !== undefined ? (
        <p className="text-base text-muted-foreground">
          {vi.restaurant.salePrice}: {formatNumber(selected.sale_price)}
        </p>
      ) : null}
      <Button
        type="button"
        size="lg"
        className="min-h-11 w-full text-base"
        disabled={!canSubmit}
        onClick={handleSubmit}
      >
        {vi.restaurant.recordSale}
      </Button>
    </section>
  );
}

/** Hủy dòng bán tay ghi sai — mobile (giữ dòng trong sổ, chỉ đánh dấu hủy). */
export function MobileVoidSaleButton({
  propertyId,
  saleId,
}: {
  propertyId: string;
  saleId: string;
}) {
  const router = useRouter();
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleClick() {
    if (!window.confirm(vi.restaurant.saleVoidConfirm)) return;
    setPending(true);
    setError(null);
    const res = await voidDishSaleAction({ propertyId, saleId });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.refresh();
  }

  return (
    <span className="inline-flex flex-col items-start gap-1">
      <Button
        type="button"
        variant="outline"
        className="min-h-11 text-base"
        disabled={pending}
        onClick={handleClick}
      >
        {vi.restaurant.voidSale}
      </Button>
      {error ? (
        <span className="text-base text-destructive">{error}</span>
      ) : null}
    </span>
  );
}
