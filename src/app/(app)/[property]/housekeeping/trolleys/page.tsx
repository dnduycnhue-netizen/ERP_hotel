import Link from "next/link";
import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import {
  getTrolleyPerms,
  listTrolleyShifts,
  type TrolleyShiftStatus,
} from "@/features/trolley/queries";
import { createClient, getAuthenticatedUserId } from "@/lib/supabase/server";
import { TrolleysTable } from "./trolleys-table";

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
            className="mt-1 h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
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
            className="mt-1 h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
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

      <TrolleysTable
        shifts={shiftsRes.data}
        propertyId={propertyId}
        currentUserId={currentUserId}
      />
    </div>
  );
}
