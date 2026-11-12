"use client";

import { useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import type { ReportParamKind } from "@/features/report/definitions";

export type FilterOption = { id: string; label: string };

/**
 * Bộ lọc báo cáo (T-044): form GET — submit đẩy tham số lên URL,
 * trang server đọc searchParams và gọi lại report_get.
 * Repo chỉ có Button trong components/ui nên dùng input/select native
 * (tiền lệ admin/assign-role-form).
 */
export function ReportFilters({
  paramKind,
  initial,
  warehouses,
  suppliers,
}: {
  paramKind: ReportParamKind;
  initial: Record<string, string | undefined>;
  warehouses?: FilterOption[];
  suppliers?: FilterOption[];
}) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const [from, setFrom] = useState(initial.from ?? "");
  const [to, setTo] = useState(initial.to ?? "");
  const [month, setMonth] = useState(initial.month ?? "");
  const [asOf, setAsOf] = useState(initial.as_of ?? "");
  const [date, setDate] = useState(initial.date ?? "");
  const [warehouseId, setWarehouseId] = useState(initial.warehouse_id ?? "all");
  const [supplierId, setSupplierId] = useState(initial.supplier_id ?? "all");

  function apply() {
    const params = new URLSearchParams(searchParams.toString());
    const setOrDelete = (key: string, value: string, allValue = "") => {
      if (value && value !== allValue) params.set(key, value);
      else params.delete(key);
    };
    setOrDelete("from", from);
    setOrDelete("to", to);
    setOrDelete("month", month);
    setOrDelete("as_of", asOf);
    setOrDelete("date", date);
    setOrDelete("warehouse_id", warehouseId, "all");
    setOrDelete("supplier_id", supplierId, "all");
    router.push(`${pathname}?${params.toString()}`);
  }

  return (
    <form
      className="flex flex-wrap items-end gap-3 rounded-lg border p-3"
      onSubmit={(e) => {
        e.preventDefault();
        apply();
      }}
    >
      {paramKind === "range" && (
        <>
          <label className="space-y-1 text-sm">
            <span className="font-medium">{vi.reports.from}</span>
            <input
              type="date"
              value={from}
              onChange={(e) => setFrom(e.target.value)}
              className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
            />
          </label>
          <label className="space-y-1 text-sm">
            <span className="font-medium">{vi.reports.to}</span>
            <input
              type="date"
              value={to}
              onChange={(e) => setTo(e.target.value)}
              className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
            />
          </label>
        </>
      )}
      {paramKind === "as_of" && (
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.reports.asOf}</span>
          <input
            type="date"
            value={asOf}
            onChange={(e) => setAsOf(e.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
      )}
      {paramKind === "month" && (
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.reports.month}</span>
          <input
            type="month"
            value={month}
            onChange={(e) => setMonth(e.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
      )}
      {paramKind === "date" && (
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.reports.date}</span>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
      )}
      {paramKind === "range" && warehouses && (
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.reports.warehouse}</span>
          <select
            value={warehouseId}
            onChange={(e) => setWarehouseId(e.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="all">{vi.reports.allWarehouses}</option>
            {warehouses.map((w) => (
              <option key={w.id} value={w.id}>
                {w.label}
              </option>
            ))}
          </select>
        </label>
      )}
      {paramKind === "range" && suppliers && (
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.reports.supplier}</span>
          <select
            value={supplierId}
            onChange={(e) => setSupplierId(e.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <option value="all">{vi.reports.allSuppliers}</option>
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>
                {s.label}
              </option>
            ))}
          </select>
        </label>
      )}
      <Button type="submit" variant="outline" size="lg">
        {vi.reports.applyFilter}
      </Button>
    </form>
  );
}
