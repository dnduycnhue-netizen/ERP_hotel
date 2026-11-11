import Link from "next/link";
import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import { shiftLabel } from "@/components/trolley/trolley-utils";
import {
  getTrolleyPerms,
  getTrolleyShift,
  listTrolleyRooms,
} from "@/features/trolley/queries";
import { createClient, getAuthenticatedUserId } from "@/lib/supabase/server";
import type { RoomCleanType } from "@/features/housekeeping/schemas";
import { ShiftConsumptionTable, ShiftCountTable } from "./shift-detail-tables";

/**
 * Chi tiết 1 ca xe đẩy desktop (C7): số đếm đầu/cuối ca + bảng tiêu
 * hao (đầu + lĩnh − cuối, âm clamp 0) qua RPC `trolley_shift_get`
 * (390000) — cùng nguồn với màn mobile, không đọc trực tiếp
 * `stock_counts` / `purpose_issues`.
 */
export default async function TrolleyShiftDetailPage({
  params,
}: {
  params: Promise<{ property: string; shiftId: string }>;
}) {
  const { property: propertyId, shiftId } = await params;

  const perms = await getTrolleyPerms(propertyId);
  if (!perms.canOperate && !perms.canManageStandard) {
    notFound();
  }

  const supabase = await createClient();
  const [detailRes, currentUserId, roomsRes] = await Promise.all([
    getTrolleyShift(shiftId),
    getAuthenticatedUserId(supabase),
    listTrolleyRooms(propertyId),
  ]);
  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }
  if (!roomsRes.ok) {
    return <ErrorState description={roomsRes.error} />;
  }
  const detail = detailRes.data;
  if (detail.shift.property_id !== propertyId) {
    notFound();
  }
  const shift = detail.shift;
  const roomNoById = new Map(
    roomsRes.data.map((room) => [room.id, room.room_no] as const),
  );

  const attendantLabel =
    currentUserId && shift.attendant_id === currentUserId
      ? vi.housekeeping.you
      : shift.attendant_id.slice(0, 8);

  return (
    <div className="space-y-6">
      <Link
        href={`/${propertyId}/housekeeping/trolleys`}
        className="text-sm font-medium text-primary underline"
      >
        ← {vi.housekeeping.backToTrolleys}
      </Link>

      <PageHeader
        title={vi.housekeeping.shiftDetailTitle}
        description={`${shift.trolley_name ?? shift.trolley_code ?? ""} · ${shift.business_date} · ${shiftLabel(shift.shift)}`}
      />

      <section className="flex flex-wrap items-center gap-x-6 gap-y-2 rounded-lg border bg-card p-4 text-sm">
        <span>
          {vi.common.status}: <DocStatusBadge status={shift.status} />
        </span>
        <span>
          {vi.housekeeping.attendant}:{" "}
          <span title={shift.attendant_id}>{attendantLabel}</span>
        </span>
        <span>
          {vi.trolley.topUpRequisition}:{" "}
          {shift.requisition_doc_no ?? vi.trolley.noTopUpRequisition}
        </span>
        <span>
          {vi.trolley.purposeIssue}:{" "}
          {shift.purpose_issue_doc_no ?? vi.common.noData}
        </span>
        {shift.closed_at ? (
          <span>
            {vi.components.docStatus.closed}: {shift.closed_at}
          </span>
        ) : null}
      </section>

      {shift.rooms_done.length > 0 ? (
        <section className="space-y-3">
          <h2 className="text-lg font-semibold">{vi.housekeeping.roomsDone}</h2>
          <ul className="flex flex-col gap-2">
            {shift.rooms_done.map((room, index) => (
              <li
                key={`${room.room_id}-${index}`}
                className="rounded-lg border bg-card p-4 text-sm"
              >
                {vi.minibar.roomNo}{" "}
                {roomNoById.get(room.room_id) ?? room.room_id} ·{" "}
                {vi.housekeeping.cleanTypes[room.clean_type as RoomCleanType]}
                {typeof room.guests === "number"
                  ? ` · ${room.guests} ${vi.trolley.guestsShort}`
                  : ""}
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">
          {vi.housekeeping.openingCounts}
        </h2>
        <ShiftCountTable
          rows={detail.opening_counts.map((line) => ({
            ...line,
            id: line.item_id,
          }))}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">
          {vi.housekeeping.closingCounts}
        </h2>
        {detail.closing_counts === null ? (
          <EmptyState title={vi.housekeeping.notClosedYet} />
        ) : (
          <ShiftCountTable
            rows={detail.closing_counts.map((line) => ({
              ...line,
              id: line.item_id,
            }))}
          />
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">
          {vi.housekeeping.consumptionTitle}
        </h2>
        {detail.consumption.length === 0 ? (
          <EmptyState title={vi.housekeeping.notClosedYet} />
        ) : (
          <ShiftConsumptionTable
            rows={detail.consumption.map((line) => ({
              ...line,
              id: line.item_id,
            }))}
          />
        )}
      </section>
    </div>
  );
}
