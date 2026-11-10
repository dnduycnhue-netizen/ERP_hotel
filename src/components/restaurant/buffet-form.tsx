"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { saveBuffetSessionAction } from "@/features/restaurant/actions";
import type { BuffetSessionDetail } from "@/features/restaurant/queries";
import type { BuffetMeal } from "@/features/restaurant/schemas";
import { vi } from "@/i18n/vi";

type DishLineState = {
  key: number;
  recipeId: string;
  plannedQty: string;
  note: string;
};

const MEAL_OPTIONS: Array<{ value: BuffetMeal; label: string }> = [
  { value: "breakfast", label: vi.restaurant.mealBreakfast },
  { value: "lunch", label: vi.restaurant.mealLunch },
  { value: "dinner", label: vi.restaurant.mealDinner },
];

/** Form tạo / sửa phiên buffet (M06, RPC `buffet_session_save`). */
export function BuffetForm({
  propertyId,
  session,
  recipes,
}: {
  propertyId: string;
  session: BuffetSessionDetail | null;
  recipes: Array<{ id: string; code: string; name: string }>;
}) {
  const router = useRouter();
  const [businessDate, setBusinessDate] = useState(
    session?.business_date ?? "",
  );
  const [meal, setMeal] = useState<BuffetMeal>(session?.meal ?? "breakfast");
  const [guestCount, setGuestCount] = useState(
    session ? String(session.guest_count) : "0",
  );
  const [pricePerGuest, setPricePerGuest] = useState(
    session?.price_per_guest !== null && session?.price_per_guest !== undefined
      ? String(session.price_per_guest)
      : "",
  );
  const [notes, setNotes] = useState(session?.notes ?? "");
  const [dishes, setDishes] = useState<DishLineState[]>(
    (session?.dishes ?? []).map((d, i) => ({
      key: i,
      recipeId: d.recipe_id,
      plannedQty: String(d.planned_qty),
      note: d.note ?? "",
    })),
  );
  const [nextKey, setNextKey] = useState(dishes.length);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function updateDish(key: number, patch: Partial<DishLineState>) {
    setDishes((prev) =>
      prev.map((d) => (d.key === key ? { ...d, ...patch } : d)),
    );
  }

  function removeDish(key: number) {
    setDishes((prev) => prev.filter((d) => d.key !== key));
  }

  function addDish() {
    setDishes((prev) => [
      ...prev,
      { key: nextKey, recipeId: "", plannedQty: "", note: "" },
    ]);
    setNextKey((k) => k + 1);
  }

  const canSubmit =
    !pending &&
    businessDate !== "" &&
    guestCount !== "" &&
    Number(guestCount) >= 0 &&
    Number.isInteger(Number(guestCount)) &&
    (pricePerGuest === "" || Number(pricePerGuest) >= 0) &&
    dishes.every(
      (d) =>
        d.recipeId !== "" && d.plannedQty !== "" && Number(d.plannedQty) > 0,
    );

  async function handleSubmit() {
    setPending(true);
    setError(null);
    const res = await saveBuffetSessionAction({
      propertyId,
      id: session?.id,
      businessDate,
      meal,
      guestCount: Number(guestCount),
      pricePerGuest: pricePerGuest === "" ? undefined : Number(pricePerGuest),
      notes: notes.trim() || undefined,
      dishes: dishes.map((d) => ({
        recipeId: d.recipeId,
        plannedQty: Number(d.plannedQty),
        note: d.note.trim() || undefined,
      })),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(`/${propertyId}/restaurant/buffet/${res.data.id}`);
    router.refresh();
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.sessionDate} *
          </span>
          <input
            type="date"
            value={businessDate}
            onChange={(e) => setBusinessDate(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.sessionMeal}</span>
          <select
            value={meal}
            onChange={(e) => setMeal(e.target.value as BuffetMeal)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          >
            {MEAL_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.guestCount}</span>
          <input
            type="number"
            min={0}
            step={1}
            value={guestCount}
            onChange={(e) => setGuestCount(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.pricePerGuest}
          </span>
          <input
            type="number"
            min={0}
            step={1000}
            value={pricePerGuest}
            onChange={(e) => setPricePerGuest(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
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
          <h2 className="text-sm font-semibold">
            {vi.restaurant.sessionDishes}
          </h2>
          <Button type="button" variant="outline" size="sm" onClick={addDish}>
            {vi.restaurant.addLine}
          </Button>
        </div>
        {dishes.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.restaurant.noLines}
          </p>
        ) : (
          <div className="space-y-2">
            {dishes.map((d) => (
              <div
                key={d.key}
                className="grid gap-2 rounded-lg border p-3 sm:grid-cols-3"
              >
                <label className="space-y-1 text-sm sm:col-span-2">
                  <span className="block font-medium">
                    {vi.restaurant.dishName}
                  </span>
                  <select
                    value={d.recipeId}
                    onChange={(e) =>
                      updateDish(d.key, { recipeId: e.target.value })
                    }
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
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
                  <span className="block font-medium">
                    {vi.restaurant.plannedQty}
                  </span>
                  <input
                    type="number"
                    min={0}
                    step="any"
                    value={d.plannedQty}
                    onChange={(e) =>
                      updateDish(d.key, { plannedQty: e.target.value })
                    }
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
                  />
                </label>
                <div className="flex items-end gap-2 sm:col-span-3">
                  <label className="grow space-y-1 text-sm">
                    <span className="block font-medium">
                      {vi.restaurant.lineNote}
                    </span>
                    <input
                      value={d.note}
                      onChange={(e) =>
                        updateDish(d.key, { note: e.target.value })
                      }
                      className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
                    />
                  </label>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    onClick={() => removeDish(d.key)}
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
