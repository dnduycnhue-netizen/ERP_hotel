"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import type {
  PaymentRequestRow,
  PaymentRequestStatus,
} from "@/features/finance/queries";
import type { SupplierRow } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

const STATUS_LABELS: Record<PaymentRequestStatus, string> = {
  draft: vi.components.docStatus.draft,
  submitted: vi.components.docStatus.submitted,
  approved: vi.components.docStatus.approved,
  paid: vi.components.docStatus.paid,
  cancelled: vi.components.docStatus.cancelled,
};

const STATUS_OPTIONS: Array<{
  value: "" | PaymentRequestStatus;
  label: string;
}> = [
  { value: "", label: vi.common.all },
  { value: "draft", label: STATUS_LABELS.draft },
  { value: "submitted", label: STATUS_LABELS.submitted },
  { value: "approved", label: STATUS_LABELS.approved },
  { value: "paid", label: STATUS_LABELS.paid },
  { value: "cancelled", label: STATUS_LABELS.cancelled },
];

/** Danh sách đề nghị thanh toán (T-041): lọc theo trạng thái + NCC. */
export function PaymentRequestList({
  propertyId,
  requests,
  suppliers,
  canRequestPayment,
  initialStatus = "",
}: {
  propertyId: string;
  requests: PaymentRequestRow[];
  suppliers: SupplierRow[];
  canRequestPayment: boolean;
  initialStatus?: "" | PaymentRequestStatus;
}) {
  const router = useRouter();
  const [status, setStatus] = useState<"" | PaymentRequestStatus>(
    initialStatus,
  );
  const [supplierId, setSupplierId] = useState("");

  const filtered = useMemo(
    () =>
      requests.filter(
        (r) =>
          (status === "" || r.status === status) &&
          (supplierId === "" || r.supplier_id === supplierId),
      ),
    [requests, status, supplierId],
  );

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div className="flex flex-wrap items-end gap-3">
          <label className="block text-sm">
            {vi.common.status}
            <select
              value={status}
              onChange={(e) =>
                setStatus(e.target.value as "" | PaymentRequestStatus)
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
        </div>
        {canRequestPayment ? (
          <Button
            type="button"
            onClick={() =>
              router.push(`/${propertyId}/finance/payment-requests/new`)
            }
          >
            {vi.finance.newPaymentRequest}
          </Button>
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
                  {vi.finance.requestDocNo}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.finance.supplier}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.finance.totalAmount}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.finance.dueDate}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.status}
                </th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr key={r.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 align-middle">
                    <Link
                      href={`/${propertyId}/finance/payment-requests/${r.id}`}
                      className="font-medium hover:underline"
                    >
                      {r.doc_no}
                    </Link>
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {r.supplier_name ?? vi.common.noData}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    <MoneyText amount={r.total} />
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {r.due_date ?? vi.common.noData}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    <DocStatusBadge status={r.status} />
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
