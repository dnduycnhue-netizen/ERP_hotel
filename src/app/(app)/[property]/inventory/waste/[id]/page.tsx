import Link from "next/link";
import { AttachmentGallery } from "@/components/common/attachment-gallery";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { getWasteAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";

/** Chi tiết hủy hàng (T-031) — chỉ xem. Giá trị chỉ hiện khi RPC trả (có stock.view_value). */
export default async function WasteDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id } = await params;
  const res = await getWasteAction(id);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const doc = res.data;
  const showValue = doc.lines.some((line) => line.unit_cost !== null);

  function reasonLabel(code: string): string {
    return (
      vi.inventory.wasteReasons[
        code as keyof typeof vi.inventory.wasteReasons
      ] ?? code
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <Link
        href={`/${propertyId}/inventory/waste`}
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
          <dt className="text-muted-foreground">{vi.inventory.reason}</dt>
          <dd className="font-medium">{reasonLabel(doc.reason_code)}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{vi.inventory.warehouse}</dt>
          <dd className="font-medium">{doc.warehouse_name ?? "—"}</dd>
        </div>
        {doc.total_value !== null ? (
          <div>
            <dt className="text-muted-foreground">{vi.inventory.totalValue}</dt>
            <dd className="font-medium">
              <MoneyText amount={doc.total_value} />
            </dd>
          </div>
        ) : null}
        <div>
          <dt className="text-muted-foreground">{vi.inventory.note}</dt>
          <dd className="font-medium">{doc.note ?? "—"}</dd>
        </div>
      </dl>

      {doc.lines.length === 0 ? (
        <EmptyState
          title={vi.inventory.wasteDetailTitle}
          description={vi.inventory.wasteEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.itemName}
                </th>
                <th className="px-4 py-3 font-medium">{vi.inventory.lot}</th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.qtyStock}
                </th>
                {showValue ? (
                  <>
                    <th className="px-4 py-3 text-right font-medium">
                      {vi.inventory.unitCost}
                    </th>
                    <th className="px-4 py-3 text-right font-medium">
                      {vi.inventory.lineAmount}
                    </th>
                  </>
                ) : null}
                <th className="px-4 py-3 font-medium">{vi.inventory.note}</th>
              </tr>
            </thead>
            <tbody>
              {doc.lines.map((line) => (
                <tr key={line.id} className="border-b last:border-b-0">
                  <td className="px-4 py-3 font-medium">{line.item_name}</td>
                  <td className="px-4 py-3">{line.lot_no ?? "—"}</td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(line.qty_stock)}
                  </td>
                  {showValue ? (
                    <>
                      <td className="px-4 py-3 text-right">
                        <MoneyText amount={line.unit_cost} />
                      </td>
                      <td className="px-4 py-3 text-right">
                        <MoneyText amount={line.line_amount} />
                      </td>
                    </>
                  ) : null}
                  <td className="px-4 py-3">{line.note ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <AttachmentGallery
        propertyId={propertyId}
        docType="waste"
        docId={doc.id}
      />
    </div>
  );
}
