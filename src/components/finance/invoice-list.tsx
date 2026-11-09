"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import type { InvoiceRow, InvoiceStatus } from "@/features/finance/queries";
import type { SupplierRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

const STATUS_LABELS: Record<InvoiceStatus, string> = {
  draft: vi.components.docStatus.draft,
  matched: vi.components.docStatus.matched,
  on_hold: vi.components.docStatus.onHold,
  approved: vi.components.docStatus.approved,
  partially_paid: vi.components.docStatus.partiallyPaid,
  paid: vi.components.docStatus.paid,
  cancelled: vi.components.docStatus.cancelled,
};

const STATUS_OPTIONS: Array<{ value: "" | InvoiceStatus; label: string }> = [
  { value: "", label: vi.common.all },
  { value: "draft", label: STATUS_LABELS.draft },
  { value: "matched", label: STATUS_LABELS.matched },
  { value: "on_hold", label: STATUS_LABELS.on_hold },
  { value: "approved", label: STATUS_LABELS.approved },
  { value: "partially_paid", label: STATUS_LABELS.partially_paid },
  { value: "paid", label: STATUS_LABELS.paid },
  { value: "cancelled", label: STATUS_LABELS.cancelled },
];

/** Danh sách hóa đơn NCC (T-041): lọc theo trạng thái + NCC + kỳ. */
export function InvoiceList({
  propertyId,
  invoices,
  suppliers,
  canManageInvoice,
}: {
  propertyId: string;
  invoices: InvoiceRow[];
  suppliers: SupplierRow[];
  canManageInvoice: boolean;
}) {
  const router = useRouter();
  const [status, setStatus] = useState<"" | InvoiceStatus>("");
  const [supplierId, setSupplierId] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");

  const filtered = useMemo(
    () =>
      invoices.filter(
        (inv) =>
          (status === "" || inv.status === status) &&
          (supplierId === "" || inv.supplier_id === supplierId) &&
          (from === "" || inv.invoice_date >= from) &&
          (to === "" || inv.invoice_date <= to),
      ),
    [invoices, status, supplierId, from, to],
  );

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="flex flex-wrap items-end gap-3">
          <label className="block text-sm">
            {vi.common.status}
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value as "" | InvoiceStatus)}
              className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
            >
              {STATUS_OPTIONS.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            {vi.finance.supplier}
            <select
              value={supplierId}
              onChange={(e) => setSupplierId(e.target.value)}
              className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
            >
              <option value="">{vi.common.all}</option>
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.code})
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            {vi.finance.invoiceDate} (từ)
            <input
              type="date"
              value={from}
              onChange={(e) => setFrom(e.target.value)}
              className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
            />
          </label>
          <label className="block text-sm">
            {vi.finance.invoiceDate} (đến)
            <input
              type="date"
              value={to}
              onChange={(e) => setTo(e.target.value)}
              className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
            />
          </label>
        </div>
        {canManageInvoice ? (
          <Button
            type="button"
            onClick={() => router.push(`/${propertyId}/finance/invoices/new`)}
          >
            {vi.finance.newInvoice}
          </Button>
        ) : null}
      </div>

      {filtered.length === 0 ? (
        <p className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">
          {vi.components.table.emptyDescription}
        </p>
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-3 py-2">{vi.finance.invoiceSymbol}</th>
                <th className="px-3 py-2">{vi.finance.invoiceNo}</th>
                <th className="px-3 py-2">{vi.finance.invoiceDate}</th>
                <th className="px-3 py-2">{vi.finance.supplier}</th>
                <th className="px-3 py-2 text-right">
                  {vi.finance.totalAmount}
                </th>
                <th className="px-3 py-2">{vi.common.status}</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((inv) => (
                <tr key={inv.id} className="border-b last:border-0">
                  <td className="px-3 py-2">
                    <Link
                      href={`/${propertyId}/finance/invoices/${inv.id}`}
                      className="font-medium hover:underline"
                    >
                      {inv.invoice_symbol}
                    </Link>
                  </td>
                  <td className="px-3 py-2">{inv.invoice_no}</td>
                  <td className="px-3 py-2">{inv.invoice_date}</td>
                  <td className="px-3 py-2">
                    {inv.supplier_name ?? vi.common.noData}
                  </td>
                  <td className="px-3 py-2 text-right">
                    <MoneyText amount={inv.total} />
                  </td>
                  <td className="px-3 py-2">
                    <span
                      className={
                        inv.status === "on_hold"
                          ? "font-medium text-red-800"
                          : undefined
                      }
                    >
                      {STATUS_LABELS[inv.status]}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
