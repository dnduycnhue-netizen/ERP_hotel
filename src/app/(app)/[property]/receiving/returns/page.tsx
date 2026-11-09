import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { EmptyState } from "@/components/common/empty-state";
import { listSupplierReturnsAction } from "@/features/receiving/actions";
import { vi } from "@/i18n/vi";

/**
 * Danh sách phiếu trả hàng NCC trên desktop (T-026) — chỉ xem để soát
 * (gm/kế toán chi phí). Xác nhận NCC đã lấy hàng / hủy phiếu làm trên
 * mobile hiện trường (`/m/[p]/receive/returns/[retId]`).
 */
export default async function DesktopReturnsPage({
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

  const res = await listSupplierReturnsAction({
    propertyId,
    status:
      status === "recorded" || status === "posted" || status === "cancelled"
        ? status
        : null,
    limit: pageSize,
    offset: (page - 1) * pageSize,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const { returns, total } = res.data;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  function statusLabel(value: string): string {
    if (value === "posted") {
      return vi.receiving.returnPosted;
    }
    if (value === "cancelled") {
      return vi.components.docStatus.cancelled;
    }
    return vi.receiving.returnRecorded;
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold">
        {vi.receiving.returnsListTitle}
      </h1>

      <div className="flex gap-2">
        {(
          [
            ["", vi.common.all],
            ["recorded", vi.receiving.returnRecorded],
            ["posted", vi.receiving.returnPosted],
            ["cancelled", vi.components.docStatus.cancelled],
          ] as const
        ).map(([value, label]) => (
          <Link
            key={value}
            href={`/${propertyId}/receiving/returns${value ? `?status=${value}` : ""}`}
            aria-current={status === value ? "page" : undefined}
            className={`rounded-lg border px-3 py-1.5 text-sm font-medium ${
              status === value
                ? "bg-primary text-primary-foreground"
                : "bg-card hover:border-ring"
            }`}
          >
            {label}
          </Link>
        ))}
      </div>

      <p className="text-sm text-muted-foreground">
        {total} {vi.receiving.returnsListTitle.toLowerCase()}
      </p>

      {returns.length === 0 ? (
        <EmptyState
          title={vi.receiving.returnsListTitle}
          description={vi.receiving.returnsEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-4 py-3 font-medium">
                  {vi.receiving.returnDocNo}
                </th>
                <th className="px-4 py-3 font-medium">{vi.common.status}</th>
                <th className="px-4 py-3 font-medium">
                  {vi.receiving.supplier}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.receiving.returnGrDocNo}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.receiving.returnQty}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.receiving.totalAmount}
                </th>
              </tr>
            </thead>
            <tbody>
              {returns.map((ret) => (
                <tr key={ret.id} className="border-b last:border-b-0">
                  <td className="px-4 py-3">
                    <Link
                      href={`/${propertyId}/receiving/returns/${ret.id}`}
                      className="font-medium hover:underline"
                    >
                      {ret.doc_no}
                    </Link>
                  </td>
                  <td className="px-4 py-3">{statusLabel(ret.status)}</td>
                  <td className="px-4 py-3">{ret.supplier_name}</td>
                  <td className="px-4 py-3">{ret.gr_doc_no ?? "—"}</td>
                  <td className="px-4 py-3 text-right">
                    {ret.total_qty_stock}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {ret.total_amount === null
                      ? vi.common.noData
                      : ret.total_amount.toLocaleString("vi-VN")}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {totalPages > 1 ? (
        <div className="flex items-center gap-2 text-sm">
          {page > 1 ? (
            <Link
              href={`/${propertyId}/receiving/returns?page=${page - 1}${status ? `&status=${status}` : ""}`}
              className="rounded-lg border bg-card px-3 py-1.5 hover:border-ring"
            >
              ← {vi.common.back}
            </Link>
          ) : null}
          <span className="text-muted-foreground">
            {page} / {totalPages}
          </span>
          {page < totalPages ? (
            <Link
              href={`/${propertyId}/receiving/returns?page=${page + 1}${status ? `&status=${status}` : ""}`}
              className="rounded-lg border bg-card px-3 py-1.5 hover:border-ring"
            >
              {vi.common.next} →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
