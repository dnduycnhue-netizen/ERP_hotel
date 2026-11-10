"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import { createPaymentRequestAction } from "@/features/finance/actions";
import type { PayableInvoiceRow } from "@/features/finance/queries";
import type { SupplierRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/**
 * Tạo đề nghị thanh toán (T-041): chọn NCC → chọn hóa đơn đã duyệt còn
 * số tiền chưa đề nghị → nhập số tiền từng hóa đơn (không vượt số còn
 * lại) → hạn trả (để trống lấy hạn muộn nhất trong các hóa đơn).
 */
export function PaymentRequestForm({
  propertyId,
  suppliers,
  selectedSupplierId,
  payableInvoices,
}: {
  propertyId: string;
  suppliers: SupplierRow[];
  selectedSupplierId: string;
  payableInvoices: PayableInvoiceRow[] | null;
}) {
  const router = useRouter();
  const [selected, setSelected] = useState<Record<string, string>>({});
  const [dueDate, setDueDate] = useState("");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [errorCode, setErrorCode] = useState<string | null>(null);

  const total = useMemo(
    () =>
      Object.values(selected).reduce((s, v) => {
        const n = Number(v);
        return s + (Number.isFinite(n) && n > 0 ? n : 0);
      }, 0),
    [selected],
  );

  function goTo(supplierId: string) {
    const search = supplierId
      ? `?supplierId=${encodeURIComponent(supplierId)}`
      : "";
    router.push(`/${propertyId}/finance/payment-requests/new${search}`);
  }

  const canSubmit =
    !pending &&
    selectedSupplierId !== "" &&
    total > 0 &&
    (payableInvoices ?? []).every((inv) => {
      const raw = selected[inv.id];
      if (raw === undefined || raw === "") return true;
      const n = Number(raw);
      return n > 0 && n <= inv.remaining;
    }) &&
    Object.keys(selected).some((k) => Number(selected[k]) > 0);

  async function handleSubmit() {
    setPending(true);
    setError(null);
    setErrorCode(null);
    const lines = (payableInvoices ?? [])
      .filter((inv) => Number(selected[inv.id]) > 0)
      .map((inv) => ({ invoiceId: inv.id, amount: Number(selected[inv.id]) }));
    const res = await createPaymentRequestAction({
      propertyId,
      supplierId: selectedSupplierId,
      lines,
      dueDate: dueDate || null,
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      setErrorCode(res.code ?? null);
      return;
    }
    router.push(`/${propertyId}/finance/payment-requests/${res.data.id}`);
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-3 rounded-lg border bg-card p-4 sm:grid-cols-2">
        <label className="block text-sm">
          {vi.finance.supplier}
          <select
            value={selectedSupplierId}
            onChange={(e) => goTo(e.target.value)}
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
          {vi.finance.dueDate}
          <input
            type="date"
            value={dueDate}
            onChange={(e) => setDueDate(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
      </div>

      {!payableInvoices ? (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.finance.selectSupplier}
        </p>
      ) : payableInvoices.length === 0 ? (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.finance.noPayableInvoices}
        </p>
      ) : (
        <div className="rounded-lg border bg-card p-4">
          <h2 className="font-medium">{vi.finance.selectInvoices}</h2>
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-3 py-2">{vi.finance.invoiceSymbol}</th>
                  <th className="px-3 py-2">{vi.finance.invoiceNo}</th>
                  <th className="px-3 py-2">{vi.finance.invoiceDate}</th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.totalAmount}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.remainingAmount}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.requestAmount}
                  </th>
                </tr>
              </thead>
              <tbody>
                {payableInvoices.map((inv) => (
                  <tr key={inv.id} className="border-b last:border-0">
                    <td className="px-3 py-2">{inv.invoice_symbol}</td>
                    <td className="px-3 py-2">{inv.invoice_no}</td>
                    <td className="px-3 py-2">{inv.invoice_date}</td>
                    <td className="px-3 py-2 text-right">
                      <MoneyText amount={inv.total} />
                    </td>
                    <td className="px-3 py-2 text-right">
                      <MoneyText amount={inv.remaining} />
                    </td>
                    <td className="px-3 py-2 text-right">
                      <input
                        type="number"
                        inputMode="decimal"
                        min="0"
                        max={inv.remaining}
                        step="0.01"
                        value={selected[inv.id] ?? ""}
                        onChange={(e) =>
                          setSelected((prev) => ({
                            ...prev,
                            [inv.id]: e.target.value,
                          }))
                        }
                        className="w-32 rounded-md border bg-background px-2 py-1 text-right text-sm"
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <p className="mt-3 text-right text-sm">
            {vi.finance.totalAmount}:{" "}
            <MoneyText amount={total} className="font-semibold" />
          </p>
          <p className="mt-1 text-right text-xs text-muted-foreground">
            {vi.finance.remainingHint}
          </p>
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
          {errorCode === "ERR_SERVICE_NOT_ACCEPTED" ? (
            <p className="mt-3 rounded-md bg-amber-50 p-3 text-sm text-amber-800">
              <span className="font-medium">{vi.service.blockedTitle}. </span>
              {vi.service.blockedHint}{" "}
              <Link
                href={`/${propertyId}/procurement/service-contracts/schedules`}
                className="font-medium underline"
              >
                {vi.service.goToSchedules}
              </Link>
            </p>
          ) : null}
        </div>
      )}
    </div>
  );
}
