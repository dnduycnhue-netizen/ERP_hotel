"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { PageHeader } from "@/components/shell/page-header";
import { Button } from "@/components/ui/button";
import {
  ItemPicker,
  type PickedItem,
} from "@/components/procurement/item-picker";
import { saveDocDraftAction } from "@/features/inventory/doc-actions";
import {
  PURPOSE_CODES,
  WASTE_REASONS,
  type DocKind,
} from "@/features/inventory/doc-schemas";
import type {
  CostCenterRow,
  ExpenseCategoryRow,
  OutletRow,
  WarehouseRow,
} from "@/features/master/queries";
import { vi } from "@/i18n/vi";

type FormLine = {
  key: string;
  picked: PickedItem | null;
  qty: string;
  note: string;
};

let lineSeq = 0;
function emptyLine(): FormLine {
  lineSeq += 1;
  return { key: `l${lineSeq}`, picked: null, qty: "", note: "" };
}

const inputCls = "h-9 w-full rounded-md border bg-background px-3 text-sm";

/** Mã DB (snake_case) → khóa vi (camelCase). */
function camel(code: string): string {
  return code.replace(/_([a-z])/g, (_, c: string) => c.toUpperCase());
}

const TITLES: Record<DocKind, string> = {
  waste: vi.inventory.doc.newWaste,
  requisition: vi.inventory.doc.newRequisition,
  transfer: vi.inventory.doc.newTransfer,
  purpose_issue: vi.inventory.doc.newIssue,
};

/**
 * Form lập chứng từ kho (B-4): hủy hàng, phiếu lĩnh, điều chuyển, xuất mục
 * đích. Chỉ lưu nháp qua RPC `<kind>_save_draft`; gửi duyệt/ghi sổ làm ở
 * trang chi tiết. Số lượng tính theo ĐVT lưu kho (ĐVT hiện kèm mặt hàng).
 */
export function StockDocForm({
  kind,
  propertyId,
  warehouses,
  outlets,
  costCenters,
  expenseCategories,
}: {
  kind: DocKind;
  propertyId: string;
  warehouses: WarehouseRow[];
  outlets: OutletRow[];
  costCenters: CostCenterRow[];
  expenseCategories: ExpenseCategoryRow[];
}) {
  const router = useRouter();
  const [warehouseId, setWarehouseId] = useState("");
  const [fromWarehouseId, setFromWarehouseId] = useState("");
  const [toWarehouseId, setToWarehouseId] = useState("");
  const [outletId, setOutletId] = useState("");
  const [reasonCode, setReasonCode] = useState("");
  const [purposeCode, setPurposeCode] = useState("");
  const [costCenterId, setCostCenterId] = useState("");
  const [expenseCategoryId, setExpenseCategoryId] = useState("");
  const [note, setNote] = useState("");
  const [lines, setLines] = useState<FormLine[]>(() => [emptyLine()]);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  // Phiếu lĩnh: kho nhận phải thuộc bộ phận đã chọn.
  const toOptions =
    kind === "requisition"
      ? warehouses.filter((w) => w.outlet_id === outletId)
      : warehouses;

  function patchLine(key: string, patch: Partial<FormLine>) {
    setLines((prev) =>
      prev.map((l) => (l.key === key ? { ...l, ...patch } : l)),
    );
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    if (lines.some((l) => !l.picked)) {
      setError(vi.inventory.doc.needItem);
      return;
    }
    if (lines.some((l) => !(Number(l.qty) > 0))) {
      setError(vi.inventory.doc.needQty);
      return;
    }
    setSaving(true);
    const res = await saveDocDraftAction({
      kind,
      propertyId,
      note: note.trim() || null,
      warehouseId: warehouseId || null,
      reasonCode: (reasonCode || null) as (typeof WASTE_REASONS)[number] | null,
      outletId: outletId || null,
      fromWarehouseId: fromWarehouseId || null,
      toWarehouseId: toWarehouseId || null,
      purposeCode: (purposeCode || null) as
        | (typeof PURPOSE_CODES)[number]
        | null,
      costCenterId: costCenterId || null,
      expenseCategoryId: expenseCategoryId || null,
      lines: lines.map((l) => ({
        itemId: l.picked?.id ?? "",
        qty: Number(l.qty),
        note: l.note.trim() || null,
      })),
    });
    setSaving(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    const base = {
      waste: "waste",
      requisition: "requisitions",
      transfer: "transfers",
      purpose_issue: "issues",
    }[kind];
    router.push(`/${propertyId}/inventory/${base}/${res.data.id}`);
    router.refresh();
  }

  const whSelect = (
    label: string,
    value: string,
    onChange: (v: string) => void,
    options: WarehouseRow[],
  ) => (
    <label className="flex flex-col gap-1 text-sm font-medium">
      {label} *
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className={inputCls}
      >
        <option value="">{vi.inventory.doc.choose}</option>
        {options.map((w) => (
          <option key={w.id} value={w.id}>
            {w.name} ({w.code})
          </option>
        ))}
      </select>
    </label>
  );

  return (
    <form onSubmit={handleSave} className="flex flex-col gap-4">
      <PageHeader title={TITLES[kind]} />

      {error ? (
        <div
          role="alert"
          className="rounded-md border border-destructive/20 bg-destructive/10 p-3 text-sm text-destructive"
        >
          {error}
        </div>
      ) : null}

      <div className="grid grid-cols-1 gap-3 rounded-lg border p-4 sm:grid-cols-2">
        {kind === "waste" || kind === "purpose_issue"
          ? whSelect(
              vi.inventory.warehouse,
              warehouseId,
              setWarehouseId,
              warehouses,
            )
          : null}

        {kind === "waste" ? (
          <label className="flex flex-col gap-1 text-sm font-medium">
            {vi.inventory.reason} *
            <select
              value={reasonCode}
              onChange={(e) => setReasonCode(e.target.value)}
              className={inputCls}
            >
              <option value="">{vi.inventory.doc.choose}</option>
              {WASTE_REASONS.map((code) => (
                <option key={code} value={code}>
                  {vi.inventory.wasteReasons[
                    camel(code) as keyof typeof vi.inventory.wasteReasons
                  ] ?? code}
                </option>
              ))}
            </select>
          </label>
        ) : null}

        {kind === "purpose_issue" ? (
          <>
            <label className="flex flex-col gap-1 text-sm font-medium">
              {vi.inventory.purpose} *
              <select
                value={purposeCode}
                onChange={(e) => setPurposeCode(e.target.value)}
                className={inputCls}
              >
                <option value="">{vi.inventory.doc.choose}</option>
                {PURPOSE_CODES.map((code) => (
                  <option key={code} value={code}>
                    {vi.inventory.purposeCodes[
                      camel(code) as keyof typeof vi.inventory.purposeCodes
                    ] ?? code}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 text-sm font-medium">
              {vi.inventory.costCenter}
              <select
                value={costCenterId}
                onChange={(e) => setCostCenterId(e.target.value)}
                className={inputCls}
              >
                <option value="">{vi.inventory.doc.choose}</option>
                {costCenters.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 text-sm font-medium">
              {vi.inventory.expenseCategory}
              <select
                value={expenseCategoryId}
                onChange={(e) => setExpenseCategoryId(e.target.value)}
                className={inputCls}
              >
                <option value="">{vi.inventory.doc.choose}</option>
                {expenseCategories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </label>
          </>
        ) : null}

        {kind === "requisition" ? (
          <label className="flex flex-col gap-1 text-sm font-medium">
            {vi.inventory.outlet} *
            <select
              value={outletId}
              onChange={(e) => {
                setOutletId(e.target.value);
                setToWarehouseId("");
              }}
              className={inputCls}
            >
              <option value="">{vi.inventory.doc.choose}</option>
              {outlets.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          </label>
        ) : null}

        {kind === "requisition" || kind === "transfer"
          ? whSelect(
              vi.inventory.fromWarehouse,
              fromWarehouseId,
              setFromWarehouseId,
              warehouses,
            )
          : null}
        {kind === "requisition" || kind === "transfer"
          ? whSelect(
              vi.inventory.toWarehouse,
              toWarehouseId,
              setToWarehouseId,
              toOptions,
            )
          : null}

        <label className="flex flex-col gap-1 text-sm font-medium sm:col-span-2">
          {vi.inventory.note}
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            className={inputCls}
            maxLength={1000}
          />
        </label>
      </div>

      <div className="flex flex-col gap-3">
        <p className="text-xs text-muted-foreground">
          {vi.inventory.doc.stockUomHint}
        </p>
        {lines.map((line) => (
          <div
            key={line.key}
            className="grid grid-cols-1 items-end gap-2 rounded-lg border p-3 sm:grid-cols-[1fr_8rem_1fr_auto]"
          >
            <div className="flex flex-col gap-1 text-sm font-medium">
              {vi.inventory.itemName} *
              <ItemPicker
                propertyId={propertyId}
                picked={line.picked}
                onPick={(item) =>
                  patchLine(line.key, {
                    picked: {
                      id: item.id,
                      code: item.code,
                      name: item.name,
                      stockUom: item.stockUom,
                    },
                  })
                }
                onClear={() => patchLine(line.key, { picked: null })}
              />
            </div>
            <label className="flex flex-col gap-1 text-sm font-medium">
              {vi.inventory.qty}
              {line.picked ? ` (${line.picked.stockUom})` : ""} *
              <input
                type="number"
                inputMode="decimal"
                step="any"
                min="0"
                value={line.qty}
                onChange={(e) => patchLine(line.key, { qty: e.target.value })}
                className={inputCls}
              />
            </label>
            <label className="flex flex-col gap-1 text-sm font-medium">
              {vi.inventory.note}
              <input
                value={line.note}
                onChange={(e) => patchLine(line.key, { note: e.target.value })}
                className={inputCls}
                maxLength={500}
              />
            </label>
            <Button
              type="button"
              variant="ghost"
              size="icon"
              aria-label={vi.inventory.doc.removeLine}
              disabled={lines.length <= 1}
              onClick={() =>
                setLines((prev) => prev.filter((l) => l.key !== line.key))
              }
            >
              <Trash2 className="size-4" aria-hidden />
            </Button>
          </div>
        ))}
        <div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => setLines((prev) => [...prev, emptyLine()])}
          >
            <Plus className="size-4" aria-hidden />
            {vi.inventory.doc.addLine}
          </Button>
        </div>
      </div>

      <div>
        <Button type="submit" disabled={saving}>
          {saving ? vi.inventory.doc.saving : vi.inventory.doc.saveDraft}
        </Button>
      </div>
    </form>
  );
}
