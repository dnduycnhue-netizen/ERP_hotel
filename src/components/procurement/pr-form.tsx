"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { ItemPicker } from "@/components/procurement/item-picker";
import { vi } from "@/i18n/vi";
import { savePrDraftAction } from "@/features/procurement/actions";
import type { PrLineRow, PrRow } from "@/features/procurement/queries";
import type {
  CostCenterRow,
  ExpenseCategoryRow,
  OutletRow,
} from "@/features/master/queries";

type FormLine = {
  key: string;
  id?: string;
  itemId: string | null;
  itemCode: string | null;
  itemName: string | null;
  description: string;
  qty: string;
  uom: string;
  expenseCategoryId: string;
  costCenterId: string;
  reason: string;
};

let lineKeyCounter = 0;
function nextLineKey(): string {
  lineKeyCounter += 1;
  return `line-${Date.now()}-${lineKeyCounter}`;
}

function toFormLine(line: PrLineRow): FormLine {
  return {
    key: nextLineKey(),
    id: line.id,
    itemId: line.item_id,
    itemCode: line.item_code,
    itemName: line.item_name,
    description: line.description ?? "",
    qty: String(line.qty),
    uom: line.uom,
    expenseCategoryId: line.expense_category_id ?? "",
    costCenterId: line.cost_center_id ?? "",
    reason: line.reason ?? "",
  };
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
    expenseCategoryId: "",
    costCenterId: "",
    reason: "",
  };
}

/**
 * Form tạo/sửa yêu cầu mua (T-021). Dòng có thể gắn vật tư (tìm theo
 * tên/mã) hoặc chỉ nhập mô tả tự do khi mua hàng chưa có mã — RPC
 * `pr_save_draft` yêu cầu có vật tư hoặc mô tả. Lưu nháp xong chuyển
 * sang trang chi tiết để gửi duyệt.
 */
export function PrForm({
  propertyId,
  initial,
  outlets,
  expenseCategories,
  costCenters,
}: {
  propertyId: string;
  initial?: { pr: PrRow; lines: PrLineRow[] };
  outlets: OutletRow[];
  expenseCategories: ExpenseCategoryRow[];
  costCenters: CostCenterRow[];
}) {
  const router = useRouter();
  const [kind, setKind] = useState<"stock" | "service">(
    initial?.pr.kind ?? "stock",
  );
  const [outletId, setOutletId] = useState(initial?.pr.outlet_id ?? "");
  const [needDate, setNeedDate] = useState(initial?.pr.need_date ?? "");
  const [note, setNote] = useState(initial?.pr.note ?? "");
  const [lines, setLines] = useState<FormLine[]>(
    initial && initial.lines.length > 0
      ? initial.lines.map(toFormLine)
      : [emptyLine()],
  );
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
    }

    setSaving(true);
    const res = await savePrDraftAction({
      propertyId,
      id: initial?.pr.id,
      outletId: outletId || null,
      kind,
      needDate: needDate || null,
      note: note.trim() ? note.trim() : null,
      lines: lines.map((line) => ({
        id: line.id,
        itemId: line.itemId,
        description: line.description.trim() ? line.description.trim() : null,
        qty: Number(line.qty),
        uom: line.uom.trim(),
        expenseCategoryId: line.expenseCategoryId || null,
        costCenterId: line.costCenterId || null,
        reason: line.reason.trim() ? line.reason.trim() : null,
      })),
    });
    setSaving(false);
    if (res.ok) {
      router.push(`/${propertyId}/procurement/pr/${res.data.id}`);
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
          {initial
            ? vi.procurement.pr.detailTitle
            : vi.procurement.pr.createTitle}
        </h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
          <div>
            <label className="text-xs font-medium text-muted-foreground">
              {vi.procurement.pr.kind} *
            </label>
            <select
              value={kind}
              onChange={(e) => setKind(e.target.value as "stock" | "service")}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            >
              <option value="stock">{vi.procurement.pr.kindStock}</option>
              <option value="service">{vi.procurement.pr.kindService}</option>
            </select>
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground">
              {vi.procurement.pr.outlet}
            </label>
            <select
              value={outletId}
              onChange={(e) => setOutletId(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            >
              <option value="">—</option>
              {outlets.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.code} · {o.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="text-xs font-medium text-muted-foreground">
              {vi.procurement.pr.needDate}
            </label>
            <input
              type="date"
              value={needDate}
              onChange={(e) => setNeedDate(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
            />
          </div>
        </div>
        <div>
          <label className="text-xs font-medium text-muted-foreground">
            {vi.procurement.pr.note}
          </label>
          <textarea
            value={note}
            onChange={(e) => setNote(e.target.value)}
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

            <div className="grid grid-cols-2 gap-3">
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
                  onChange={(e) =>
                    updateLine(line.key, { uom: e.target.value })
                  }
                  className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
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

            <div>
              <label className="text-xs font-medium text-muted-foreground">
                {vi.procurement.form.reason}
              </label>
              <input
                value={line.reason}
                onChange={(e) =>
                  updateLine(line.key, { reason: e.target.value })
                }
                className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm"
              />
            </div>
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
