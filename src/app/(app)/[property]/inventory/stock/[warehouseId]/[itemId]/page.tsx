import Link from "next/link";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { getStockCardAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/**
 * Thẻ kho của 1 mặt hàng tại 1 kho (T-031).
 * AC: tổng thẻ kho khớp `stock_moves` và khớp tồn sổ — trang hiện
 * "Tồn cuối theo thẻ" đối chiếu "Tồn sổ (stock_balances)" kèm huy hiệu
 * Khớp/Lệch (chỉ kiểm tra khi xem toàn bộ lịch sử, không lọc ngày).
 */
export default async function StockCardPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string; warehouseId: string; itemId: string }>;
  searchParams: Promise<{ from?: string; to?: string }>;
}) {
  const { property: propertyId, warehouseId, itemId } = await params;
  const sp = await searchParams;
  const from = sp.from ?? "";
  const to = sp.to ?? "";

  const res = await getStockCardAction({
    propertyId,
    warehouseId,
    itemId,
    from: from === "" ? null : from,
    to: to === "" ? null : to,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const card = res.data;
  const strings = vi.inventory.stockCard;

  function moveTypeLabel(moveType: string): string {
    const map: Record<string, string> = {
      opening: vi.inventory.moveTypes.opening,
      receipt: vi.inventory.moveTypes.receipt,
      return_out: vi.inventory.moveTypes.returnOut,
      issue_out: vi.inventory.moveTypes.issueOut,
      issue_in: vi.inventory.moveTypes.issueIn,
      transfer_out: vi.inventory.moveTypes.transferOut,
      transfer_in: vi.inventory.moveTypes.transferIn,
      purpose_issue: vi.inventory.moveTypes.purposeIssue,
      waste: vi.inventory.moveTypes.waste,
      adjust_count: vi.inventory.moveTypes.adjustCount,
      production_out: vi.inventory.moveTypes.productionOut,
      production_in: vi.inventory.moveTypes.productionIn,
      minibar_sale: vi.inventory.moveTypes.minibarSale,
      merge_out: vi.inventory.moveTypes.mergeOut,
      merge_in: vi.inventory.moveTypes.mergeIn,
      reversal: vi.inventory.moveTypes.reversal,
    };
    return map[moveType] ?? moveType;
  }

  function sourceDocLabel(sourceDocType: string): string {
    const map: Record<string, string> = {
      goods_receipt: vi.inventory.sourceDocTypes.goodsReceipt,
      supplier_return: vi.inventory.sourceDocTypes.supplierReturn,
      requisition: vi.inventory.sourceDocTypes.requisition,
      transfer: vi.inventory.sourceDocTypes.transfer,
      purpose_issue: vi.inventory.sourceDocTypes.purposeIssue,
      waste: vi.inventory.sourceDocTypes.waste,
      item_merge: vi.inventory.sourceDocTypes.itemMerge,
      count: vi.inventory.sourceDocTypes.count,
    };
    return map[sourceDocType] ?? sourceDocType;
  }

  function sourceDocHref(
    sourceDocType: string,
    sourceDocId: string,
  ): string | null {
    switch (sourceDocType) {
      case "requisition":
        return `/${propertyId}/inventory/requisitions/${sourceDocId}`;
      case "transfer":
        return `/${propertyId}/inventory/transfers/${sourceDocId}`;
      case "purpose_issue":
        return `/${propertyId}/inventory/issues/${sourceDocId}`;
      case "waste":
        return `/${propertyId}/inventory/waste/${sourceDocId}`;
      case "supplier_return":
        return `/${propertyId}/receiving/returns/${sourceDocId}`;
      default:
        return null;
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <Link
        href={`/${propertyId}/inventory/stock`}
        className="text-sm text-muted-foreground hover:underline"
      >
        ← {vi.common.back}
      </Link>

      <PageHeader
        title={vi.inventory.stockCardTitle}
        description={
          <>
            {card.item.code} — {card.item.name} · {card.warehouse.name} ·{" "}
            {card.item.stock_uom}
          </>
        }
      />

      <form method="get" className="flex flex-wrap items-end gap-2">
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-muted-foreground">{strings.fromDate}</span>
          <input
            type="date"
            name="from"
            defaultValue={from}
            className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-muted-foreground">{strings.toDate}</span>
          <input
            type="date"
            name="to"
            defaultValue={to}
            className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </label>
        <button
          type="submit"
          className="h-9 rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.inventory.filter}
        </button>
        {from !== "" || to !== "" ? (
          <Link
            href={`/${propertyId}/inventory/stock/${warehouseId}/${itemId}`}
            className="inline-flex h-9 items-center rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            {vi.common.all}
          </Link>
        ) : null}
      </form>

      <dl className="grid grid-cols-2 gap-x-6 gap-y-3 rounded-lg border bg-card p-4 text-sm sm:grid-cols-3 lg:grid-cols-5">
        <div>
          <dt className="text-muted-foreground">{strings.opening}</dt>
          <dd className="text-base font-semibold">
            {formatNumber(card.opening)}
          </dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{strings.totalIn}</dt>
          <dd className="text-base font-semibold text-green-700">
            +{formatNumber(card.total_in)}
          </dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{strings.totalOut}</dt>
          <dd className="text-base font-semibold text-red-700">
            −{formatNumber(card.total_out)}
          </dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{strings.closing}</dt>
          <dd className="text-base font-semibold">
            {formatNumber(card.closing)}
          </dd>
        </div>
        <div>
          <dt className="text-muted-foreground">{strings.ledgerQty}</dt>
          <dd className="text-base font-semibold">
            {formatNumber(card.ledger_qty)}
          </dd>
        </div>
      </dl>

      {card.matches === true ? (
        <p className="rounded-lg border border-green-200 bg-green-50 px-3 py-2 text-sm font-medium text-green-800">
          ✓ {strings.matched} ({formatNumber(card.closing)} ={" "}
          {formatNumber(card.ledger_qty)})
        </p>
      ) : null}
      {card.matches === false ? (
        <p className="rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm font-medium text-red-800">
          ⚠ {strings.mismatched}: {formatNumber(card.closing)} ≠{" "}
          {formatNumber(card.ledger_qty)}
        </p>
      ) : null}
      {card.matches === null && card.truncated ? (
        <p className="rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-800">
          {strings.unknownMatch}. {strings.truncatedNote}
        </p>
      ) : null}
      {card.truncated && card.matches !== null ? (
        <p className="text-sm text-muted-foreground">{strings.truncatedNote}</p>
      ) : null}

      {card.moves.length === 0 ? (
        <EmptyState
          title={vi.inventory.stockCardTitle}
          description={strings.noMoves}
        />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.businessDate}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {strings.doc}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {strings.moveType}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.lot}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {strings.inQty}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {strings.outQty}
                </th>
                {card.canViewValue ? (
                  <>
                    <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                      {vi.inventory.unitCost}
                    </th>
                    <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                      {vi.inventory.lineAmount}
                    </th>
                  </>
                ) : null}
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {strings.runningBalance}
                </th>
              </tr>
            </thead>
            <tbody>
              {card.moves.map((move) => {
                const href = sourceDocHref(
                  move.source_doc_type,
                  move.source_doc_id,
                );
                return (
                  <tr key={move.id} className="border-t hover:bg-muted/40">
                    <td className="px-3 py-3 whitespace-nowrap align-middle">
                      {move.business_date}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {href && move.source_doc_no ? (
                        <Link
                          href={href}
                          className="font-medium hover:underline"
                        >
                          {move.source_doc_no}
                        </Link>
                      ) : (
                        <>
                          <span className="font-medium">
                            {move.source_doc_no ??
                              sourceDocLabel(move.source_doc_type)}
                          </span>
                          {move.source_doc_no ? (
                            <span className="block text-xs text-muted-foreground">
                              {sourceDocLabel(move.source_doc_type)}
                            </span>
                          ) : null}
                        </>
                      )}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {moveTypeLabel(move.move_type)}
                      {move.reverses_move_id !== null ? (
                        <span className="block text-xs text-muted-foreground">
                          {strings.reverses} #{move.reverses_move_id}
                        </span>
                      ) : null}
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {move.lot_no ?? "—"}
                      {move.expiry_date ? (
                        <span className="block text-xs text-muted-foreground">
                          {strings.expiryDate}: {move.expiry_date}
                        </span>
                      ) : null}
                    </td>
                    <td className="px-3 py-3 text-right align-middle text-green-700">
                      {move.qty > 0 ? formatNumber(move.qty) : "—"}
                    </td>
                    <td className="px-3 py-3 text-right align-middle text-red-700">
                      {move.qty < 0 ? formatNumber(Math.abs(move.qty)) : "—"}
                    </td>
                    {card.canViewValue ? (
                      <>
                        <td className="px-3 py-3 text-right align-middle">
                          <MoneyText amount={move.unit_cost} />
                        </td>
                        <td className="px-3 py-3 text-right align-middle">
                          <MoneyText amount={move.amount} />
                        </td>
                      </>
                    ) : null}
                    <td className="px-3 py-3 text-right font-medium align-middle">
                      {formatNumber(move.running_balance)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {!card.canViewValue ? (
        <p className="text-sm text-muted-foreground">
          {strings.noViewValueHint}
        </p>
      ) : null}
    </div>
  );
}
