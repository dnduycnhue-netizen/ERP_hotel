"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { approveNoInvoiceListingAction } from "@/features/finance/actions";
import type {
  NoInvoiceListingRow,
  NoInvoiceListingStatus,
} from "@/features/finance/queries";
import { vi } from "@/i18n/vi";

const STATUS_LABELS: Record<NoInvoiceListingStatus, string> = {
  draft: vi.components.docStatus.draft,
  approved: vi.components.docStatus.approved,
  cancelled: vi.components.docStatus.cancelled,
};

/**
 * Danh sách bảng kê không hóa đơn (T-041): lọc theo trạng thái + nút
 * duyệt từng bảng (chỉ khi `draft` và có `invoice.approve`). Bảng kê
 * đã duyệt KHÔNG ghi vào sổ công nợ — xem Q71.
 */
export function NoInvoiceList({
  propertyId,
  listings,
  canApproveInvoice,
}: {
  propertyId: string;
  listings: NoInvoiceListingRow[];
  canApproveInvoice: boolean;
}) {
  const router = useRouter();
  const [status, setStatus] = useState<"" | NoInvoiceListingStatus>("");
  const [pendingId, setPendingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);

  const filtered = useMemo(
    () =>
      status === "" ? listings : listings.filter((l) => l.status === status),
    [listings, status],
  );

  async function handleApprove(listingId: string) {
    setPendingId(listingId);
    setError(null);
    setMessage(null);
    const res = await approveNoInvoiceListingAction({
      propertyId,
      listingId,
    });
    setPendingId(null);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setMessage(vi.finance.listingApproved);
    router.refresh();
  }

  return (
    <div className="space-y-4">
      <p className="text-sm text-muted-foreground">
        {vi.finance.listingApproveNote}
      </p>
      <label className="block max-w-xs text-sm">
        {vi.common.status}
        <select
          value={status}
          onChange={(e) =>
            setStatus(e.target.value as "" | NoInvoiceListingStatus)
          }
          className="mt-1 h-9 w-full rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          <option value="">{vi.common.all}</option>
          <option value="draft">{STATUS_LABELS.draft}</option>
          <option value="approved">{STATUS_LABELS.approved}</option>
          <option value="cancelled">{STATUS_LABELS.cancelled}</option>
        </select>
      </label>
      {message ? (
        <p className="text-sm font-medium text-green-800">{message}</p>
      ) : null}
      {error ? (
        <p className="text-sm font-medium text-red-800">{error}</p>
      ) : null}
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
                  {vi.finance.sellerName}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.finance.purchaseDate}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.finance.totalAmount}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.status}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.actions}
                </th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((l) => (
                <tr key={l.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 font-medium align-middle">
                    {l.doc_no}
                  </td>
                  <td className="px-3 py-3 align-middle">{l.seller_name}</td>
                  <td className="px-3 py-3 align-middle">{l.purchase_date}</td>
                  <td className="px-3 py-3 text-right align-middle">
                    <MoneyText amount={l.total} />
                  </td>
                  <td className="px-3 py-3 align-middle">
                    <DocStatusBadge status={l.status} />
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {canApproveInvoice && l.status === "draft" ? (
                      <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        disabled={pendingId !== null}
                        onClick={() => handleApprove(l.id)}
                      >
                        {pendingId === l.id
                          ? vi.common.loading
                          : vi.finance.approveButton}
                      </Button>
                    ) : null}
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
