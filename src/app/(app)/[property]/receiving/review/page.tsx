import Link from "next/link";
import { DataTable } from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { listPhotoReviewsAction } from "@/features/receiving/actions";
import type { PhotoReviewListRow } from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

function formatReceivedAt(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" });
}

/**
 * Danh sách phiếu nhận có ảnh chờ hậu kiểm (C2, M04) — duyệt theo phiếu.
 * Chỉ người có `receiving.review_photos` mới liệt kê được (cổng quyền
 * nằm trong RPC `receiving_list_photo_reviews`).
 */
export default async function PhotoReviewListPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ status?: string; page?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const status = sp.status ?? "";
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const pageSize = 20;

  const res = await listPhotoReviewsAction({
    propertyId,
    reviewStatus:
      status === "pending" || status === "approved" || status === "rejected"
        ? status
        : null,
    limit: pageSize,
    offset: (page - 1) * pageSize,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const { reviews, total } = res.data;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={vi.receiving.photoReviewTitle} />

      <div className="flex flex-wrap gap-1.5">
        {(
          [
            ["", vi.common.all],
            ["pending", vi.receiving.photoReviewPending],
            ["approved", vi.receiving.photoReviewApproved],
            ["rejected", vi.receiving.photoReviewRejected],
          ] as const
        ).map(([value, label]) => (
          <Link
            key={value}
            href={`/${propertyId}/receiving/review${value ? `?status=${value}` : ""}`}
            aria-current={status === value ? "page" : undefined}
            className={`rounded-full border px-3 py-1.5 text-sm font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-brand/40 ${
              status === value
                ? "border-brand/40 bg-brand/10 text-brand"
                : "bg-background text-muted-foreground hover:text-foreground"
            }`}
          >
            {label}
          </Link>
        ))}
      </div>

      <p className="text-sm text-muted-foreground">
        {total} {vi.receiving.photoReviewTitle.toLowerCase()}
      </p>

      {reviews.length === 0 ? (
        <EmptyState
          title={vi.receiving.photoReviewTitle}
          description={vi.receiving.photoReviewEmpty}
        />
      ) : (
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
              cell: (row) => (
                <DocStatusBadge status={row.photo_review_status} />
              ),
            },
          ]}
          rows={reviews}
          emptyTitle={vi.receiving.photoReviewTitle}
          emptyDescription={vi.receiving.photoReviewEmpty}
        />
      )}

      {totalPages > 1 ? (
        <div className="flex items-center gap-2 text-sm">
          {page > 1 ? (
            <Link
              href={`/${propertyId}/receiving/review?page=${page - 1}${status ? `&status=${status}` : ""}`}
              className="flex h-9 items-center rounded-md border bg-background px-3 font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
            >
              ← {vi.common.back}
            </Link>
          ) : null}
          <span className="text-muted-foreground">
            {page} / {totalPages}
          </span>
          {page < totalPages ? (
            <Link
              href={`/${propertyId}/receiving/review?page=${page + 1}${status ? `&status=${status}` : ""}`}
              className="flex h-9 items-center rounded-md border bg-background px-3 font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
            >
              {vi.common.next} →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
