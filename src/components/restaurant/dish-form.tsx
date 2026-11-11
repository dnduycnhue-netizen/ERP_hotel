"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { saveRecipeAction } from "@/features/restaurant/actions";
import type { RecipeDetail } from "@/features/restaurant/queries";
import type { RecipeKind } from "@/features/restaurant/schemas";
import type { ItemRow, UomRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

type LineState = {
  key: number;
  type: "item" | "sub";
  itemId: string;
  subRecipeId: string;
  qty: string;
  uom: string;
  lossPct: string;
  note: string;
};

const KIND_OPTIONS: Array<{ value: RecipeKind; label: string }> = [
  { value: "dish", label: vi.restaurant.kindDish },
  { value: "buffet_batch", label: vi.restaurant.kindBuffetBatch },
  { value: "set_menu", label: vi.restaurant.kindSetMenu },
];

/**
 * Form tạo / sửa món ăn + công thức (M06, RPC `recipe_save`).
 * Lưu món tạo version công thức mới (version cũ tự hết hiệu lực).
 */
export function DishForm({
  propertyId,
  recipe,
  items,
  uoms,
  recipes,
}: {
  propertyId: string;
  recipe: RecipeDetail | null;
  items: ItemRow[];
  uoms: UomRow[];
  recipes: Array<{ id: string; code: string; name: string }>;
}) {
  const router = useRouter();
  const [code, setCode] = useState(recipe?.code ?? "");
  const [name, setName] = useState(recipe?.name ?? "");
  const [kind, setKind] = useState<RecipeKind>(recipe?.kind ?? "dish");
  const [groupName, setGroupName] = useState(recipe?.group_name ?? "");
  const [salePrice, setSalePrice] = useState(
    recipe?.sale_price !== null && recipe?.sale_price !== undefined
      ? String(recipe.sale_price)
      : "",
  );
  const [portions, setPortions] = useState(
    recipe?.portions_per_batch !== null &&
      recipe?.portions_per_batch !== undefined
      ? String(recipe.portions_per_batch)
      : "",
  );
  const [dietFlags, setDietFlags] = useState(
    (recipe?.diet_flags ?? []).join(", "),
  );
  const [isActive, setIsActive] = useState(recipe?.is_active ?? true);
  const [notes, setNotes] = useState(recipe?.notes ?? "");
  const [lines, setLines] = useState<LineState[]>(
    (recipe?.lines ?? []).map((l, i) => ({
      key: i,
      type: l.item_id ? "item" : "sub",
      itemId: l.item_id ?? "",
      subRecipeId: l.sub_recipe_id ?? "",
      qty: String(l.qty),
      uom: l.uom,
      lossPct: String(l.loss_pct),
      note: l.note ?? "",
    })),
  );
  const [nextKey, setNextKey] = useState(lines.length);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const subOptions = recipes.filter((r) => r.id !== recipe?.id);

  function updateLine(key: number, patch: Partial<LineState>) {
    setLines((prev) =>
      prev.map((l) => (l.key === key ? { ...l, ...patch } : l)),
    );
  }

  function removeLine(key: number) {
    setLines((prev) => prev.filter((l) => l.key !== key));
  }

  function addLine() {
    setLines((prev) => [
      ...prev,
      {
        key: nextKey,
        type: "item",
        itemId: "",
        subRecipeId: "",
        qty: "",
        uom: uoms[0]?.code ?? "kg",
        lossPct: "0",
        note: "",
      },
    ]);
    setNextKey((k) => k + 1);
  }

  const linesValid = lines.every((l) => {
    if (l.type === "item") return l.itemId !== "";
    return l.subRecipeId !== "";
  });
  const canSubmit =
    !pending &&
    code.trim() !== "" &&
    name.trim() !== "" &&
    lines.every(
      (l) =>
        l.qty !== "" &&
        Number(l.qty) > 0 &&
        l.uom !== "" &&
        l.lossPct !== "" &&
        Number(l.lossPct) >= 0 &&
        Number(l.lossPct) <= 100,
    ) &&
    linesValid &&
    (salePrice === "" || Number(salePrice) >= 0) &&
    (portions === "" || Number(portions) > 0);

  async function handleSubmit() {
    setPending(true);
    setError(null);
    const res = await saveRecipeAction({
      propertyId,
      id: recipe?.id,
      code: code.trim(),
      name: name.trim(),
      kind,
      groupName: groupName.trim() || undefined,
      salePrice: salePrice === "" ? undefined : Number(salePrice),
      portionsPerBatch: portions === "" ? undefined : Number(portions),
      dietFlags: dietFlags
        .split(",")
        .map((s) => s.trim())
        .filter((s) => s !== ""),
      isActive,
      notes: notes.trim() || undefined,
      lines: lines.map((l) => ({
        itemId: l.type === "item" ? l.itemId : null,
        subRecipeId: l.type === "sub" ? l.subRecipeId : null,
        qty: Number(l.qty),
        uom: l.uom,
        lossPct: Number(l.lossPct),
        note: l.note.trim() || undefined,
      })),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(`/${propertyId}/restaurant/dishes/${res.data.id}`);
    router.refresh();
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.dishCode} *</span>
          <input
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.dishName} *</span>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.dishKind}</span>
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value as RecipeKind)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          >
            {KIND_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.dishGroup}</span>
          <input
            value={groupName}
            onChange={(e) => setGroupName(e.target.value)}
            placeholder="hot / salad / dessert / bread…"
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.salePrice}</span>
          <input
            type="number"
            min={0}
            step={1000}
            value={salePrice}
            onChange={(e) => setSalePrice(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.portionsPerBatch}
          </span>
          <input
            type="number"
            min={0}
            step={1}
            value={portions}
            onChange={(e) => setPortions(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
          <span className="block text-xs text-muted-foreground">
            {vi.restaurant.portionsHint}
          </span>
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.dietFlags}</span>
          <input
            value={dietFlags}
            onChange={(e) => setDietFlags(e.target.value)}
            placeholder="lactose-free, vegetarian"
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="flex items-center gap-2 text-sm">
          <input
            type="checkbox"
            checked={isActive}
            onChange={(e) => setIsActive(e.target.checked)}
            className="size-4"
          />
          {vi.restaurant.active}
        </label>
      </div>
      <label className="block space-y-1 text-sm">
        <span className="block font-medium">{vi.restaurant.notes}</span>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          rows={2}
          className="w-full rounded-lg border border-border bg-background px-2.5 py-2"
        />
      </label>

      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-semibold">{vi.restaurant.recipeLines}</h2>
          <Button type="button" variant="outline" size="sm" onClick={addLine}>
            {vi.restaurant.addLine}
          </Button>
        </div>
        <p className="text-sm text-muted-foreground">
          {vi.restaurant.recipeLinesHint}
        </p>
        {lines.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noLines}
          </p>
        ) : (
          <div className="space-y-2">
            {lines.map((l) => (
              <div
                key={l.key}
                className="grid gap-2 rounded-lg border p-3 sm:grid-cols-6"
              >
                <label className="space-y-1 text-sm">
                  <span className="block font-medium">
                    {vi.restaurant.dishKind}
                  </span>
                  <select
                    value={l.type}
                    onChange={(e) =>
                      updateLine(l.key, {
                        type: e.target.value as "item" | "sub",
                      })
                    }
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
                  >
                    <option value="item">{vi.restaurant.lineItem}</option>
                    <option value="sub">{vi.restaurant.lineSubRecipe}</option>
                  </select>
                </label>
                {l.type === "item" ? (
                  <label className="space-y-1 text-sm sm:col-span-2">
                    <span className="block font-medium">
                      {vi.restaurant.lineItem}
                    </span>
                    <select
                      value={l.itemId}
                      onChange={(e) =>
                        updateLine(l.key, { itemId: e.target.value })
                      }
                      className="h-9 w-full rounded-lg border border-border bg-background px-2"
                    >
                      <option value="">{vi.restaurant.selectItem}</option>
                      {items.map((it) => (
                        <option key={it.id} value={it.id}>
                          {it.code} — {it.name} ({it.stock_uom})
                        </option>
                      ))}
                    </select>
                  </label>
                ) : (
                  <label className="space-y-1 text-sm sm:col-span-2">
                    <span className="block font-medium">
                      {vi.restaurant.lineSubRecipe}
                    </span>
                    <select
                      value={l.subRecipeId}
                      onChange={(e) =>
                        updateLine(l.key, { subRecipeId: e.target.value })
                      }
                      className="h-9 w-full rounded-lg border border-border bg-background px-2"
                    >
                      <option value="">{vi.restaurant.selectRecipe}</option>
                      {subOptions.map((r) => (
                        <option key={r.id} value={r.id}>
                          {r.code} — {r.name}
                        </option>
                      ))}
                    </select>
                  </label>
                )}
                <label className="space-y-1 text-sm">
                  <span className="block font-medium">
                    {vi.restaurant.lineQty}
                  </span>
                  <input
                    type="number"
                    min={0}
                    step="any"
                    value={l.qty}
                    onChange={(e) => updateLine(l.key, { qty: e.target.value })}
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="block font-medium">
                    {vi.restaurant.lineUom}
                  </span>
                  <select
                    value={l.uom}
                    onChange={(e) => updateLine(l.key, { uom: e.target.value })}
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
                  >
                    {uoms.map((u) => (
                      <option key={u.code} value={u.code}>
                        {u.code} — {u.name_vi}
                      </option>
                    ))}
                  </select>
                </label>
                <label className="space-y-1 text-sm">
                  <span className="block font-medium">
                    {vi.restaurant.lineLossPct}
                  </span>
                  <input
                    type="number"
                    min={0}
                    max={100}
                    step="any"
                    value={l.lossPct}
                    onChange={(e) =>
                      updateLine(l.key, { lossPct: e.target.value })
                    }
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
                  />
                </label>
                <div className="flex items-end gap-2 sm:col-span-6">
                  <label className="grow space-y-1 text-sm">
                    <span className="block font-medium">
                      {vi.restaurant.lineNote}
                    </span>
                    <input
                      value={l.note}
                      onChange={(e) =>
                        updateLine(l.key, { note: e.target.value })
                      }
                      className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
                    />
                  </label>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => removeLine(l.key)}
                  >
                    {vi.common.remove}
                  </Button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {error ? <p className="text-sm text-destructive">{error}</p> : null}
      <div className="flex gap-2">
        <Button type="button" disabled={!canSubmit} onClick={handleSubmit}>
          {vi.restaurant.save}
        </Button>
        <Button type="button" variant="outline" onClick={() => router.back()}>
          {vi.restaurant.cancel}
        </Button>
      </div>
    </div>
  );
}
