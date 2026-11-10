import Link from "next/link";
import { Search } from "lucide-react";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { DocPagination } from "@/components/inventory/doc-list-controls";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import {
  listInventoryWarehousesAction,
  listStockAction,
} from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/**
 * Tồn kho theo kho + mặt hàng (T-031).
 * Đọc trực tiếp `stock_balances` (RLS chặn theo stock.view_qty /
 * stock.view_value); giá trị tồn chỉ hiện khi có stock.view_value.
 */
export default async function StockPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ warehouse?: string; search?: string; page?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const search = sp.search ?? "";
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const pageSize = 20;

  const [warehousesRes, res] = await Promise.all([
    listInventoryWarehousesAction(propertyId),
    listStockAction({
      propertyId,
      warehouseId: sp.warehouse ?? null,
      search: search === "" ? null : search,
      limit: pageSize,
      offset: (page - 1) * pageSize,
    }),
  ]);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const { rows, total, page_total_value, canViewValue, warehouses } = res.data;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const filterWarehouses = warehousesRes.ok ? warehousesRes.data : warehouses;
  const warehouseId = sp.warehouse ?? "";

  function hrefWith(params: Record<string, string | undefined>): string {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") {
        query.set(key, value);
      }
    }
    const qs = query.toString();
    return `/${propertyId}/inventory/stock${qs ? `?${qs}` : ""}`;
  }

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={vi.inventory.stockTitle} />

      <form method="get" className="flex flex-wrap gap-2">
        <select
          name="warehouse"
          defaultValue={warehouseId}
          aria-label={vi.inventory.warehouse}
          className="h-9 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          <option value="">{vi.inventory.allWarehouses}</option>
          {filterWarehouses.map((warehouse) => (
            <option key={warehouse.id} value={warehouse.id}>
              {warehouse.name}
            </option>
          ))}
        </select>
        <div className="relative w-full max-w-sm flex-1">
          <Search
            className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
            aria-hidden
          />
          <input
            type="search"
            name="search"
            defaultValue={search}
            placeholder={vi.inventory.searchPlaceholder}
            aria-label={vi.inventory.searchPlaceholder}
            className="h-9 w-full rounded-md border bg-background pr-3 pl-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </div>
        <button
          type="submit"
          className="h-9 shrink-0 rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.inventory.filter}
        </button>
      </form>

      <p className="text-sm text-muted-foreground">
        {total} {vi.inventory.stockTitle.toLowerCase()}
      </p>

      {rows.length === 0 ? (
        <EmptyState
          title={vi.inventory.stockTitle}
          description={vi.inventory.stockEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.warehouse}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.itemCode}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.itemName}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.inventory.stockUom}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.inventory.lotCount}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.inventory.stockQty}
                </th>
                {canViewValue ? (
                  <>
                    <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                      {vi.inventory.avgCost}
                    </th>
                    <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                      {vi.inventory.stockValue}
                    </th>
                  </>
                ) : null}
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr
                  key={`${row.warehouse_id}|${row.item_id}`}
                  className="border-t hover:bg-muted/40"
                >
                  <td className="px-3 py-3 align-middle">
                    {row.warehouse_name}
                  </td>
                  <td className="px-3 py-3 align-middle">{row.item_code}</td>
                  <td className="px-3 py-3 align-middle">
                    <Link
                      href={`/${propertyId}/inventory/stock/${row.warehouse_id}/${row.item_id}`}
                      className="font-medium hover:underline"
                    >
                      {row.item_name}
                    </Link>
                  </td>
                  <td className="px-3 py-3 align-middle">{row.stock_uom}</td>
                  <td className="px-3 py-3 text-right align-middle">
                    {row.lot_count === 0 ? "—" : row.lot_count}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    {formatNumber(row.qty)}
                  </td>
                  {canViewValue ? (
                    <>
                      <td className="px-3 py-3 text-right align-middle">
                        <MoneyText amount={row.avg_cost} />
                      </td>
                      <td className="px-3 py-3 text-right align-middle">
                        <MoneyText amount={row.value} />
                      </td>
                    </>
                  ) : null}
                </tr>
              ))}
            </tbody>
            {canViewValue && page_total_value !== null ? (
              <tfoot>
                <tr className="border-t font-medium">
                  <td className="px-3 py-3" colSpan={7}>
                    {vi.inventory.pageTotalValue}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    <MoneyText amount={page_total_value} />
                  </td>
                </tr>
              </tfoot>
            ) : null}
          </table>
        </div>
      )}

      {!canViewValue ? (
        <p className="text-sm text-muted-foreground">
          {vi.inventory.stockCard.noViewValueHint}
        </p>
      ) : null}

      <DocPagination
        page={page}
        totalPages={totalPages}
        hrefForPage={(next) =>
          hrefWith({
            warehouse: warehouseId || undefined,
            search: search || undefined,
            page: String(next),
          })
        }
      />
    </div>
  );
}
