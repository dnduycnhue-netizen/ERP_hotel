import Link from "next/link";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { DocPagination } from "@/components/inventory/doc-list-controls";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import {
  listInventoryWarehousesAction,
  listStockAction,
} from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";

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
      <h1 className="text-2xl font-semibold">{vi.inventory.stockTitle}</h1>

      <form method="get" className="flex flex-wrap gap-2">
        <select
          name="warehouse"
          defaultValue={warehouseId}
          className="rounded-lg border bg-card px-3 py-1.5 text-sm outline-none focus:border-ring"
        >
          <option value="">{vi.inventory.allWarehouses}</option>
          {filterWarehouses.map((warehouse) => (
            <option key={warehouse.id} value={warehouse.id}>
              {warehouse.name}
            </option>
          ))}
        </select>
        <input
          type="search"
          name="search"
          defaultValue={search}
          placeholder={vi.inventory.searchPlaceholder}
          className="w-full max-w-sm rounded-lg border bg-card px-3 py-1.5 text-sm outline-none focus:border-ring"
        />
        <button
          type="submit"
          className="rounded-lg border bg-card px-3 py-1.5 text-sm font-medium hover:border-ring"
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
        <div className="overflow-x-auto rounded-xl border bg-card shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.warehouse}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.itemCode}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.itemName}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.stockUom}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.lotCount}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.stockQty}
                </th>
                {canViewValue ? (
                  <>
                    <th className="px-4 py-3 text-right font-medium">
                      {vi.inventory.avgCost}
                    </th>
                    <th className="px-4 py-3 text-right font-medium">
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
                  className="border-b last:border-b-0"
                >
                  <td className="px-4 py-3">{row.warehouse_name}</td>
                  <td className="px-4 py-3">{row.item_code}</td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/${propertyId}/inventory/stock/${row.warehouse_id}/${row.item_id}`}
                      className="font-medium hover:underline"
                    >
                      {row.item_name}
                    </Link>
                  </td>
                  <td className="px-4 py-3">{row.stock_uom}</td>
                  <td className="px-4 py-3 text-right">
                    {row.lot_count === 0 ? "—" : row.lot_count}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(row.qty)}
                  </td>
                  {canViewValue ? (
                    <>
                      <td className="px-4 py-3 text-right">
                        <MoneyText amount={row.avg_cost} />
                      </td>
                      <td className="px-4 py-3 text-right">
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
                  <td className="px-4 py-3" colSpan={7}>
                    {vi.inventory.pageTotalValue}
                  </td>
                  <td className="px-4 py-3 text-right">
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
