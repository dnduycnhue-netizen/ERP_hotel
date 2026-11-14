"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { saveInvoiceDraftAction } from "@/features/finance/actions";
import type { PoLineRow, PoRow } from "@/features/procurement/queries";
import type { SupplierRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/** Ngày hôm nay theo giờ Việt Nam (YYYY-MM-DD) — phía client. */
function todayVnClient(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

const ALLOWED_PO_STATUSES = new Set([
  "approved",
  "sent",
  "partially_received",
  "received",
  "closed",
]);

type LineInput = {
  poLineId: string;
  qty: string;
  unitPrice: string;
  vatRate: string;
};

/**
 * Nhập hóa đơn mới (T-041): chọn NCC → chọn đơn mua → nhập dòng hóa đơn
 * theo dòng đơn mua. Số lượng nhập theo đơn vị lưu kho (RPC khớp 3
 * chiều so với số đã nhận theo đơn vị lưu kho). Đơn giá mặc định lấy
 * theo đơn mua; số lượng mặc định lấy số đã nhận (nếu có).
 */
export function InvoiceForm({
  propertyId,
  suppliers,
  pos,
  selectedSupplierId,
  selectedPoId,
  poLines,
}: {
  propertyId: string;
  suppliers: SupplierRow[];
  pos: PoRow[];
  selectedSupplierId: string;
  selectedPoId: string;
  poLines: PoLineRow[] | null;
}) {
  const router = useRouter();
  const [symbol, setSymbol] = useState("");
  const [no, setNo] = useState("");
  const [date, setDate] = useState(todayVnClient());
  const [lookupCode, setLookupCode] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const supplierPos = useMemo(
    () =>
      pos.filter(
        (po) =>
          po.supplier_id !== null &&
          ALLOWED_PO_STATUSES.has(po.status) &&
          (selectedSupplierId === "" || po.supplier_id === selectedSupplierId),
      ),
    [pos, selectedSupplierId],
  );

  const [lines, setLines] = useState<LineInput[]>(() =>
    (poLines ?? []).map((l) => ({
      poLineId: l.id,
      qty: String(
        l.received_qty_stock > 0
          ? l.received_qty_stock
          : (l.qty_stock ?? l.qty),
      ),
      unitPrice: String(l.unit_price),
      vatRate: "0",
    })),
  );

  function goTo(params: { supplierId?: string; poId?: string }) {
    const search = new URLSearchParams();
    const supplierId = params.supplierId ?? selectedSupplierId;
    const poId = params.poId ?? selectedPoId;
    if (supplierId) search.set("supplierId", supplierId);
    if (poId) search.set("poId", poId);
    router.push(`/${propertyId}/finance/invoices/new?${search.toString()}`);
  }

  function setLine(index: number, patch: Partial<LineInput>) {
    setLines((prev) =>
      prev.map((l, i) => (i === index ? { ...l, ...patch } : l)),
    );
  }

  const totals = useMemo(() => {
    let beforeTax = 0;
    let vat = 0;
    for (const l of lines) {
      const qty = Number(l.qty);
      const price = Number(l.unitPrice);
      const rate = Number(l.vatRate);
      if (!Number.isFinite(qty) || !Number.isFinite(price)) continue;
      const amount = qty * price;
      beforeTax += amount;
      if (Number.isFinite(rate)) vat += (amount * rate) / 100;
    }
    return { beforeTax, vat, total: beforeTax + vat };
  }, [lines]);

  const canSubmit =
    !pending &&
    selectedSupplierId !== "" &&
    selectedPoId !== "" &&
    symbol.trim() !== "" &&
    no.trim() !== "" &&
    date !== "" &&
    lines.length > 0 &&
    lines.every(
      (l) =>
        Number(l.qty) > 0 &&
        Number(l.unitPrice) >= 0 &&
        Number(l.vatRate) >= 0 &&
        Number(l.vatRate) <= 100,
    );

  async function handleSubmit() {
    setPending(true);
    setError(null);
    const res = await saveInvoiceDraftAction({
      propertyId,
      supplierId: selectedSupplierId,
      header: {
        invoiceSymbol: symbol.trim(),
        invoiceNo: no.trim(),
        invoiceDate: date,
        lookupCode: lookupCode.trim() || null,
        xmlPath: null,
      },
      lines: lines.map((l) => ({
        poLineId: l.poLineId,
        qty: Number(l.qty),
        unitPrice: Number(l.unitPrice),
        vatRate: Number(l.vatRate),
        grLineId: null,
      })),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(`/${propertyId}/finance/invoices/${res.data.id}`);
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-3 rounded-lg border bg-card p-4 sm:grid-cols-2">
        <label className="block text-sm">
          {vi.finance.supplier}
          <select
            value={selectedSupplierId}
            onChange={(e) => goTo({ supplierId: e.target.value, poId: "" })}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          >
            <option value="">{vi.finance.selectSupplier}</option>
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name} ({s.code})
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          {vi.finance.poDocNo}
          <select
            value={selectedPoId}
            onChange={(e) => goTo({ poId: e.target.value })}
            disabled={selectedSupplierId === ""}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm disabled:opacity-50"
          >
            <option value="">{vi.finance.selectPo}</option>
            {supplierPos.map((po) => (
              <option key={po.id} value={po.id}>
                {po.doc_no} · {po.status}
              </option>
            ))}
          </select>
          {selectedSupplierId === "" ? (
            <span className="mt-1 block text-xs text-muted-foreground">
              {vi.finance.selectSupplierFirst}
            </span>
          ) : null}
        </label>
        <label className="block text-sm">
          {vi.finance.invoiceSymbol}
          <input
            value={symbol}
            onChange={(e) => setSymbol(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
            placeholder={`${vi.common.examplePrefix} C25TAA`}
          />
        </label>
        <label className="block text-sm">
          {vi.finance.invoiceNo}
          <input
            value={no}
            onChange={(e) => setNo(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
            placeholder={`${vi.common.examplePrefix} 0000123`}
          />
        </label>
        <label className="block text-sm">
          {vi.finance.invoiceDate}
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.finance.lookupCode}
          <input
            value={lookupCode}
            onChange={(e) => setLookupCode(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
      </div>

      {!poLines ? (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.finance.selectPo}
        </p>
      ) : poLines.length === 0 ? (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.components.table.emptyDescription}
        </p>
      ) : (
        <div className="rounded-lg border bg-card p-4">
          <p className="text-sm text-muted-foreground">
            {vi.finance.invoiceQtyStockHint}
          </p>
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-3 py-2">{vi.finance.itemDesc}</th>
                  <th className="px-3 py-2 text-right">{vi.finance.poQty}</th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.receivedQty}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.invoiceQty}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.unitPrice}
                  </th>
                  <th className="px-3 py-2 text-right">{vi.finance.vatRate}</th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.lineAmount}
                  </th>
                </tr>
              </thead>
              <tbody>
                {poLines.map((l, i) => {
                  const qty = Number(lines[i]?.qty ?? 0);
                  const price = Number(lines[i]?.unitPrice ?? 0);
                  return (
                    <tr key={l.id} className="border-b last:border-0">
                      <td className="px-3 py-2">
                        {l.item_name ??
                          l.item_code ??
                          l.description ??
                          vi.common.noData}
                        <span className="block text-xs text-muted-foreground">
                          {vi.finance.unitPrice}:{" "}
                          <MoneyText amount={l.unit_price} />
                        </span>
                      </td>
                      <td className="px-3 py-2 text-right">
                        {formatNumber(l.qty_stock ?? l.qty)}
                      </td>
                      <td className="px-3 py-2 text-right">
                        {formatNumber(l.received_qty_stock)}
                      </td>
                      <td className="px-3 py-2 text-right">
                        <input
                          type="number"
                          inputMode="decimal"
                          min="0"
                          step="0.0001"
                          value={lines[i]?.qty ?? ""}
                          onChange={(e) => setLine(i, { qty: e.target.value })}
                          className="w-24 rounded-md border bg-background px-2 py-1 text-right text-sm"
                        />
                      </td>
                      <td className="px-3 py-2 text-right">
                        <input
                          type="number"
                          inputMode="decimal"
                          min="0"
                          step="0.01"
                          value={lines[i]?.unitPrice ?? ""}
                          onChange={(e) =>
                            setLine(i, { unitPrice: e.target.value })
                          }
                          className="w-28 rounded-md border bg-background px-2 py-1 text-right text-sm"
                        />
                      </td>
                      <td className="px-3 py-2 text-right">
                        <input
                          type="number"
                          inputMode="decimal"
                          min="0"
                          max="100"
                          step="0.5"
                          value={lines[i]?.vatRate ?? ""}
                          onChange={(e) =>
                            setLine(i, { vatRate: e.target.value })
                          }
                          className="w-16 rounded-md border bg-background px-2 py-1 text-right text-sm"
                        />
                      </td>
                      <td className="px-3 py-2 text-right">
                        <MoneyText
                          amount={
                            Number.isFinite(qty) && Number.isFinite(price)
                              ? qty * price
                              : 0
                          }
                        />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <div className="mt-4 space-y-1 text-right text-sm">
            <p>
              {vi.finance.totalBeforeTax}:{" "}
              <MoneyText amount={totals.beforeTax} />
            </p>
            <p>
              {vi.finance.vatAmount}: <MoneyText amount={totals.vat} />
            </p>
            <p className="font-semibold">
              {vi.finance.totalAmount}: <MoneyText amount={totals.total} />
            </p>
          </div>
          <Button
            type="button"
            className="mt-4"
            disabled={!canSubmit}
            onClick={handleSubmit}
          >
            {pending ? vi.common.loading : vi.common.save}
          </Button>
          {error ? (
            <p className="mt-3 text-sm font-medium text-red-800">{error}</p>
          ) : null}
        </div>
      )}
    </div>
  );
}
