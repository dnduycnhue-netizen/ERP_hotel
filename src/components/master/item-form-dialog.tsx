"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import type { ItemRow, ItemGroupRow, UomRow } from "@/features/master/queries";
import { saveItemAction } from "@/features/master/actions";

export function ItemFormDialog({
  propertyId,
  item,
  groups,
  uoms,
  open,
  onClose,
  onSuccess,
}: {
  propertyId: string;
  item?: ItemRow | null;
  groups: ItemGroupRow[];
  uoms: UomRow[];
  open: boolean;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const [code, setCode] = useState(item?.code ?? "");
  const [name, setName] = useState(item?.name ?? "");
  const [nameEn, setNameEn] = useState(item?.name_en ?? "");
  const [groupId, setGroupId] = useState(
    item?.group_id ?? (groups[0]?.id || ""),
  );
  const [stockUom, setStockUom] = useState(
    item?.stock_uom ?? (uoms[0]?.code || "kg"),
  );
  const [recipeUom, setRecipeUom] = useState(item?.recipe_uom ?? "");
  const [stockToRecipe, setStockToRecipe] = useState(
    item?.stock_to_recipe ? String(item.stock_to_recipe) : "",
  );
  const [isKeyItem, setIsKeyItem] = useState(item?.is_key_item ?? false);
  const [abcClass, setAbcClass] = useState<string>(item?.abc_class ?? "");
  const [trackLot, setTrackLot] = useState(item?.track_lot ?? false);
  const [shelfLifeDays, setShelfLifeDays] = useState(
    item?.shelf_life_days ? String(item.shelf_life_days) : "",
  );
  const [storageCondition, setStorageCondition] = useState(
    item?.storage_condition ?? "",
  );
  const [vatRate, setVatRate] = useState(
    item?.vat_rate !== null && item?.vat_rate !== undefined
      ? String(item.vat_rate)
      : "8",
  );
  const [contractChannel, setContractChannel] = useState(
    item?.allowed_channels?.includes("contract") ?? true,
  );
  const [marketChannel, setMarketChannel] = useState(
    item?.allowed_channels?.includes("market") ?? true,
  );
  const [tareG, setTareG] = useState(item?.tare_g ? String(item.tare_g) : "");
  const [densityGMl, setDensityGMl] = useState(
    item?.density_g_ml ? String(item.density_g_ml) : "",
  );
  const [status, setStatus] = useState<"active" | "inactive">(
    (item?.status as "active" | "inactive") || "active",
  );

  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const allowedChannels: ("contract" | "market")[] = [];
    if (contractChannel) allowedChannels.push("contract");
    if (marketChannel) allowedChannels.push("market");

    if (allowedChannels.length === 0) {
      setError(vi.master.items.selectAtLeastOneChannel);
      setSaving(false);
      return;
    }

    const payload = {
      id: item?.id,
      propertyId,
      code,
      name,
      nameEn: nameEn.trim() || null,
      groupId,
      stockUom,
      recipeUom: recipeUom.trim() || null,
      stockToRecipe: stockToRecipe ? Number(stockToRecipe) : null,
      isKeyItem,
      abcClass: (abcClass as "A" | "B" | "C") || null,
      trackLot,
      shelfLifeDays: shelfLifeDays ? Number(shelfLifeDays) : null,
      storageCondition: storageCondition.trim() || null,
      vatRate: vatRate ? Number(vatRate) : null,
      allowedChannels,
      tareG: tareG ? Number(tareG) : null,
      densityGMl: densityGMl ? Number(densityGMl) : null,
      status,
    };

    const res = await saveItemAction(payload);
    setSaving(false);

    if (res.ok) {
      onSuccess();
    } else {
      setError(res.error);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="max-h-[90vh] w-full max-w-2xl overflow-y-auto rounded-xl border bg-background p-6 shadow-lg">
        <div className="flex items-center justify-between border-b pb-3">
          <h2 className="text-lg font-semibold">
            {item ? vi.master.items.editItem : vi.master.items.addItem}
          </h2>
          <Button variant="ghost" size="sm" onClick={onClose}>
            ✕
          </Button>
        </div>

        {error ? (
          <div className="mt-4 rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
            {error}
          </div>
        ) : null}

        <form onSubmit={handleSubmit} className="mt-4 space-y-4">
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="code"
              >
                {vi.master.items.code} *
              </label>
              <input
                id="code"
                type="text"
                required
                value={code}
                onChange={(e) => setCode(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="group"
              >
                {vi.master.items.group} *
              </label>
              <select
                id="group"
                required
                value={groupId}
                onChange={(e) => setGroupId(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              >
                {groups.map((g) => (
                  <option key={g.id} value={g.id}>
                    {g.code_prefix} - {g.name}
                  </option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label
              className="text-xs font-medium text-muted-foreground"
              htmlFor="name"
            >
              {vi.master.items.name} *
            </label>
            <input
              id="name"
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
          </div>

          <div>
            <label
              className="text-xs font-medium text-muted-foreground"
              htmlFor="nameEn"
            >
              {vi.master.items.nameEn}
            </label>
            <input
              id="nameEn"
              type="text"
              value={nameEn}
              onChange={(e) => setNameEn(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="stockUom"
              >
                {vi.master.items.stockUom} *
              </label>
              <select
                id="stockUom"
                required
                value={stockUom}
                onChange={(e) => setStockUom(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              >
                {uoms.map((u) => (
                  <option key={u.code} value={u.code}>
                    {u.code} ({u.name_vi})
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="recipeUom"
              >
                {vi.master.items.recipeUom}
              </label>
              <select
                id="recipeUom"
                value={recipeUom}
                onChange={(e) => setRecipeUom(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              >
                <option value="">{vi.master.items.noUseOption}</option>
                {uoms.map((u) => (
                  <option key={u.code} value={u.code}>
                    {u.code} ({u.name_vi})
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="stockToRecipe"
              >
                {vi.master.items.stockToRecipe}
              </label>
              <input
                id="stockToRecipe"
                type="number"
                step="any"
                min="0"
                value={stockToRecipe}
                onChange={(e) => setStockToRecipe(e.target.value)}
                placeholder={vi.master.items.stockToRecipeExample}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="abcClass"
              >
                {vi.master.items.abcClass}
              </label>
              <select
                id="abcClass"
                value={abcClass}
                onChange={(e) => setAbcClass(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              >
                <option value="">{vi.master.items.unclassifiedOption}</option>
                <option value="A">{vi.master.items.abcClassA}</option>
                <option value="B">{vi.master.items.abcClassB}</option>
                <option value="C">{vi.master.items.abcClassC}</option>
              </select>
            </div>
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="vatRate"
              >
                {vi.master.items.vatRate}
              </label>
              <input
                id="vatRate"
                type="number"
                min="0"
                max="100"
                step="0.1"
                value={vatRate}
                onChange={(e) => setVatRate(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="shelfLifeDays"
              >
                {vi.master.items.shelfLifeDays}
              </label>
              <input
                id="shelfLifeDays"
                type="number"
                min="1"
                value={shelfLifeDays}
                onChange={(e) => setShelfLifeDays(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="storageCondition"
              >
                {vi.master.items.storageCondition}
              </label>
              <input
                id="storageCondition"
                type="text"
                value={storageCondition}
                onChange={(e) => setStorageCondition(e.target.value)}
                placeholder={vi.master.items.storageExamplePlaceholder}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="tareG"
              >
                {vi.master.items.tareG}
              </label>
              <input
                id="tareG"
                type="number"
                step="any"
                min="0"
                value={tareG}
                onChange={(e) => setTareG(e.target.value)}
                placeholder={vi.master.items.densityExamplePlaceholder}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
            <div>
              <label
                className="text-xs font-medium text-muted-foreground"
                htmlFor="densityGMl"
              >
                {vi.master.items.densityGMl}
              </label>
              <input
                id="densityGMl"
                type="number"
                step="any"
                min="0"
                value={densityGMl}
                onChange={(e) => setDensityGMl(e.target.value)}
                placeholder={vi.master.items.densityExample}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
          </div>

          <div className="rounded-lg border p-3 space-y-2">
            <span className="text-xs font-medium text-muted-foreground">
              {vi.master.items.allowedChannels}
            </span>
            <div className="flex gap-6 text-sm">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={contractChannel}
                  onChange={(e) => setContractChannel(e.target.checked)}
                  className="rounded border"
                />
                {vi.master.items.channelContract}
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={marketChannel}
                  onChange={(e) => setMarketChannel(e.target.checked)}
                  className="rounded border"
                />
                {vi.master.items.channelMarket}
              </label>
            </div>
          </div>

          <div className="flex flex-wrap gap-6 pt-1">
            <label className="flex items-center gap-2 cursor-pointer text-sm">
              <input
                type="checkbox"
                checked={isKeyItem}
                onChange={(e) => setIsKeyItem(e.target.checked)}
                className="rounded border"
              />
              <span className="font-medium text-primary">
                {vi.master.items.isKeyItem}
              </span>
            </label>
            <label className="flex items-center gap-2 cursor-pointer text-sm">
              <input
                type="checkbox"
                checked={trackLot}
                onChange={(e) => setTrackLot(e.target.checked)}
                className="rounded border"
              />
              {vi.master.items.trackLot}
            </label>
            <label className="flex items-center gap-2 cursor-pointer text-sm">
              <span className="text-muted-foreground">
                {vi.master.items.status}:
              </span>
              <select
                value={status}
                onChange={(e) =>
                  setStatus(e.target.value as "active" | "inactive")
                }
                className="h-8 rounded-md border bg-background px-2 text-xs"
              >
                <option value="active">{vi.master.items.statusActive}</option>
                <option value="inactive">
                  {vi.master.items.statusInactive}
                </option>
              </select>
            </label>
          </div>

          <div className="flex items-center justify-end gap-3 border-t pt-4">
            <Button type="button" variant="outline" onClick={onClose}>
              {vi.common.cancel}
            </Button>
            <Button type="submit" disabled={saving}>
              {saving ? vi.common.loading : vi.common.save}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
