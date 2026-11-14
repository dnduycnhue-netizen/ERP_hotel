import Link from "next/link";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { getPurposeIssueAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";
import { StockDocActions } from "@/components/inventory/stock-doc-actions";

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

      <PageHeader
        title={doc.doc_no}
        description={<DocStatusBadge status={doc.status} />}
      />

      <StockDocActions
        kind="purpose_issue"
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
          doneOutQty: 0,
          receivedQty: 0,
          note: l.note,
        }))}
      />

      <dl className="grid grid-cols-2 gap-x-6 gap-y-2 rounded-lg border bg-card p-4 text-sm sm:grid-cols-3">
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
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.lot}
                </th>
                {showValue ? (
                  <>
                    <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                      {vi.inventory.unitCost}
                    </th>
                    <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                      {vi.inventory.lineAmount}
                    </th>
                  </>
                ) : null}
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
                  <td className="px-3 py-3 align-middle">
                    {line.lot_no ?? "—"}
                  </td>
                  {showValue ? (
                    <>
                      <td className="px-3 py-3 text-right align-middle">
                        <MoneyText amount={line.unit_cost} />
                      </td>
                      <td className="px-3 py-3 text-right align-middle">
                        <MoneyText amount={line.line_amount} />
                      </td>
                    </>
                  ) : null}
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
