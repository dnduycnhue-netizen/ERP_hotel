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
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import type { PrRow } from "@/features/procurement/queries";

const PR_STATUSES = [
  "draft",
  "submitted",
  "approved",
  "rejected",
  "converted",
  "cancelled",
] as const;

function prStatusLabel(status: string): string {
  switch (status) {
    case "draft":
      return vi.procurement.pr.statusDraft;
    case "submitted":
      return vi.procurement.pr.statusSubmitted;
    case "approved":
      return vi.procurement.pr.statusApproved;
    case "rejected":
      return vi.procurement.pr.statusRejected;
    case "converted":
      return vi.procurement.pr.statusConverted;
    case "cancelled":
      return vi.procurement.pr.statusCancelled;
    default:
      return status;
  }
}

/** Danh sách yêu cầu mua (T-021): lọc theo trạng thái/từ khóa, phân trang qua URL. */
export function PrList({
  propertyId,
  initialPrs,
  total,
  currentSearch,
  currentStatus,
  currentPage,
  pageSize,
}: {
  propertyId: string;
  initialPrs: PrRow[];
  total: number;
  currentSearch: string;
  currentStatus: string;
  currentPage: number;
  pageSize: number;
}) {
  const router = useRouter();
  const canCreate = useCan("pr.create");
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

    router.push(`/${propertyId}/procurement/pr?${query.toString()}`);
  }

  const columns: DataTableColumn<PrRow>[] = [
    {
      key: "doc_no",
      header: vi.procurement.pr.docNo,
      cell: (row) => (
        <Link
          href={`/${propertyId}/procurement/pr/${row.id}`}
          className="font-mono text-xs font-bold text-primary hover:underline"
        >
          {row.doc_no}
        </Link>
      ),
    },
    {
      key: "kind",
      header: vi.procurement.pr.kind,
      cell: (row) =>
        row.kind === "service"
          ? vi.procurement.pr.kindService
          : vi.procurement.pr.kindStock,
    },
    {
      key: "outlet_name",
      header: vi.procurement.pr.outlet,
      cell: (row) => row.outlet_name ?? "—",
    },
    {
      key: "need_date",
      header: vi.procurement.pr.needDate,
      cell: (row) =>
        row.need_date
          ? new Date(row.need_date).toLocaleDateString("vi-VN")
          : "—",
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
    {
      key: "created_at",
      header: vi.procurement.list.createdAt,
      cell: (row) => new Date(row.created_at).toLocaleDateString("vi-VN"),
    },
  ];

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h2 className="text-lg font-semibold">
            {vi.procurement.pr.listTitle}
          </h2>
        </div>
        {canCreate ? (
          <Button
            size="sm"
            onClick={() => router.push(`/${propertyId}/procurement/pr/new`)}
          >
            + {vi.procurement.pr.createTitle}
          </Button>
        ) : null}
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
          {PR_STATUSES.map((s) => (
            <option key={s} value={s}>
              {prStatusLabel(s)}
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
        rows={initialPrs}
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
