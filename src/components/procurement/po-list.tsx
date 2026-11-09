"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { MoneyText } from "@/components/common/money-text";
import { vi } from "@/i18n/vi";
import type { PoRow } from "@/features/procurement/queries";

const PO_STATUSES = [
  "draft",
  "submitted",
  "approved",
  "rejected",
  "sent",
  "partially_received",
  "received",
  "closed",
  "cancelled",
] as const;

function poStatusLabel(status: string): string {
  switch (status) {
    case "draft":
      return vi.procurement.po.statusDraft;
    case "submitted":
      return vi.procurement.po.statusSubmitted;
    case "approved":
      return vi.procurement.po.statusApproved;
    case "rejected":
      return vi.procurement.po.statusRejected;
    case "sent":
      return vi.procurement.po.statusSent;
    case "partially_received":
      return vi.procurement.po.statusPartiallyReceived;
    case "received":
      return vi.procurement.po.statusReceived;
    case "closed":
      return vi.procurement.po.statusClosed;
    case "cancelled":
      return vi.procurement.po.statusCancelled;
    default:
      return status;
  }
}

/** Danh sách đơn mua (T-021): lọc theo trạng thái/từ khóa, phân trang qua URL. */
export function PoList({
  propertyId,
  initialPos,
  total,
  currentSearch,
  currentStatus,
  currentPage,
  pageSize,
}: {
  propertyId: string;
  initialPos: PoRow[];
  total: number;
  currentSearch: string;
  currentStatus: string;
  currentPage: number;
  pageSize: number;
}) {
  const router = useRouter();
  const [search, setSearch] = useState(currentSearch);

  function applyFilters(newParams: {
    search?: string;
    status?: string;
    page?: number;
  }) {
    const s = newParams.search !== undefined ? newParams.search : search;
    const st =
      newParams.status !== undefined ? newParams.status : currentStatus;
    const p = newParams.page !== undefined ? newParams.page : 1;

    const query = new URLSearchParams();
    if (s.trim()) query.set("search", s.trim());
    if (st) query.set("status", st);
    if (p > 1) query.set("page", String(p));

    router.push(`/${propertyId}/procurement/po?${query.toString()}`);
  }

  const columns: DataTableColumn<PoRow>[] = [
    {
      key: "doc_no",
      header: vi.procurement.po.docNo,
      cell: (row) => (
        <Link
          href={`/${propertyId}/procurement/po/${row.id}`}
          className="font-mono text-xs font-bold text-primary hover:underline"
        >
          {row.doc_no}
        </Link>
      ),
    },
    {
      key: "supplier_name",
      header: vi.procurement.po.supplier,
      cell: (row) => <span className="font-medium">{row.supplier_name}</span>,
    },
    {
      key: "channel",
      header: vi.procurement.po.channel,
      cell: (row) =>
        row.channel === "contract"
          ? vi.procurement.po.channelContract
          : row.channel === "quote"
            ? vi.procurement.po.channelQuote
            : vi.procurement.po.channelMarket,
    },
    {
      key: "order_date",
      header: vi.procurement.po.orderDate,
      cell: (row) => new Date(row.order_date).toLocaleDateString("vi-VN"),
    },
    {
      key: "total_amount",
      header: vi.procurement.po.totalAmount,
      align: "right",
      cell: (row) => <MoneyText amount={row.total_amount} />,
    },
    {
      key: "line_count",
      header: vi.procurement.list.lines,
      align: "right",
      cell: (row) => String(row.line_count),
    },
    {
      key: "status",
      header: vi.procurement.list.status,
      cell: (row) => <DocStatusBadge status={row.status} />,
    },
  ];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h2 className="text-lg font-semibold">
            {vi.procurement.po.listTitle}
          </h2>
        </div>
      </div>

      <div className="flex gap-2 flex-wrap">
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") applyFilters({});
          }}
          placeholder={vi.procurement.list.searchPlaceholder}
          className="h-9 flex-1 min-w-52 rounded-md border bg-background px-3 text-sm"
        />
        <select
          value={currentStatus}
          onChange={(e) => applyFilters({ status: e.target.value })}
          className="h-9 rounded-md border bg-background px-3 text-sm"
        >
          <option value="">{vi.procurement.list.filterAllStatuses}</option>
          {PO_STATUSES.map((s) => (
            <option key={s} value={s}>
              {poStatusLabel(s)}
            </option>
          ))}
        </select>
        <Button
          variant="outline"
          size="sm"
          className="h-9"
          onClick={() => applyFilters({})}
        >
          {vi.common.search}
        </Button>
      </div>

      <DataTable
        columns={columns}
        rows={initialPos}
        pagination={{
          page: currentPage,
          pageSize,
          total,
          onPageChange: (page) => applyFilters({ page }),
        }}
      />
    </div>
  );
}
