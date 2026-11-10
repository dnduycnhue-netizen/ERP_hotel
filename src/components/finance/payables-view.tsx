"use client";

import { useMemo, useState } from "react";
import { MoneyText } from "@/components/common/money-text";
import type { ApLedgerRow, SupplierAgingRow } from "@/features/finance/queries";
import type { SupplierRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

const DOC_TYPE_LABELS: Record<string, string> = {
  supplier_invoice: vi.finance.navInvoices,
  supplier_return: vi.finance.navInvoices,
  payment_request: vi.finance.navPaymentRequests,
  advance_settlement: vi.finance.navAdvances,
};

/**
 * Công nợ (T-041): tuổi nợ theo NCC + sổ chi tiết ap_ledger.
 * Tuổi nợ tính từ hạn trả (`due_date`) của từng khoản phải trả, tiền
 * đã trả/trả hàng đã phân bổ FIFO vào khoản hạn trả sớm nhất (xem
 * `getApAging`). Sổ công nợ chỉ đọc — ap_ledger INSERT-only.
 */
export function PayablesView({
  aging,
  ledger,
  suppliers,
}: {
  aging: SupplierAgingRow[];
  ledger: ApLedgerRow[];
  suppliers: SupplierRow[];
}) {
  const [supplierId, setSupplierId] = useState("");

  const filteredAging = useMemo(
    () =>
      supplierId === ""
        ? aging
        : aging.filter((r) => r.supplier_id === supplierId),
    [aging, supplierId],
  );
  const filteredLedger = useMemo(
    () =>
      supplierId === ""
        ? ledger
        : ledger.filter((r) => r.supplier_id === supplierId),
    [ledger, supplierId],
  );

  const totals = useMemo(() => {
    let balance = 0;
    let overdue = 0;
    for (const r of filteredAging) {
      balance += r.balance;
      overdue +=
        r.overdue1to30 + r.overdue31to60 + r.overdue61to90 + r.overdueOver90;
    }
    return { balance, overdue };
  }, [filteredAging]);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end gap-3">
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
        <div className="flex gap-4 text-sm">
          <p>
            {vi.finance.totalPayable}:{" "}
            <MoneyText amount={totals.balance} className="font-semibold" />
          </p>
          <p>
            {vi.finance.totalOverdue}:{" "}
            <MoneyText
              amount={totals.overdue}
              className={
                totals.overdue > 0
                  ? "font-semibold text-red-800"
                  : "font-semibold"
              }
            />
          </p>
        </div>
      </div>

      <p className="text-sm text-muted-foreground">{vi.finance.payablesHint}</p>

      <div className="rounded-lg border bg-card p-4">
        <h2 className="font-medium">{vi.finance.payablesTitle}</h2>
        {filteredAging.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.components.table.emptyDescription}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.supplier}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.payableColumn}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.paidColumn}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.balanceColumn}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.notDue}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.overdue1to30}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.overdue31to60}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.overdue61to90}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.overdueOver90}
                  </th>
                </tr>
              </thead>
              <tbody>
                {filteredAging.map((r) => (
                  <tr
                    key={r.supplier_id}
                    className="border-t hover:bg-muted/40"
                  >
                    <td className="px-3 py-3 align-middle">
                      {r.supplier_name ?? vi.common.noData}
                      {r.supplier_code ? ` (${r.supplier_code})` : ""}
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={r.payable} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={r.paid} />
                    </td>
                    <td className="px-3 py-3 text-right font-medium align-middle">
                      <MoneyText amount={r.balance} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={r.notDue} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={r.overdue1to30} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={r.overdue31to60} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={r.overdue61to90} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={r.overdueOver90} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="rounded-lg border bg-card p-4">
        <h2 className="font-medium">{vi.finance.ledgerTitle}</h2>
        {filteredLedger.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.components.table.emptyDescription}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.entryDateColumn}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.supplier}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.docTypeColumn}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.dueDateColumn}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.amountColumn}
                  </th>
                </tr>
              </thead>
              <tbody>
                {filteredLedger.map((row) => (
                  <tr key={row.id} className="border-t hover:bg-muted/40">
                    <td className="px-3 py-3 align-middle">{row.entry_date}</td>
                    <td className="px-3 py-3 align-middle">
                      {row.supplier_name ?? vi.common.noData}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {DOC_TYPE_LABELS[row.doc_type] ?? row.doc_type}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {row.due_date ?? vi.common.noData}
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={row.amount} />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
