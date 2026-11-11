"use client";

import Link from "next/link";
import { DataTable } from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { shiftLabel } from "@/components/trolley/trolley-utils";
import type { TrolleyShiftRow } from "@/features/trolley/queries";
import { vi } from "@/i18n/vi";

/**
 * Bảng danh sách ca xe đẩy (Q203): cột `cell` là hàm nên phải định
 * nghĩa ở phía client — trang server chỉ được truyền dữ liệu thuần
 * (rows + currentUserId) sang. Truyền hàm từ Server Component sang
 * Client Component làm React nổ lỗi serialize ("Functions cannot be
 * passed directly to Client Components") và trang sập hoàn toàn.
 */
export function TrolleysTable({
  shifts,
  propertyId,
  currentUserId,
}: {
  shifts: TrolleyShiftRow[];
  propertyId: string;
  currentUserId: string | null;
}) {
  function attendantLabel(attendantId: string): string {
    if (currentUserId && attendantId === currentUserId) {
      return vi.housekeeping.you;
    }
    return attendantId.slice(0, 8);
  }

  return (
    <DataTable
      columns={[
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
            <span title={row.attendant_id}>
              {attendantLabel(row.attendant_id)}
            </span>
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
      ]}
      rows={shifts}
      emptyTitle={vi.trolley.shiftsEmpty}
    />
  );
}
