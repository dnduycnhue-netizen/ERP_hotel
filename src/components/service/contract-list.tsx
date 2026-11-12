"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import type { ServiceContractRow } from "@/features/service/queries";
import { daysLeft } from "@/features/service/dates";
import type { SupplierRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

const STATUS_LABELS: Record<string, string> = {
  draft: vi.service.statusDraft,
  active: vi.service.statusActive,
  suspended: vi.service.statusSuspended,
  expired: vi.service.statusExpired,
  cancelled: vi.service.statusCancelled,
};

const CYCLE_LABELS: Record<string, string> = {
  monthly: vi.service.cycleMonthly,
  quarterly: vi.service.cycleQuarterly,
  yearly: vi.service.cycleYearly,
  per_visit: vi.service.cyclePerVisit,
};

/** Danh sách hợp đồng dịch vụ (T-042): lọc theo trạng thái + NCC. */
export function ContractList({
  propertyId,
  contracts,
  suppliers,
  canManageContract,
}: {
  propertyId: string;
  contracts: ServiceContractRow[];
  suppliers: SupplierRow[];
  canManageContract: boolean;
}) {
  const [status, setStatus] = useState("");
  const [supplierId, setSupplierId] = useState("");

  const filtered = useMemo(
    () =>
      contracts.filter(
        (c) =>
          (status === "" || c.status === status) &&
          (supplierId === "" || c.supplier_id === supplierId),
      ),
    [contracts, status, supplierId],
  );

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="flex flex-wrap items-end gap-3">
          <label className="block text-sm">
            {vi.common.status}
            <select
              value={status}
              onChange={(e) => setStatus(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
            >
              <option value="">{vi.common.all}</option>
              {Object.entries(STATUS_LABELS).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
          <label className="block text-sm">
            {vi.finance.supplier}
            <select
              value={supplierId}
              onChange={(e) => setSupplierId(e.target.value)}
              className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
            >
              <option value="">{vi.common.all}</option>
              {suppliers.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.code})
                </option>
              ))}
            </select>
          </label>
        </div>
        {canManageContract ? (
          <Link
            href={`/${propertyId}/procurement/service-contracts/new`}
            className="inline-flex"
          >
            <Button type="button">{vi.service.newContract}</Button>
          </Link>
        ) : null}
      </div>

      {filtered.length === 0 ? (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.components.table.emptyDescription}
        </p>
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.service.contractTitle}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.finance.supplier}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.service.billingCycle}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.service.amountPerCycle}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.service.endDate}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.status}
                </th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((c) => {
                const remaining =
                  c.status === "active" && c.end_date
                    ? daysLeft(c.end_date)
                    : null;
                const renewalSoon =
                  remaining !== null &&
                  remaining >= 0 &&
                  remaining <= c.renew_notice_days;
                const renewalOverdue = remaining !== null && remaining < 0;
                return (
                  <tr key={c.id} className="border-t hover:bg-muted/40">
                    <td className="px-3 py-3 align-middle">
                      <Link
                        href={`/${propertyId}/procurement/service-contracts/${c.id}`}
                        className="font-medium hover:underline"
                      >
                        {c.title}
                      </Link>
                      <p className="text-xs text-muted-foreground">
                        {c.expense_category_name ?? vi.common.noData} ·{" "}
                        {c.cost_center_name ?? vi.common.noData}
                      </p>
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {c.supplier_name ?? vi.common.noData}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {CYCLE_LABELS[c.billing_cycle] ?? c.billing_cycle}
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={c.amount_per_cycle} />
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {c.end_date ?? vi.service.noEndDate}
                      {renewalSoon ? (
                        <p className="text-xs font-medium text-amber-700">
                          {vi.service.renewalSoon.replace(
                            "{days}",
                            String(remaining),
                          )}
                        </p>
                      ) : null}
                      {renewalOverdue ? (
                        <p className="text-xs font-medium text-destructive">
                          {vi.service.renewalOverdue.replace(
                            "{days}",
                            String(-remaining),
                          )}
                        </p>
                      ) : null}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      <span
                        className={cn(
                          "rounded-full px-2 py-0.5 text-xs font-medium",
                          c.status === "active" &&
                            "bg-green-100 text-green-800",
                          c.status === "draft" && "bg-slate-100 text-slate-700",
                          c.status === "suspended" &&
                            "bg-amber-100 text-amber-800",
                          c.status === "expired" && "bg-red-100 text-red-800",
                          c.status === "cancelled" &&
                            "bg-slate-100 text-slate-500",
                        )}
                      >
                        {STATUS_LABELS[c.status] ?? c.status}
                      </span>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
