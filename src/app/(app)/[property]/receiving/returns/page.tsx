import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { EmptyState } from "@/components/common/empty-state";
import { listSupplierReturnsAction } from "@/features/receiving/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

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
      <PageHeader title={vi.receiving.returnsListTitle} />

      <div className="flex flex-wrap gap-1.5">
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
        {total} {vi.receiving.returnsListTitle.toLowerCase()}
      </p>

      {returns.length === 0 ? (
        <EmptyState
          title={vi.receiving.returnsListTitle}
          description={vi.receiving.returnsEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.returnDocNo}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.status}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.supplier}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.returnGrDocNo}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.receiving.returnQty}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.receiving.totalAmount}
                </th>
              </tr>
            </thead>
            <tbody>
              {returns.map((ret) => (
                <tr key={ret.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 align-middle">
                    <Link
                      href={`/${propertyId}/receiving/returns/${ret.id}`}
                      className="font-medium hover:underline"
                    >
                      {ret.doc_no}
                    </Link>
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {statusLabel(ret.status)}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {ret.supplier_name}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {ret.gr_doc_no ?? "—"}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    {ret.total_qty_stock}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
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
              href={`/${propertyId}/receiving/returns?page=${page + 1}${status ? `&status=${status}` : ""}`}
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
