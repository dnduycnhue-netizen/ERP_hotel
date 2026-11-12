"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Search } from "lucide-react";
import { Button } from "@/components/ui/button";
import { PageHeader } from "@/components/shell/page-header";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { MoneyText } from "@/components/common/money-text";
import { vi } from "@/i18n/vi";
import type { AdvanceRow } from "@/features/procurement/queries";

const ADVANCE_STATUSES = [
  "requested",
  "approved",
  "rejected",
  "disbursed",
  "settling",
  "settled",
  "overdue",
] as const;

function advanceStatusLabel(status: string): string {
  switch (status) {
    case "requested":
      return vi.procurement.advances.statusRequested;
    case "approved":
      return vi.procurement.advances.statusApproved;
    case "rejected":
      return vi.procurement.advances.statusRejected;
    case "disbursed":
      return vi.procurement.advances.statusDisbursed;
    case "settling":
      return vi.procurement.advances.statusSettling;
    case "settled":
      return vi.procurement.advances.statusSettled;
    case "overdue":
      return vi.procurement.advances.statusOverdue;
    default:
      return status;
  }
}

/** Danh sách tạm ứng (T-022): lọc theo trạng thái/từ khóa, phân trang qua URL. */
export function AdvanceList({
  propertyId,
  initialAdvances,
  total,
  currentSearch,
  currentStatus,
  currentPage,
  pageSize,
}: {
  propertyId: string;
  initialAdvances: AdvanceRow[];
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

    router.push(`/${propertyId}/procurement/advances?${query.toString()}`);
  }

  const columns: DataTableColumn<AdvanceRow>[] = [
    {
      key: "doc_no",
      header: vi.procurement.advances.docNo,
      cell: (row) => (
        <Link
          href={`/${propertyId}/procurement/advances/${row.id}`}
          className="font-mono text-xs font-bold text-primary hover:underline"
        >
          {row.doc_no}
        </Link>
      ),
    },
    {
      key: "employee_name",
      header: vi.procurement.advances.employee,
      cell: (row) => (
        <span className="font-medium">{row.employee_name ?? "—"}</span>
      ),
    },
    {
      key: "amount",
      header: vi.procurement.advances.amount,
      align: "right",
      cell: (row) => <MoneyText amount={row.amount} />,
    },
    {
      key: "purpose",
      header: vi.procurement.advances.purpose,
      cell: (row) => (
        <span className="line-clamp-2 max-w-72">{row.purpose}</span>
      ),
    },
    {
      key: "po_doc_no",
      header: vi.procurement.advances.linkedPo,
      cell: (row) =>
        row.po_doc_no ? (
          <Link
            href={`/${propertyId}/procurement/po/${row.po_id}`}
            className="font-mono text-xs font-bold text-primary hover:underline"
          >
            {row.po_doc_no}
          </Link>
        ) : (
          <span className="text-muted-foreground">—</span>
        ),
    },
    {
      key: "due_settle_at",
      header: vi.procurement.advances.dueSettleAt,
      cell: (row) =>
        row.due_settle_at
          ? new Date(row.due_settle_at).toLocaleString("vi-VN")
          : "—",
    },
    {
      key: "status",
      header: vi.procurement.list.status,
      cell: (row) => <DocStatusBadge status={row.status} />,
    },
  ];

  return (
    <div className="space-y-4">
      <PageHeader title={vi.procurement.advances.listTitle} />

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
          {ADVANCE_STATUSES.map((s) => (
            <option key={s} value={s}>
              {advanceStatusLabel(s)}
            </option>
          ))}
        </select>
        <Button variant="outline" size="lg" onClick={() => applyFilters({})}>
          {vi.common.search}
        </Button>
      </div>

      <DataTable
        columns={columns}
        rows={initialAdvances}
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
