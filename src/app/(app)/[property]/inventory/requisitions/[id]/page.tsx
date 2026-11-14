import Link from "next/link";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { formatNumber } from "@/components/common/money-text";
import { getRequisitionAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import { StockDocActions } from "@/components/inventory/stock-doc-actions";

/** Chi tiết phiếu lĩnh (T-031) — chỉ xem, không sửa (chứng từ đã posted chỉ được reverse). */
export default async function RequisitionDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id } = await params;
  const res = await getRequisitionAction(id);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const doc = res.data;

  return (
    <div className="flex flex-col gap-4">
      <Link
        href={`/${propertyId}/inventory/requisitions`}
        className="text-sm text-muted-foreground hover:underline"
      >
        ← {vi.common.back}
      </Link>

      <PageHeader
        title={doc.doc_no}
        description={<DocStatusBadge status={doc.status} />}
      />

      <StockDocActions
        kind="requisition"
        propertyId={propertyId}
        doc={{
          id: doc.id,
          status: doc.status,
          businessDate: doc.business_date,
          note: doc.note,
        }}
        lines={doc.lines.map((l) => ({
          id: l.id,
          itemId: l.item_id,
          itemName: l.item_name,
          qtyStock: l.qty_stock,
          doneOutQty: l.issued_qty_stock,
          receivedQty: l.received_qty_stock,
          note: l.note,
        }))}
      />

      <dl className="grid grid-cols-2 gap-x-6 gap-y-2 rounded-lg border bg-card p-4 text-sm sm:grid-cols-3">
        <div>
          <dt className="text-muted-foreground">{vi.inventory.businessDate}</dt>
          <dd className="font-medium">{doc.business_date}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{vi.inventory.outlet}</dt>
          <dd className="font-medium">{doc.outlet_name ?? "—"}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">
            {vi.inventory.fromWarehouse}
          </dt>
          <dd className="font-medium">{doc.from_warehouse_name ?? "—"}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{vi.inventory.toWarehouse}</dt>
          <dd className="font-medium">{doc.to_warehouse_name ?? "—"}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{vi.inventory.note}</dt>
          <dd className="font-medium">{doc.note ?? "—"}</dd>
        </div>
        {doc.discrepancy_note ? (
          <div>
            <dt className="text-muted-foreground">
              {vi.inventory.discrepancyNote}
            </dt>
            <dd className="font-medium">{doc.discrepancy_note}</dd>
          </div>
        ) : null}
      </dl>

      {doc.lines.length === 0 ? (
        <EmptyState
          title={vi.inventory.requisitionDetailTitle}
          description={vi.inventory.requisitionsEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.itemName}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.uom}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.inventory.qty}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.inventory.qtyStock}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.inventory.issuedQty}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.inventory.receivedQty}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.lot}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.note}
                </th>
              </tr>
            </thead>
            <tbody>
              {doc.lines.map((line) => (
                <tr key={line.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 font-medium align-middle">
                    {line.item_name}
                  </td>
                  <td className="px-3 py-3 align-middle">{line.uom}</td>
                  <td className="px-3 py-3 text-right align-middle">
                    {formatNumber(line.qty)}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    {formatNumber(line.qty_stock)}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    {formatNumber(line.issued_qty_stock)}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    {formatNumber(line.received_qty_stock)}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {line.lot_no ?? "—"}
                  </td>
                  <td className="px-3 py-3 align-middle">{line.note ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
