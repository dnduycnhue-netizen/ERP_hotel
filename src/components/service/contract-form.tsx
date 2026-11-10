"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { saveContractAction } from "@/features/service/actions";
import type { ServiceContractRow } from "@/features/service/queries";
import type {
  CostCenterRow,
  ExpenseCategoryRow,
  SupplierRow,
} from "@/features/master/queries";
import { vi } from "@/i18n/vi";

const CYCLE_OPTIONS = [
  { value: "monthly", label: vi.service.cycleMonthly },
  { value: "quarterly", label: vi.service.cycleQuarterly },
  { value: "yearly", label: vi.service.cycleYearly },
  { value: "per_visit", label: vi.service.cyclePerVisit },
] as const;

const STATUS_OPTIONS = [
  { value: "draft", label: vi.service.statusDraft },
  { value: "active", label: vi.service.statusActive },
  { value: "suspended", label: vi.service.statusSuspended },
  { value: "expired", label: vi.service.statusExpired },
  { value: "cancelled", label: vi.service.statusCancelled },
] as const;

/**
 * Form tạo / sửa hợp đồng dịch vụ (T-042, RPC `service_contract_save`).
 * NCC chỉ lấy loại đang hoạt động; khoản mục + trung tâm chi phí lấy
 * theo tổ chức của khách sạn.
 */
export function ContractForm({
  propertyId,
  contract,
  suppliers,
  expenseCategories,
  costCenters,
}: {
  propertyId: string;
  contract: ServiceContractRow | null;
  suppliers: SupplierRow[];
  expenseCategories: ExpenseCategoryRow[];
  costCenters: CostCenterRow[];
}) {
  const router = useRouter();
  const [title, setTitle] = useState(contract?.title ?? "");
  const [supplierId, setSupplierId] = useState(contract?.supplier_id ?? "");
  const [expenseCategoryId, setExpenseCategoryId] = useState(
    contract?.expense_category_id ?? "",
  );
  const [costCenterId, setCostCenterId] = useState(
    contract?.cost_center_id ?? "",
  );
  const [startDate, setStartDate] = useState(contract?.start_date ?? "");
  const [endDate, setEndDate] = useState(contract?.end_date ?? "");
  const [billingCycle, setBillingCycle] = useState<
    "monthly" | "quarterly" | "yearly" | "per_visit"
  >(contract?.billing_cycle ?? "monthly");
  const [amount, setAmount] = useState(
    contract ? String(contract.amount_per_cycle) : "",
  );
  const [renewNoticeDays, setRenewNoticeDays] = useState(
    String(contract?.renew_notice_days ?? 30),
  );
  const [status, setStatus] = useState<
    "draft" | "active" | "suspended" | "expired" | "cancelled"
  >(contract?.status ?? "active");
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSubmit =
    !pending &&
    title.trim() !== "" &&
    supplierId !== "" &&
    expenseCategoryId !== "" &&
    costCenterId !== "" &&
    startDate !== "" &&
    amount !== "" &&
    Number(amount) >= 0 &&
    (endDate === "" || endDate >= startDate);

  async function handleSubmit() {
    setPending(true);
    setError(null);
    const res = await saveContractAction({
      propertyId,
      contractId: contract?.id ?? null,
      title: title.trim(),
      supplierId,
      expenseCategoryId,
      costCenterId,
      startDate,
      endDate: endDate || null,
      billingCycle,
      amountPerCycle: Number(amount),
      renewNoticeDays: Number(renewNoticeDays),
      status,
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    router.push(`/${propertyId}/procurement/service-contracts/${res.data.id}`);
    router.refresh();
  }

  return (
    <div className="space-y-4 rounded-lg border bg-card p-4">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="block text-sm sm:col-span-2">
          {vi.service.contractTitle}
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.finance.supplier}
          <select
            value={supplierId}
            onChange={(e) => setSupplierId(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          >
            <option value="">{vi.finance.selectSupplier}</option>
            {suppliers
              .filter((s) => s.status === "active")
              .map((s) => (
                <option key={s.id} value={s.id}>
                  {s.name} ({s.code})
                </option>
              ))}
          </select>
        </label>
        <label className="block text-sm">
          {vi.service.billingCycle}
          <select
            value={billingCycle}
            onChange={(e) =>
              setBillingCycle(
                e.target.value as
                  "monthly" | "quarterly" | "yearly" | "per_visit",
              )
            }
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          >
            {CYCLE_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          {vi.service.expenseCategory}
          <select
            value={expenseCategoryId}
            onChange={(e) => setExpenseCategoryId(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          >
            <option value="">{vi.service.selectExpenseCategory}</option>
            {expenseCategories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.code} — {c.name}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          {vi.service.costCenter}
          <select
            value={costCenterId}
            onChange={(e) => setCostCenterId(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          >
            <option value="">{vi.service.selectCostCenter}</option>
            {costCenters.map((c) => (
              <option key={c.id} value={c.id}>
                {c.code} — {c.name}
              </option>
            ))}
          </select>
        </label>
        <label className="block text-sm">
          {vi.service.startDate}
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.service.endDate}
          <input
            type="date"
            value={endDate}
            min={startDate || undefined}
            onChange={(e) => setEndDate(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.service.amountPerCycle}
          <input
            type="number"
            min={0}
            step="1000"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.service.renewNoticeDays}
          <input
            type="number"
            min={0}
            step={1}
            value={renewNoticeDays}
            onChange={(e) => setRenewNoticeDays(e.target.value)}
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          />
        </label>
        <label className="block text-sm">
          {vi.common.status}
          <select
            value={status}
            onChange={(e) =>
              setStatus(
                e.target.value as
                  "draft" | "active" | "suspended" | "expired" | "cancelled",
              )
            }
            className="mt-1 w-full rounded-md border bg-background px-3 py-2 text-sm"
          >
            {STATUS_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </label>
      </div>

      {endDate !== "" && endDate < startDate ? (
        <p className="text-sm text-destructive">{vi.service.endBeforeStart}</p>
      ) : null}

      {error ? (
        <p role="alert" className="text-sm font-medium text-red-800">
          {error}
        </p>
      ) : null}

      <div className="flex gap-2">
        <Button type="button" disabled={!canSubmit} onClick={handleSubmit}>
          {pending ? vi.common.loading : vi.common.save}
        </Button>
        <Button
          type="button"
          variant="outline"
          onClick={() =>
            router.push(`/${propertyId}/procurement/service-contracts`)
          }
        >
          {vi.common.cancel}
        </Button>
      </div>
    </div>
  );
}
