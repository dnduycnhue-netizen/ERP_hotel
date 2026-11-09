import Link from "next/link";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { formatNumber } from "@/components/common/money-text";
import { getTransferAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";

/** Chi tiết điều chuyển (T-031) — chỉ xem. */
export default async function TransferDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id } = await params;
  const res = await getTransferAction(id);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const doc = res.data;

  return (
    <div className="flex flex-col gap-4">
      <Link
        href={`/${propertyId}/inventory/transfers`}
        className="text-sm text-muted-foreground hover:underline"
      >
        ← {vi.common.back}
      </Link>

      <div className="flex flex-wrap items-center gap-3">
        <h1 className="text-2xl font-semibold">{doc.doc_no}</h1>
        <DocStatusBadge status={doc.status} />
      </div>

      <dl className="grid grid-cols-2 gap-x-6 gap-y-2 rounded-xl border bg-card p-4 text-sm sm:grid-cols-3">
        <div>
          <dt className="text-muted-foreground">{vi.inventory.businessDate}</dt>
          <dd className="font-medium">{doc.business_date}</dd>
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
      </dl>

      {doc.lines.length === 0 ? (
        <EmptyState
          title={vi.inventory.transferDetailTitle}
          description={vi.inventory.transfersEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.itemName}
                </th>
                <th className="px-4 py-3 font-medium">{vi.inventory.uom}</th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.qty}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.qtyStock}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.sentQty}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.receivedQty}
                </th>
                <th className="px-4 py-3 font-medium">{vi.inventory.lot}</th>
                <th className="px-4 py-3 font-medium">{vi.inventory.note}</th>
              </tr>
            </thead>
            <tbody>
              {doc.lines.map((line) => (
                <tr key={line.id} className="border-b last:border-b-0">
                  <td className="px-4 py-3 font-medium">{line.item_name}</td>
                  <td className="px-4 py-3">{line.uom}</td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(line.qty)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(line.qty_stock)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(line.sent_qty_stock)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(line.received_qty_stock)}
                  </td>
                  <td className="px-4 py-3">{line.lot_no ?? "—"}</td>
                  <td className="px-4 py-3">{line.note ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
