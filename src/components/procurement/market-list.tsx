"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { MoneyText } from "@/components/common/money-text";
import { PageHeader } from "@/components/shell/page-header";
import { buildMarketListSearch } from "@/features/procurement/market-list-params";
import type { PoRow } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";

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

/**
 * Danh sach lenh mua cho (C6): PO co `channel = 'market'` (loc o RPC
 * `po_list` qua `p_channel`, khong loc o client). Chi tiet mo o trang
 * chi tiet PO chung; tao moi o `/procurement/market/new`.
 */
export function MarketList({
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

    router.push(
      `/${propertyId}/procurement/market${buildMarketListSearch({
        search: s,
        status: st,
        page: p,
      })}`,
    );
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
      key: "order_date",
      header: vi.procurement.po.orderDate,
      cell: (row) => new Date(row.order_date).toLocaleDateString("vi-VN"),
    },
    {
      key: "expected_date",
      header: vi.procurement.po.expectedDate,
      cell: (row) =>
        row.expected_date
          ? new Date(row.expected_date).toLocaleDateString("vi-VN")
          : "—",
    },
    {
      key: "total_amount",
      header: vi.procurement.po.totalAmount,
      align: "right",
      cell: (row) =>
        row.total_amount > 0 ? (
          <MoneyText amount={row.total_amount} />
        ) : (
          <span className="text-xs text-muted-foreground">
            {vi.procurement.list.priceNotSet}
          </span>
        ),
    },
    {
      key: "line_count",
      header: vi.procurement.list.lines,
      align: "right",
      cell: (row) => String(row.line_count),
    },
    {
      key: "received_qty_stock",
      header: vi.procurement.detail.receivedQty,
      align: "right",
      cell: (row) => String(row.received_qty_stock),
    },
    {
      key: "created_by_name",
      header: vi.procurement.list.createdBy,
      cell: (row) => row.created_by_name ?? "—",
    },
    {
      key: "status",
      header: vi.procurement.list.status,
      cell: (row) => <DocStatusBadge status={row.status} />,
    },
  ];

  return (
    <div className="space-y-4">
      <PageHeader
        title={vi.procurement.market.listTitle}
        actions={
          <Link
            href={`/${propertyId}/procurement/market/new`}
            className="inline-flex h-9 items-center justify-center gap-1.5 rounded-lg bg-primary px-4 text-sm font-medium whitespace-nowrap text-primary-foreground"
          >
            {vi.procurement.market.create}
          </Link>
        }
      />

      <div className="flex gap-2 flex-wrap">
        <div className="relative min-w-52 flex-1">
          <Search
            className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
            aria-hidden
          />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter") applyFilters({});
            }}
            placeholder={vi.procurement.list.searchPlaceholder}
            aria-label={vi.procurement.list.searchPlaceholder}
            className="h-9 w-full rounded-md border bg-background pr-3 pl-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </div>
        <select
          value={currentStatus}
          onChange={(e) => applyFilters({ status: e.target.value })}
          aria-label={vi.procurement.list.filterAllStatuses}
          className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          <option value="">{vi.procurement.list.filterAllStatuses}</option>
          {PO_STATUSES.map((s) => (
            <option key={s} value={s}>
              {poStatusLabel(s)}
            </option>
          ))}
        </select>
        <Button variant="outline" size="lg" onClick={() => applyFilters({})}>
          {vi.common.search}
        </Button>
      </div>

      <DataTable
        columns={columns}
        rows={initialPos}
        emptyTitle={vi.procurement.market.empty}
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
