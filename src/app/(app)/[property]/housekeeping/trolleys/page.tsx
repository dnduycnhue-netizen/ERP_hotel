import Link from "next/link";
import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import { shiftLabel } from "@/components/trolley/trolley-utils";
import {
  getTrolleyPerms,
  listTrolleyShifts,
  type TrolleyShiftRow,
  type TrolleyShiftStatus,
} from "@/features/trolley/queries";
import { createClient, getAuthenticatedUserId } from "@/lib/supabase/server";

/**
 * Danh sách ca xe đẩy desktop (C7): trạng thái mở/đóng, nhân viên,
 * tóm tắt tiêu hao (số phòng đã dọn + phiếu lĩnh bù / phiếu tiêu hao),
 * link tới chi tiết ca. Đọc qua `listTrolleyShifts` (RLS trực tiếp,
 * đã có từ T-034/mobile); chi tiết ca qua RPC `trolley_shift_get`.
 *
 * Tên nhân viên: policy `profiles_select` chỉ cho đọc hồ sơ của chính
 * mình (hoặc admin.users.manage) nên chỉ nhận diện được ca của mình
 * ("Bạn"), ca khác hiện mã định danh rút gọn.
 */
export default async function TrolleysPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ status?: string; date?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;

  const perms = await getTrolleyPerms(propertyId);
  if (!perms.canOperate && !perms.canManageStandard) {
    notFound();
  }

  const statusFilter =
    sp.status === "open" || sp.status === "closed" || sp.status === "cancelled"
      ? (sp.status as TrolleyShiftStatus)
      : undefined;
  const dateFilter =
    sp.date && /^\d{4}-\d{2}-\d{2}$/.test(sp.date) ? sp.date : undefined;

  const supabase = await createClient();
  const [shiftsRes, currentUserId] = await Promise.all([
    listTrolleyShifts(
      propertyId,
      { status: statusFilter, businessDate: dateFilter },
      50,
    ),
    getAuthenticatedUserId(supabase),
  ]);
  if (!shiftsRes.ok) {
    return <ErrorState description={shiftsRes.error} />;
  }

  function attendantLabel(attendantId: string): string {
    if (currentUserId && attendantId === currentUserId) {
      return vi.housekeeping.you;
    }
    return attendantId.slice(0, 8);
  }

  const columns: DataTableColumn<TrolleyShiftRow>[] = [
    {
      key: "business_date",
      header: vi.housekeeping.businessDate,
      cell: (row) => row.business_date,
    },
    {
      key: "shift",
      header: vi.housekeeping.shift,
      cell: (row) => shiftLabel(row.shift),
    },
    {
      key: "trolley",
      header: vi.housekeeping.trolleyWarehouse,
      cell: (row) => row.trolley_name ?? row.trolley_code ?? "—",
    },
    {
      key: "attendant",
      header: vi.housekeeping.attendant,
      cell: (row) => (
        <span title={row.attendant_id}>{attendantLabel(row.attendant_id)}</span>
      ),
    },
    {
      key: "status",
      header: vi.common.status,
      cell: (row) => <DocStatusBadge status={row.status} />,
    },
    {
      key: "summary",
      header: vi.housekeeping.roomsDone,
      cell: (row) =>
        [
          `${row.rooms_done.length} ${vi.housekeeping.roomsDoneSummary}`,
          row.requisition_id
            ? vi.housekeeping.topUpNote
            : vi.housekeeping.noTopUpNote,
          row.purpose_issue_id
            ? vi.housekeeping.consumptionNote
            : vi.housekeeping.noConsumptionNote,
        ].join(" · "),
    },
    {
      key: "actions",
      header: vi.common.actions,
      align: "right",
      cell: (row) => (
        <Link
          href={`/${propertyId}/housekeeping/trolleys/${row.id}`}
          className="inline-flex h-7 items-center rounded-md border px-2 text-xs font-medium hover:bg-muted"
        >
          {vi.housekeeping.detail}
        </Link>
      ),
    },
  ];

  return (
    <div className="space-y-4">
      <PageHeader
        title={vi.housekeeping.trolleysTitle}
        description={vi.housekeeping.trolleysDescription}
      />

      <form method="get" className="flex flex-wrap items-end gap-3">
        <div>
          <label
            className="text-xs font-medium text-muted-foreground"
            htmlFor="status"
          >
            {vi.housekeeping.filterStatus}
          </label>
          <select
            id="status"
            name="status"
            defaultValue={statusFilter ?? ""}
            className="mt-1 h-9 rounded-md border bg-background px-3 text-sm"
          >
            <option value="">{vi.common.all}</option>
            <option value="open">{vi.components.docStatus.open}</option>
            <option value="closed">{vi.components.docStatus.closed}</option>
            <option value="cancelled">
              {vi.components.docStatus.cancelled}
            </option>
          </select>
        </div>
        <div>
          <label
            className="text-xs font-medium text-muted-foreground"
            htmlFor="date"
          >
            {vi.housekeeping.filterDate}
          </label>
          <input
            id="date"
            name="date"
            type="date"
            defaultValue={dateFilter ?? ""}
            className="mt-1 h-9 rounded-md border bg-background px-3 text-sm"
          />
        </div>
        <Button type="submit" size="sm" variant="outline">
          {vi.housekeeping.filterButton}
        </Button>
        {statusFilter || dateFilter ? (
          <Link
            href={`/${propertyId}/housekeeping/trolleys`}
            className="inline-flex h-9 items-center rounded-md border px-3 text-sm hover:bg-muted"
          >
            {vi.housekeeping.clearFilter}
          </Link>
        ) : null}
      </form>

      <DataTable
        columns={columns}
        rows={shiftsRes.data}
        emptyTitle={vi.trolley.shiftsEmpty}
      />
    </div>
  );
}
