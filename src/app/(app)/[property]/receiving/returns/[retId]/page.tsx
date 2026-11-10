import Link from "next/link";
import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { getSupplierReturnAction } from "@/features/receiving/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/**
 * Chi tiết phiếu trả hàng NCC trên desktop (T-026) — chỉ xem để soát.
 * Xác nhận NCC đã lấy hàng / hủy phiếu làm trên mobile hiện trường
 * (`/m/[p]/receive/returns/[retId]`).
 */
export default async function DesktopReturnDetailPage({
  params,
}: {
  params: Promise<{ property: string; retId: string }>;
}) {
  const { property: propertyId, retId } = await params;

  const res = await getSupplierReturnAction(retId);

  if (!res.ok) {
    // supplier_return_get chi ra ERR_INVALID_VALUE khi khong tim thay
    // phieu (theo quy uoc cua module receiving, T-023).
    if (res.error.includes("ERR_INVALID_VALUE")) {
      notFound();
    }
    return <ErrorState description={res.error} />;
  }

  const detail = res.data;

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
      <div className="flex items-center gap-3">
        <Link
          href={`/${propertyId}/receiving/returns`}
          className="text-sm text-muted-foreground hover:underline"
        >
          ← {vi.receiving.returnsListTitle}
        </Link>
      </div>
      <PageHeader
        title={`${vi.receiving.returnDetailTitle}: ${detail.doc_no}`}
      />

      <section className="rounded-lg border bg-card p-4">
        <dl className="grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">{vi.common.status}</dt>
            <dd className="font-medium">{statusLabel(detail.status)}</dd>
          </div>
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">{vi.receiving.supplier}</dt>
            <dd>{detail.supplier_name}</dd>
          </div>
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">
              {vi.receiving.returnGrDocNo}
            </dt>
            <dd>{detail.gr_doc_no ?? vi.common.noData}</dd>
          </div>
          <div className="flex justify-between gap-3 sm:block">
            <dt className="text-muted-foreground">
              {vi.receiving.returnPoDocNo}
            </dt>
            <dd>{detail.po_doc_no ?? vi.common.noData}</dd>
          </div>
          {detail.total_amount !== null ? (
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted-foreground">
                {vi.receiving.totalAmount}
              </dt>
              <dd className="font-semibold">
                {detail.total_amount.toLocaleString("vi-VN")}
              </dd>
            </div>
          ) : null}
          {detail.cancel_reason ? (
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted-foreground">
                {vi.receiving.cancelReturnReason}
              </dt>
              <dd>{detail.cancel_reason}</dd>
            </div>
          ) : null}
        </dl>
      </section>

      <section className="rounded-lg border bg-card p-4">
        <h2 className="font-semibold">{vi.receiving.returnLinesTitle}</h2>
        {detail.lines.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.receiving.returnsEmpty}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.receiving.itemName}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.receiving.returnQty}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.receiving.unitCost}
                  </th>
                  <th className="py-2.5 pr-3 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.receiving.lineAmount}
                  </th>
                </tr>
              </thead>
              <tbody>
                {detail.lines.map((line) => (
                  <tr key={line.id} className="border-t hover:bg-muted/40">
                    <td className="py-3 pr-3 align-middle">
                      <p className="font-medium">{line.item_name}</p>
                      {line.reason ? (
                        <p className="text-muted-foreground">
                          {vi.receiving.returnReason}: {line.reason}
                        </p>
                      ) : null}
                    </td>
                    <td className="py-3 pr-3 text-right align-middle">
                      {line.qty_stock}
                    </td>
                    <td className="py-3 pr-3 text-right align-middle">
                      {line.unit_cost === null
                        ? vi.common.noData
                        : line.unit_cost.toLocaleString("vi-VN")}
                    </td>
                    <td className="py-3 pr-3 text-right align-middle">
                      {line.line_amount === null
                        ? vi.common.noData
                        : line.line_amount.toLocaleString("vi-VN")}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <p className="text-sm text-muted-foreground">
        {vi.receiving.confirmReturnTitle} / {vi.receiving.cancelReturnTitle}:{" "}
        {vi.receiving.mobileOnlyNote}
      </p>
    </div>
  );
}
