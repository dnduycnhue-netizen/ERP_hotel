"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { ItemPicker } from "@/components/procurement/item-picker";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { vi } from "@/i18n/vi";
import { savePoDraftAction } from "@/features/procurement/actions";
import type { PoLineRow, PoRow } from "@/features/procurement/queries";
import type {
  CostCenterRow,
  ExpenseCategoryRow,
} from "@/features/master/queries";

type FormLine = {
  key: string;
  id?: string;
  isNew: boolean;
  itemId: string | null;
  itemCode: string | null;
  itemName: string | null;
  description: string;
  qty: string;
  uom: string;
  unitPrice: string;
  priceSource: PoLineRow["price_source"];
  ceilingPrice: number | null;
  overCeiling: boolean;
  expenseCategoryId: string;
  costCenterId: string;
};

let lineKeyCounter = 0;
function nextLineKey(): string {
  lineKeyCounter += 1;
  return `po-line-${Date.now()}-${lineKeyCounter}`;
}

function toFormLine(line: PoLineRow): FormLine {
  return {
    key: nextLineKey(),
    id: line.id,
    isNew: false,
    itemId: line.item_id,
    itemCode: line.item_code,
    itemName: line.item_name,
    description: line.description ?? "",
    qty: String(line.qty),
    uom: line.uom,
    unitPrice: String(line.unit_price ?? ""),
    priceSource: line.price_source,
    ceilingPrice: line.ceiling_price,
    overCeiling: line.over_ceiling,
    expenseCategoryId: line.expense_category_id ?? "",
    costCenterId: line.cost_center_id ?? "",
  };
}

function emptyLine(): FormLine {
  return {
    key: nextLineKey(),
    isNew: true,
    itemId: null,
    itemCode: null,
    itemName: null,
    description: "",
    qty: "1",
    uom: "",
    unitPrice: "",
    priceSource: "manual",
    ceilingPrice: null,
    overCeiling: false,
    expenseCategoryId: "",
    costCenterId: "",
  };
}

/**
 * Form sửa đơn mua nháp (T-021). Theo RPC `po_save_draft` (T-020): dòng
 * cũ không đổi được vật tư/ĐVT, chỉ sửa số lượng và đơn giá khi là dòng
 * giá tay; dòng mới tự giải quyết giá như `po_create_from_pr`. Lý do
 * vượt trần nhập tại đây — thiếu lý do thì `po_submit` bị chặn ở
 * server (`ERR_OVER_CEILING_NO_REASON`).
 */
export function PoForm({
  propertyId,
  po,
  lines,
  expenseCategories,
  costCenters,
}: {
  propertyId: string;
  po: PoRow;
  lines: PoLineRow[];
  expenseCategories: ExpenseCategoryRow[];
  costCenters: CostCenterRow[];
}) {
  const router = useRouter();
  const [expectedDate, setExpectedDate] = useState(po.expected_date ?? "");
  const [overCeilingReason, setOverCeilingReason] = useState(
    po.over_ceiling_reason ?? "",
  );
  const [formLines, setFormLines] = useState<FormLine[]>(() =>
    lines.map(toFormLine),
  );
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const hasOverCeiling = formLines.some((line) => line.overCeiling);

  function updateLine(key: string, patch: Partial<FormLine>) {
    setFormLines((prev) =>
      prev.map((line) => (line.key === key ? { ...line, ...patch } : line)),
    );
  }

  function removeLine(key: string) {
    setFormLines((prev) => {
      if (prev.length <= 1) return prev;
      return prev.filter((line) => line.key !== key);
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (formLines.length === 0) {
      setError(vi.procurement.form.needAtLeastOneLine);
      return;
    }
    for (const line of formLines) {
      const qty = Number(line.qty);
      if (!Number.isFinite(qty) || qty <= 0) {
        setError(vi.procurement.form.needAtLeastOneLine);
        return;
      }
      if (!line.uom.trim()) {
        setError(vi.procurement.form.needAtLeastOneLine);
        return;
      }
      if (line.isNew && !line.itemId && !line.description.trim()) {
        setError(vi.procurement.form.itemSearchHint);
        return;
      }
    }

    setSaving(true);
    const res = await savePoDraftAction({
      propertyId,
      id: po.id,
      expectedDate: expectedDate || null,
      overCeilingReason: overCeilingReason.trim()
        ? overCeilingReason.trim()
        : null,
      lines: formLines.map((line) => ({
        id: line.id,
        itemId: line.itemId,
        description: line.description.trim() ? line.description.trim() : null,
        qty: Number(line.qty),
        uom: line.uom.trim(),
        unitPrice: line.unitPrice === "" ? null : Number(line.unitPrice),
        expenseCategoryId: line.expenseCategoryId || null,
        costCenterId: line.costCenterId || null,
      })),
    });
    setSaving(false);
    if (res.ok) {
      router.push(`/${propertyId}/procurement/po/${po.id}`);
      router.refresh();
    } else {
      setError(res.error);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      {error ? (
        <div className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive">
          {error}
        </div>
      ) : null}

      <div className="rounded-lg border p-4 space-y-3">
        <h2 className="text-lg font-semibold">
          {vi.procurement.po.detailTitle} ·{" "}
          <span className="font-mono">{po.doc_no}</span>
        </h2>
        <p className="text-sm text-muted-foreground">
          {po.supplier_name} ·{" "}
          <MoneyText amount={po.total_amount} className="font-medium" />
        </p>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div>
            <label className="text-xs font-medium text-muted-foreground">
              {vi.procurement.po.expectedDate}
            </label>
            <input
              type="date"
              value={expectedDate}
              onChange={(e) => setExpectedDate(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground">
              {vi.procurement.po.overCeilingReason}
              {hasOverCeiling ? " *" : ""}
            </label>
            <input
              value={overCeilingReason}
              onChange={(e) => setOverCeilingReason(e.target.value)}
              placeholder={
                hasOverCeiling
                  ? vi.procurement.detail.overCeilingReasonMissing
                  : vi.procurement.po.overCeilingReason
              }
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
          </div>
        </div>
        {hasOverCeiling ? (
          <div className="rounded-md border border-amber-500/30 bg-amber-500/10 p-3 text-sm">
            <p className="font-medium">
              {vi.procurement.detail.overCeilingWarning}
            </p>
          </div>
        ) : null}
      </div>

      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="font-semibold text-sm">
            {vi.procurement.list.lines} ({formLines.length})
          </h3>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => setFormLines((prev) => [...prev, emptyLine()])}
          >
            + {vi.procurement.form.addLine}
          </Button>
        </div>

        {formLines.map((line, index) => (
          <div
            key={line.key}
            className="rounded-lg border p-4 space-y-3 bg-card"
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">
                {vi.procurement.form.lineNumber} {index + 1}
                {line.overCeiling ? (
                  <span className="ml-2 rounded-full bg-red-100 px-2 py-0.5 text-[11px] font-medium text-red-800">
                    {vi.procurement.detail.overCeiling}
                  </span>
                ) : null}
                {line.priceSource === "manual" ? (
                  <span className="ml-2 rounded-full bg-amber-100 px-2 py-0.5 text-[11px] font-medium text-amber-800">
                    {vi.procurement.detail.manualPrice}
                  </span>
                ) : null}
              </span>
              {formLines.length > 1 ? (
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  className="h-7 px-2 text-xs text-destructive hover:bg-destructive/10"
                  onClick={() => removeLine(line.key)}
                >
                  {vi.procurement.form.removeLine}
                </Button>
              ) : null}
            </div>

            {line.isNew ? (
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.form.item}
                </label>
                <div className="mt-1">
                  <ItemPicker
                    propertyId={propertyId}
                    picked={
                      line.itemId
                        ? {
                            id: line.itemId,
                            code: line.itemCode ?? "",
                            name: line.itemName ?? "",
                            stockUom: line.uom,
                          }
                        : null
                    }
                    onPick={(item) =>
                      updateLine(line.key, {
                        itemId: item.id,
                        itemCode: item.code,
                        itemName: item.name,
                        uom: line.uom || item.stockUom,
                      })
                    }
                    onClear={() =>
                      updateLine(line.key, {
                        itemId: null,
                        itemCode: null,
                        itemName: null,
                      })
                    }
                  />
                </div>
              </div>
            ) : (
              <p className="text-sm">
                {line.itemCode ? (
                  <>
                    <span className="font-mono text-xs font-bold">
                      {line.itemCode}
                    </span>{" "}
                    <span className="font-medium">{line.itemName}</span>
                  </>
                ) : (
                  line.description
                )}
                {line.ceilingPrice !== null ? (
                  <span className="text-muted-foreground">
                    {" · "}
                    {vi.procurement.detail.ceilingPrice}:{" "}
                    <MoneyText amount={line.ceilingPrice} />
                  </span>
                ) : null}
              </p>
            )}

            <div>
              <label className="text-xs font-medium text-muted-foreground">
                {vi.procurement.form.description}
              </label>
              <input
                value={line.description}
                onChange={(e) =>
                  updateLine(line.key, { description: e.target.value })
                }
                placeholder={vi.procurement.form.descriptionPlaceholder}
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>

            <div className="grid grid-cols-3 gap-3">
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.form.qty} *
                </label>
                <input
                  type="number"
                  min={0}
                  step="any"
                  required
                  value={line.qty}
                  onChange={(e) =>
                    updateLine(line.key, { qty: e.target.value })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.form.uom} *
                </label>
                <input
                  required
                  value={line.uom}
                  disabled={!line.isNew}
                  onChange={(e) =>
                    updateLine(line.key, { uom: e.target.value })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm disabled:opacity-60"
                />
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.detail.unitPrice}
                  {line.priceSource === "manual" ? " *" : ""}
                </label>
                <input
                  type="number"
                  min={0}
                  step="any"
                  value={line.unitPrice}
                  disabled={!line.isNew && line.priceSource !== "manual"}
                  onChange={(e) =>
                    updateLine(line.key, { unitPrice: e.target.value })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm disabled:opacity-60"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.form.expenseCategory}
                </label>
                <select
                  value={line.expenseCategoryId}
                  onChange={(e) =>
                    updateLine(line.key, {
                      expenseCategoryId: e.target.value,
                    })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">—</option>
                  {expenseCategories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.code} · {c.name}
                    </option>
                  ))}
                </select>
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.form.costCenter}
                </label>
                <select
                  value={line.costCenterId}
                  onChange={(e) =>
                    updateLine(line.key, { costCenterId: e.target.value })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">—</option>
                  {costCenters.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.code} · {c.name}
                    </option>
                  ))}
                </select>
              </div>
            </div>

            {!line.isNew && line.priceSource !== "manual" ? (
              <p className="text-xs text-muted-foreground">
                {vi.procurement.detail.priceSource}:{" "}
                {line.priceSource === "agreement"
                  ? vi.procurement.priceSource.agreement
                  : line.priceSource === "quote"
                    ? vi.procurement.priceSource.quote
                    : vi.procurement.priceSource.ceiling}{" "}
                · {formatNumber(line.qty)} ×{" "}
                <MoneyText amount={Number(line.unitPrice || 0)} />
              </p>
            ) : null}
          </div>
        ))}
      </div>

      <div className="flex justify-end gap-2">
        <Button type="button" variant="outline" onClick={() => router.back()}>
          {vi.common.cancel}
        </Button>
        <Button type="submit" disabled={saving}>
          {saving ? vi.common.loading : vi.procurement.form.saveDraft}
        </Button>
      </div>
    </form>
  );
}
