import Link from "next/link";
import { notFound } from "next/navigation";
import { AttachmentGallery } from "@/components/common/attachment-gallery";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { ErrorState } from "@/components/common/error-state";
import { PhotoReviewForm } from "@/components/receiving/photo-review-form";
import { getPhotoReviewAction } from "@/features/receiving/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

function formatDateTime(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" });
}

/**
 * Chi tiết hậu kiểm ảnh 1 phiếu nhận (C2, M04): xem ảnh full-size qua
 * `AttachmentGallery` (ảnh đăng ký doc_type `receiving`, doc_id = id
 * phiếu), xem dòng hàng + số ảnh từng dòng, duyệt / từ chối theo phiếu.
 * Không hiện giá tiền — hậu kiểm chỉ xem ảnh.
 */
export default async function PhotoReviewDetailPage({
  params,
}: {
  params: Promise<{ property: string; grId: string }>;
}) {
  const { property: propertyId, grId } = await params;

  const res = await getPhotoReviewAction(grId);

  if (!res.ok) {
    // receiving_get_photo_review chi ra ERR_INVALID_VALUE khi khong tim
    // thay phieu (theo quy uoc cua module receiving, T-023).
    if (res.error.includes("ERR_INVALID_VALUE")) {
      notFound();
    }
    return <ErrorState description={res.error} />;
  }

  const detail = res.data;

  function qcLabel(value: string): string {
    if (value === "fail") {
      return vi.receiving.qcFail;
    }
    if (value === "conditional") {
      return vi.receiving.qcConditional;
    }
    return vi.receiving.qcPass;
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center gap-3">
        <Link
          href={`/${propertyId}/receiving/review`}
          className="text-sm text-muted-foreground hover:underline"
        >
          ← {vi.receiving.photoReviewTitle}
        </Link>
      </div>
      <PageHeader
        title={`${vi.receiving.photoReviewDetailTitle}: ${detail.doc_no}`}
      />

      <section className="rounded-lg border bg-card p-4">
        <dl className="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">{vi.common.status}</dt>
            <dd>
              <DocStatusBadge status={detail.status} />
            </dd>
          </div>
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">{vi.receiving.supplier}</dt>
            <dd>{detail.supplier_name}</dd>
          </div>
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">{vi.receiving.receivedAt}</dt>
            <dd>{formatDateTime(detail.received_at)}</dd>
          </div>
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">
              {vi.receiving.photoReviewPhotoCount}
            </dt>
            <dd className="font-medium">{detail.photo_count}</dd>
          </div>
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">
              {vi.receiving.photoReviewTitle}
            </dt>
            <dd>
              <DocStatusBadge status={detail.photo_review_status} />
            </dd>
          </div>
          {detail.photo_reviewed_at ? (
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted-foreground">
                {vi.receiving.photoReviewReviewedAt}
              </dt>
              <dd>{formatDateTime(detail.photo_reviewed_at)}</dd>
            </div>
          ) : null}
          {detail.photo_review_reason ? (
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted-foreground">
                {vi.receiving.photoReviewReason}
              </dt>
              <dd>{detail.photo_review_reason}</dd>
            </div>
          ) : null}
        </dl>
      </section>

      <section className="rounded-lg border bg-card p-4">
        <h2 className="mb-3 text-sm font-semibold">
          {vi.receiving.photoReviewPhotos} ({detail.photo_count})
        </h2>
        <AttachmentGallery
          propertyId={propertyId}
          docType="receiving"
          docId={detail.id}
        />
      </section>

      <section className="rounded-lg border bg-card p-4">
        <h2 className="mb-3 text-sm font-semibold">
          {vi.receiving.photoReviewLinesTitle}
        </h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.itemName}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.qcStatus}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.receiving.photoReviewPhotoCount}
                </th>
              </tr>
            </thead>
            <tbody>
              {detail.lines.map((line) => (
                <tr key={line.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 align-middle">{line.item_name}</td>
                  <td className="px-3 py-3 align-middle">
                    {qcLabel(line.qc_status)}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    {line.photo_count}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {detail.photo_review_status === "pending" ? (
        <section className="rounded-lg border bg-card p-4">
          <PhotoReviewForm grId={detail.id} />
        </section>
      ) : null}
    </div>
  );
}
