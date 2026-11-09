import Link from "next/link";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { getPurposeIssueAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";

/** Chi tiết xuất mục đích (T-031) — chỉ xem. Giá vốn chỉ hiện khi RPC trả (có stock.view_value). */
export default async function PurposeIssueDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id } = await params;
  const res = await getPurposeIssueAction(id);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const doc = res.data;
  const showValue = doc.lines.some((line) => line.unit_cost !== null);

  function purposeLabel(code: string): string {
    return (
      vi.inventory.purposeCodes[
        code as keyof typeof vi.inventory.purposeCodes
      ] ?? code
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <Link
        href={`/${propertyId}/inventory/issues`}
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
          <dt className="text-muted-foreground">{vi.inventory.purpose}</dt>
          <dd className="font-medium">{purposeLabel(doc.purpose_code)}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{vi.inventory.warehouse}</dt>
          <dd className="font-medium">{doc.warehouse_name ?? "—"}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{vi.inventory.costCenter}</dt>
          <dd className="font-medium">{doc.cost_center_name ?? "—"}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">
            {vi.inventory.expenseCategory}
          </dt>
          <dd className="font-medium">{doc.expense_category_name ?? "—"}</dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{vi.inventory.note}</dt>
          <dd className="font-medium">{doc.note ?? "—"}</dd>
        </div>
      </dl>

      {doc.lines.length === 0 ? (
        <EmptyState
          title={vi.inventory.issueDetailTitle}
          description={vi.inventory.issuesEmpty}
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
                <th className="px-4 py-3 font-medium">{vi.inventory.lot}</th>
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
                  <td className="px-4 py-3">{line.uom}</td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(line.qty)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(line.qty_stock)}
                  </td>
                  <td className="px-4 py-3">{line.lot_no ?? "—"}</td>
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
    </div>
  );
}
