"use client";

import Link from "next/link";
import { DataTable } from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import type { PhotoReviewListRow } from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";

function formatReceivedAt(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" });
}

/**
 * Bảng phiếu nhận có ảnh chờ hậu kiểm (Q203): cột `cell` là hàm nên
 * phải định nghĩa ở phía client — trang server chỉ được truyền dữ liệu
 * thuần (rows) sang. Truyền hàm từ Server Component sang Client
 * Component làm React nổ lỗi serialize ("Functions cannot be passed
 * directly to Client Components") và trang sập hoàn toàn.
 */
export function PhotoReviewTable({
  reviews,
  propertyId,
}: {
  reviews: PhotoReviewListRow[];
  propertyId: string;
}) {
  return (
    <DataTable<PhotoReviewListRow>
      columns={[
        {
          key: "doc_no",
          header: vi.receiving.docNo,
          cell: (row) => (
            <Link
              href={`/${propertyId}/receiving/review/${row.id}`}
              className="font-medium hover:underline"
            >
              {row.doc_no}
            </Link>
          ),
        },
        {
          key: "supplier_name",
          header: vi.receiving.supplier,
          cell: (row) => row.supplier_name,
        },
        {
          key: "received_at",
          header: vi.receiving.receivedAt,
          cell: (row) => formatReceivedAt(row.received_at),
        },
        {
          key: "status",
          header: vi.common.status,
          cell: (row) => <DocStatusBadge status={row.status} />,
        },
        {
          key: "photo_count",
          header: vi.receiving.photoReviewPhotoCount,
          align: "right",
          cell: (row) => row.photo_count,
        },
        {
          key: "photo_review_status",
          header: vi.receiving.photoReviewTitle,
          cell: (row) => <DocStatusBadge status={row.photo_review_status} />,
        },
      ]}
      rows={reviews}
      emptyTitle={vi.receiving.photoReviewTitle}
      emptyDescription={vi.receiving.photoReviewEmpty}
    />
  );
}
