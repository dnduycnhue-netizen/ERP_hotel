"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { ItemPicker } from "@/components/procurement/item-picker";
import { vi } from "@/i18n/vi";
import { createMarketOrderAction } from "@/features/procurement/actions";
import type {
  CostCenterRow,
  ExpenseCategoryRow,
} from "@/features/master/queries";

type FormLine = {
  key: string;
  itemId: string | null;
  itemCode: string | null;
  itemName: string | null;
  description: string;
  qty: string;
  uom: string;
  unitPrice: string;
  expenseCategoryId: string;
  costCenterId: string;
};

let lineKeyCounter = 0;
function nextLineKey(): string {
  lineKeyCounter += 1;
  return `line-${Date.now()}-${lineKeyCounter}`;
}

function emptyLine(): FormLine {
  return {
    key: nextLineKey(),
    itemId: null,
    itemCode: null,
    itemName: null,
    description: "",
    qty: "1",
    uom: "",
    unitPrice: "",
    expenseCategoryId: "",
    costCenterId: "",
  };
}

/**
 * Form tạo lệnh mua chợ + tạm ứng (T-022). Vật tư chỉ được chọn khi
 * danh mục cho phép kênh `market` (server chặn bằng
 * `ERR_CHANNEL_NOT_ALLOWED` nếu lọt); đơn giá để trống thì lấy giá
 * trần, có giá thì ghi nguồn `manual`. Tạo xong chuyển sang chi tiết
 * PO market để gửi duyệt (PO) rồi duyệt/chi tạm ứng.
 */
export function MarketOrderForm({
  propertyId,
  expenseCategories,
  costCenters,
}: {
  propertyId: string;
  expenseCategories: ExpenseCategoryRow[];
  costCenters: CostCenterRow[];
}) {
  const router = useRouter();
  const [lines, setLines] = useState<FormLine[]>([emptyLine()]);
  const [advanceAmount, setAdvanceAmount] = useState("");
  const [purpose, setPurpose] = useState("");
  const [expectedDate, setExpectedDate] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  function updateLine(key: string, patch: Partial<FormLine>) {
    setLines((prev) =>
      prev.map((line) => (line.key === key ? { ...line, ...patch } : line)),
    );
  }

  function removeLine(key: string) {
    setLines((prev) => {
      if (prev.length <= 1) return prev;
      return prev.filter((line) => line.key !== key);
    });
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (lines.length === 0) {
      setError(vi.procurement.form.needAtLeastOneLine);
      return;
    }
    for (const line of lines) {
      const qty = Number(line.qty);
      if (!Number.isFinite(qty) || qty <= 0) {
        setError(vi.procurement.form.needAtLeastOneLine);
        return;
      }
      if (!line.uom.trim()) {
        setError(vi.procurement.form.needAtLeastOneLine);
        return;
      }
      if (!line.itemId && !line.description.trim()) {
        setError(vi.procurement.form.itemSearchHint);
        return;
      }
      if (line.unitPrice.trim()) {
        const price = Number(line.unitPrice);
        if (!Number.isFinite(price) || price < 0) {
          setError(vi.procurement.form.needAtLeastOneLine);
          return;
        }
      }
    }
    const amount = Number(advanceAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      setError(vi.procurement.market.advanceAmountHint);
      return;
    }
    if (!purpose.trim()) {
      setError(vi.procurement.market.purposePlaceholder);
      return;
    }

    setSaving(true);
    const res = await createMarketOrderAction({
      propertyId,
      lines: lines.map((line) => ({
        itemId: line.itemId,
        description: line.description.trim() ? line.description.trim() : null,
        qty: Number(line.qty),
        uom: line.uom.trim(),
        unitPrice: line.unitPrice.trim() ? Number(line.unitPrice) : null,
        expenseCategoryId: line.expenseCategoryId || null,
        costCenterId: line.costCenterId || null,
      })),
      advanceAmount: amount,
      purpose: purpose.trim(),
      expectedDate: expectedDate || null,
    });
    setSaving(false);
    if (res.ok) {
      router.push(`/${propertyId}/procurement/po/${res.data.po_id}`);
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
          {vi.procurement.market.createTitle}
        </h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div>
            <label className="text-xs font-medium text-muted-foreground">
              {vi.procurement.market.advanceAmount} {vi.common.vndSuffix} *
            </label>
            <input
              type="number"
              min="1"
              step="any"
              value={advanceAmount}
              onChange={(e) => setAdvanceAmount(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
            <p className="mt-1 text-xs text-muted-foreground">
              {vi.procurement.market.advanceAmountHint}
            </p>
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground">
              {vi.procurement.market.expectedDate}
            </label>
            <input
              type="date"
              value={expectedDate}
              onChange={(e) => setExpectedDate(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
          </div>
        </div>
        <div>
          <label className="text-xs font-medium text-muted-foreground">
            {vi.procurement.market.purpose} *
          </label>
          <textarea
            value={purpose}
            onChange={(e) => setPurpose(e.target.value)}
            placeholder={vi.procurement.market.purposePlaceholder}
            className="mt-1 min-h-16 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </div>
      </div>

      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h3 className="font-semibold text-sm">
            {vi.procurement.list.lines} ({lines.length})
          </h3>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => setLines((prev) => [...prev, emptyLine()])}
          >
            + {vi.procurement.form.addLine}
          </Button>
        </div>
        <p className="text-xs text-muted-foreground">
          {vi.procurement.form.itemSearchHint}
        </p>

        {lines.map((line, index) => (
          <div
            key={line.key}
            className="rounded-lg border p-4 space-y-3 bg-card"
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium">
                {vi.procurement.form.lineNumber} {index + 1}
              </span>
              {lines.length > 1 ? (
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
                  onPick={(item) => {
                    if (!item.allowedChannels.includes("market")) {
                      setError(vi.procurement.market.channelNotAllowed);
                      return;
                    }
                    updateLine(line.key, {
                      itemId: item.id,
                      itemCode: item.code,
                      itemName: item.name,
                      uom: line.uom || item.stockUom,
                    });
                  }}
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

            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.form.qty} *
                </label>
                <input
                  type="number"
                  min="0"
                  step="any"
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
                  value={line.uom}
                  onChange={(e) =>
                    updateLine(line.key, { uom: e.target.value })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
              </div>
              <div>
                <label className="text-xs font-medium text-muted-foreground">
                  {vi.procurement.detail.unitPrice}
                </label>
                <input
                  type="number"
                  min="0"
                  step="any"
                  value={line.unitPrice}
                  onChange={(e) =>
                    updateLine(line.key, { unitPrice: e.target.value })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
                />
                <p className="mt-1 text-xs text-muted-foreground">
                  {vi.procurement.market.unitPriceHint}
                </p>
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

            <div>
              <label className="text-xs font-medium text-muted-foreground">
                {vi.procurement.form.expenseCategory}
              </label>
              <select
                value={line.expenseCategoryId}
                onChange={(e) =>
                  updateLine(line.key, { expenseCategoryId: e.target.value })
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
          </div>
        ))}
      </div>

      <div className="flex justify-end gap-2">
        <Button type="submit" disabled={saving}>
          {saving ? vi.common.loading : vi.procurement.market.create}
        </Button>
      </div>
    </form>
  );
}
