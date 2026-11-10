"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { saveBanquetAction } from "@/features/restaurant/actions";
import type { BanquetDetail } from "@/features/restaurant/queries";
import type { DepositStatus } from "@/features/restaurant/schemas";
import { vi } from "@/i18n/vi";

export type HallOption = {
  id: string;
  name: string;
  capacity: number | null;
  is_active: boolean;
};

type DishLineState = {
  key: number;
  recipeId: string;
  qty: string;
  unitPrice: string;
  note: string;
};

/**
 * Form tạo / sửa tiệc (M06, RPC `banquet_save`).
 * Đơn giá mặc định = giá bán của món (snapshot lúc lưu).
 * Sảnh: chọn trong danh mục (C11, Q170b) hoặc nhập tay; tên sảnh lưu
 * snapshot vào `hall`, `hall_id` link danh mục (nullable).
 */
export function BanquetForm({
  propertyId,
  banquet,
  recipes,
  halls,
}: {
  propertyId: string;
  banquet: BanquetDetail | null;
  recipes: Array<{
    id: string;
    code: string;
    name: string;
    sale_price: number | null;
  }>;
  halls: HallOption[];
}) {
  const router = useRouter();
  const [customerName, setCustomerName] = useState(
    banquet?.customer_name ?? "",
  );
  const [customerPhone, setCustomerPhone] = useState(
    banquet?.customer_phone ?? "",
  );
  const [eventDate, setEventDate] = useState(banquet?.event_date ?? "");
  const [startTime, setStartTime] = useState(banquet?.start_time ?? "10:00");
  const [endTime, setEndTime] = useState(banquet?.end_time ?? "13:00");
  const [hall, setHall] = useState(banquet?.hall ?? "");
  const [hallId, setHallId] = useState(banquet?.hall_id ?? "");
  const hallInList = halls.some((h) => h.id === hallId);
  const [depositStatus, setDepositStatus] = useState<DepositStatus>(
    banquet?.deposit_status ?? "unpaid",
  );
  const [tablesCount, setTablesCount] = useState(
    String(banquet?.tables_count ?? 0),
  );
  const [guestsCount, setGuestsCount] = useState(
    banquet ? String(banquet.guests_count) : "",
  );
  const [deposit, setDeposit] = useState(
    banquet ? String(banquet.deposit_amount) : "0",
  );
  const [notes, setNotes] = useState(banquet?.notes ?? "");
  const [dishes, setDishes] = useState<DishLineState[]>(
    (banquet?.dishes ?? []).map((d, i) => ({
      key: i,
      recipeId: d.recipe_id,
      qty: String(d.qty),
      unitPrice: String(d.unit_price),
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
      { key: nextKey, recipeId: "", qty: "", unitPrice: "", note: "" },
    ]);
    setNextKey((k) => k + 1);
  }

  function onRecipeChange(key: number, recipeId: string) {
    const recipe = recipes.find((r) => r.id === recipeId);
    updateDish(key, {
      recipeId,
      unitPrice:
        recipe?.sale_price !== null && recipe?.sale_price !== undefined
          ? String(recipe.sale_price)
          : "",
    });
  }

  const canSubmit =
    !pending &&
    customerName.trim() !== "" &&
    eventDate !== "" &&
    startTime !== "" &&
    endTime !== "" &&
    endTime > startTime &&
    (hallId !== "" || hall.trim() !== "") &&
    guestsCount !== "" &&
    Number(guestsCount) > 0 &&
    Number.isInteger(Number(guestsCount)) &&
    tablesCount !== "" &&
    Number(tablesCount) >= 0 &&
    deposit !== "" &&
    Number(deposit) >= 0 &&
    (depositStatus !== "paid" || Number(deposit) > 0) &&
    dishes.every(
      (d) =>
        d.recipeId !== "" &&
        d.qty !== "" &&
        Number(d.qty) > 0 &&
        d.unitPrice !== "" &&
        Number(d.unitPrice) >= 0,
    );

  async function handleSubmit() {
    setPending(true);
    setError(null);
    const res = await saveBanquetAction({
      propertyId,
      id: banquet?.id,
      customerName: customerName.trim(),
      customerPhone: customerPhone.trim() || undefined,
      eventDate,
      startTime,
      endTime,
      hall: hall.trim(),
      hallId: hallInList ? hallId : undefined,
      tablesCount: Number(tablesCount),
      guestsCount: Number(guestsCount),
      depositAmount: Number(deposit),
      depositStatus,
      notes: notes.trim() || undefined,
      dishes: dishes.map((d) => ({
        recipeId: d.recipeId,
        qty: Number(d.qty),
        unitPrice: Number(d.unitPrice),
        note: d.note.trim() || undefined,
      })),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(`/${propertyId}/restaurant/banquets/${res.data.id}`);
    router.refresh();
  }

  return (
    <div className="space-y-4">
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.customerName} *
          </span>
          <input
            value={customerName}
            onChange={(e) => setCustomerName(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.customerPhone}
          </span>
          <input
            value={customerPhone}
            onChange={(e) => setCustomerPhone(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.eventDate} *</span>
          <input
            type="date"
            value={eventDate}
            onChange={(e) => setEventDate(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.hall} *</span>
          <select
            value={hallInList ? hallId : ""}
            onChange={(e) => {
              const id = e.target.value;
              setHallId(id);
              const picked = halls.find((h) => h.id === id);
              if (picked) setHall(picked.name);
            }}
            className="h-9 w-full rounded-lg border border-border bg-background px-2"
          >
            <option value="">{vi.restaurant.hallOther}</option>
            {halls
              .filter((h) => h.is_active)
              .map((h) => (
                <option key={h.id} value={h.id}>
                  {h.name}
                  {h.capacity !== null ? ` (${h.capacity})` : ""}
                </option>
              ))}
          </select>
          {hallInList ? null : (
            <input
              value={hall}
              onChange={(e) => setHall(e.target.value)}
              placeholder="Sảnh A"
              className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
            />
          )}
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.startTime} *</span>
          <input
            type="time"
            value={startTime}
            onChange={(e) => setStartTime(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.endTime} *</span>
          <input
            type="time"
            value={endTime}
            onChange={(e) => setEndTime(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">{vi.restaurant.tablesCount}</span>
          <input
            type="number"
            min={0}
            step={1}
            value={tablesCount}
            onChange={(e) => setTablesCount(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.guestsCount} *
          </span>
          <input
            type="number"
            min={1}
            step={1}
            value={guestsCount}
            onChange={(e) => setGuestsCount(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.depositAmount}
          </span>
          <input
            type="number"
            min={0}
            step={1000}
            value={deposit}
            onChange={(e) => setDeposit(e.target.value)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2.5"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block font-medium">
            {vi.restaurant.depositStatus}
          </span>
          <select
            value={depositStatus}
            onChange={(e) => setDepositStatus(e.target.value as DepositStatus)}
            className="h-9 w-full rounded-lg border border-border bg-background px-2"
          >
            <option value="unpaid">{vi.restaurant.depositUnpaid}</option>
            <option value="paid">{vi.restaurant.depositPaid}</option>
          </select>
          {depositStatus === "paid" && Number(deposit) <= 0 ? (
            <span className="block text-xs text-destructive">
              {vi.restaurant.depositPaidRequiresAmount}
            </span>
          ) : null}
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
            {vi.restaurant.banquetDishes}
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
                className="grid gap-2 rounded-lg border p-3 sm:grid-cols-4"
              >
                <label className="space-y-1 text-sm sm:col-span-2">
                  <span className="block font-medium">
                    {vi.restaurant.dishName}
                  </span>
                  <select
                    value={d.recipeId}
                    onChange={(e) => onRecipeChange(d.key, e.target.value)}
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
                    {vi.restaurant.servings}
                  </span>
                  <input
                    type="number"
                    min={0}
                    step="any"
                    value={d.qty}
                    onChange={(e) => updateDish(d.key, { qty: e.target.value })}
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
                  />
                </label>
                <label className="space-y-1 text-sm">
                  <span className="block font-medium">
                    {vi.restaurant.unitPrice}
                  </span>
                  <input
                    type="number"
                    min={0}
                    step={1000}
                    value={d.unitPrice}
                    onChange={(e) =>
                      updateDish(d.key, { unitPrice: e.target.value })
                    }
                    className="h-9 w-full rounded-lg border border-border bg-background px-2"
                  />
                </label>
                <div className="flex items-end gap-2 sm:col-span-4">
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
