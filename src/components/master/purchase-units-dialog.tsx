"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import type {
  ItemRow,
  UomRow,
  PurchaseUnitRow,
} from "@/features/master/queries";
import {
  savePurchaseUnitAction,
  deletePurchaseUnitAction,
} from "@/features/master/actions";

export function PurchaseUnitsDialog({
  propertyId,
  item,
  uoms,
  units,
  open,
  onClose,
  onRefresh,
}: {
  propertyId: string;
  item: ItemRow;
  uoms: UomRow[];
  units: PurchaseUnitRow[];
  open: boolean;
  onClose: () => void;
  onRefresh: () => void;
}) {
  const [uom, setUom] = useState(uoms[0]?.code || "");
  const [factorToStock, setFactorToStock] = useState("1");
  const [isDefault, setIsDefault] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  if (!open) return null;

  async function handleAdd(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);

    const res = await savePurchaseUnitAction({
      propertyId,
      itemId: item.id,
      uom,
      factorToStock: Number(factorToStock),
      isDefault,
    });

    setSaving(false);
    if (res.ok) {
      setFactorToStock("1");
      setIsDefault(false);
      onRefresh();
    } else {
      setError(res.error);
    }
  }

  async function handleDelete(unitId: string) {
    if (!confirm(vi.master.purchaseUnits.confirmDelete)) return;
    const res = await deletePurchaseUnitAction(propertyId, unitId);
    if (res.ok) {
      onRefresh();
    } else {
      setError(res.error);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
      <div className="w-full max-w-lg rounded-xl border bg-background p-6 shadow-lg">
        <div className="flex items-center justify-between border-b pb-3">
          <div>
            <h2 className="text-lg font-semibold">
              {vi.master.items.purchaseUnits}
            </h2>
            <p className="text-xs text-muted-foreground mt-0.5">
              {item.code} - {item.name} ({vi.master.purchaseUnits.stockUomLabel}{" "}
              <span className="font-semibold">{item.stock_uom}</span>)
            </p>
          </div>
          <Button variant="ghost" size="sm" onClick={onClose}>
            ✕
          </Button>
        </div>

        {error ? (
          <div className="mt-4 rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
            {error}
          </div>
        ) : null}

        <div className="mt-4">
          <table className="w-full text-sm border rounded-md">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.master.items.purchaseUom}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.master.items.factorToStock}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.master.items.isDefaultPurchaseUnit}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.common.actions}
                </th>
              </tr>
            </thead>
            <tbody>
              {units.length === 0 ? (
                <tr>
                  <td
                    colSpan={4}
                    className="p-4 text-center text-xs text-muted-foreground"
                  >
                    {vi.master.purchaseUnits.noCustomUnitPrefix}
                    {item.stock_uom}).
                  </td>
                </tr>
              ) : (
                units.map((u) => (
                  <tr key={u.id} className="border-t hover:bg-muted/40">
                    <td className="px-3 py-3 font-medium align-middle">
                      {u.uom}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      1 {u.uom} = {u.factor_to_stock} {item.stock_uom}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {u.is_default ? (
                        <span className="rounded bg-primary/10 px-1.5 py-0.5 text-xs font-semibold text-primary">
                          {vi.master.purchaseUnits.defaultLabel}
                        </span>
                      ) : (
                        "—"
                      )}
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <Button
                        variant="ghost"
                        size="sm"
                        className="text-destructive hover:bg-destructive/10"
                        onClick={() => handleDelete(u.id)}
                      >
                        {vi.master.purchaseUnits.delete}
                      </Button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        <form onSubmit={handleAdd} className="mt-4 border-t pt-4 space-y-3">
          <span className="text-xs font-semibold text-muted-foreground block">
            {vi.master.items.addPurchaseUnit}
          </span>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
            <div>
              <label
                className="text-xs text-muted-foreground"
                htmlFor="purchaseUom"
              >
                {vi.master.items.purchaseUom} *
              </label>
              <select
                id="purchaseUom"
                required
                value={uom}
                onChange={(e) => setUom(e.target.value)}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              >
                {uoms.map((unit) => (
                  <option key={unit.code} value={unit.code}>
                    {unit.code} ({unit.name_vi})
                  </option>
                ))}
              </select>
            </div>
            <div>
              <label className="text-xs text-muted-foreground" htmlFor="factor">
                {vi.master.items.factorToStock} *
              </label>
              <input
                id="factor"
                type="number"
                step="any"
                min="0.0001"
                required
                value={factorToStock}
                onChange={(e) => setFactorToStock(e.target.value)}
                placeholder={vi.master.purchaseUnits.factorExamplePlaceholder}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
          </div>
          <div className="flex items-center justify-between pt-1">
            <label className="flex items-center gap-2 cursor-pointer text-xs">
              <input
                type="checkbox"
                checked={isDefault}
                onChange={(e) => setIsDefault(e.target.checked)}
                className="rounded border"
              />
              {vi.master.items.isDefaultPurchaseUnit}
            </label>
            <Button type="submit" size="sm" disabled={saving}>
              {saving ? vi.common.loading : vi.common.save}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
