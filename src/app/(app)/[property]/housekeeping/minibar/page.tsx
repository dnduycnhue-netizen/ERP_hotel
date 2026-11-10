import { ErrorState } from "@/components/common/error-state";
import { MoneyText, formatNumber } from "@/components/common/money-text";
import { OfficePriceManager } from "@/components/minibar/office-price-manager";
import { OfficeReconcilePanel } from "@/components/minibar/office-reconcile-panel";
import { OfficeRefillForm } from "@/components/minibar/office-refill-form";
import { listRooms } from "@/features/master/queries";
import {
  getMinibarPerms,
  getMinibarReport,
  getRecallList,
  getRoomStocks,
  listMinibarItems,
  listMinibarPrices,
} from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";

/**
 * Màn văn phòng — minibar buồng phòng (T-035): tồn từng phòng, bổ
 * sung theo tầng, bảng giá, đối soát ngày, thu hồi sắp hết hạn, báo
 * cáo. Từng mục chỉ hiện khi user có quyền tương ứng.
 */
export default async function HousekeepingMinibarPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
  const monthStart = `${today.slice(0, 7)}-01`;

  const [
    perms,
    rooms,
    itemsRes,
    pricesRes,
    stocksRes,
    recallRes,
    reportRes,
  ] = await Promise.all([
    getMinibarPerms(propertyId),
    listRooms(propertyId),
    listMinibarItems(propertyId),
    listMinibarPrices(propertyId),
    getRoomStocks(propertyId),
    getRecallList(propertyId, 30),
    getMinibarReport(propertyId, monthStart, today),
  ]);

  if (!itemsRes.ok) {
    return <ErrorState description={itemsRes.error} />;
  }
  if (!pricesRes.ok) {
    return <ErrorState description={pricesRes.error} />;
  }
  if (!stocksRes.ok) {
    return <ErrorState description={stocksRes.error} />;
  }
  if (!recallRes.ok) {
    return <ErrorState description={recallRes.error} />;
  }
  if (!reportRes.ok) {
    return <ErrorState description={reportRes.error} />;
  }

  const stocks = stocksRes.data.rows;
  const stocksByRoom = new Map<string, typeof stocks>();
  for (const row of stocks) {
    const list = stocksByRoom.get(row.room_id) ?? [];
    list.push(row);
    stocksByRoom.set(row.room_id, list);
  }
  const report = reportRes.data;

  return (
    <div className="space-y-8">
      <h1 className="text-xl font-semibold">
        {vi.minibar.housekeepingTitle}
      </h1>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{vi.minibar.stockTitle}</h2>
        {!stocksRes.data.canViewQty ? (
          <p className="rounded-md border border-amber-200 bg-amber-50 px-3 py-2 text-sm text-amber-900">
            {vi.minibar.stockHiddenNote}
          </p>
        ) : stocks.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.minibar.stockEmpty}
          </p>
        ) : (
          <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
            {[...stocksByRoom.entries()].map(([roomId, rows]) => (
              <div key={roomId} className="rounded-xl border bg-card p-4">
                <p className="font-medium">
                  {vi.minibar.roomNo} {rows[0].room_no}
                  {rows[0].floor
                    ? ` · ${vi.minibar.floor} ${rows[0].floor}`
                    : ""}
                </p>
                <ul className="mt-2 space-y-1 text-sm">
                  {rows.map((row) => (
                    <li
                      key={`${row.item_id}`}
                      className="flex items-center justify-between gap-2"
                    >
                      <span>
                        {row.item_name ?? vi.minibar.itemNameHidden}
                        {row.item_code ? ` (${row.item_code})` : ""}
                      </span>
                      <span className="tabular-nums">
                        {formatNumber(row.qty)} {row.stock_uom ?? ""}
                      </span>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        )}
      </section>

      {perms.canRefill ? (
        <OfficeRefillForm
          propertyId={propertyId}
          rooms={rooms}
          items={itemsRes.data}
        />
      ) : null}

      {perms.canPriceManage ? (
        <OfficePriceManager
          propertyId={propertyId}
          items={itemsRes.data}
          prices={pricesRes.data}
        />
      ) : null}

      {perms.canReconcile ? (
        <OfficeReconcilePanel propertyId={propertyId} />
      ) : null}

      <section className="rounded-xl border bg-card p-4">
        <h2 className="font-medium">{vi.minibar.recallTitle}</h2>
        {recallRes.data.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.minibar.recallEmpty}
          </p>
        ) : (
          <table className="mt-3 w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="py-2 pr-2 font-medium">{vi.minibar.roomNo}</th>
                <th className="py-2 pr-2 font-medium">{vi.minibar.itemCode}</th>
                <th className="py-2 pr-2 font-medium">{vi.minibar.lotNo}</th>
                <th className="py-2 pr-2 font-medium">
                  {vi.minibar.expiryDate}
                </th>
                <th className="py-2 pr-2 text-right font-medium">
                  {vi.minibar.daysLeft}
                </th>
                <th className="py-2 text-right font-medium">{vi.minibar.qty}</th>
              </tr>
            </thead>
            <tbody>
              {recallRes.data.map((row) => (
                <tr
                  key={`${row.room_no}-${row.lot_id}`}
                  className="border-b last:border-0"
                >
                  <td className="py-2 pr-2">{row.room_no}</td>
                  <td className="py-2 pr-2">{row.item_code}</td>
                  <td className="py-2 pr-2">{row.lot_no}</td>
                  <td className="py-2 pr-2">{row.expiry_date}</td>
                  <td className="py-2 pr-2 text-right tabular-nums">
                    {row.days_left}
                  </td>
                  <td className="py-2 text-right tabular-nums">
                    {formatNumber(row.qty)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>

      {perms.canViewReport ? (
        <section className="rounded-xl border bg-card p-4">
          <h2 className="font-medium">
            {vi.minibar.reportTitle} — {monthStart} → {today}
          </h2>
          {report.chargedChecks === 0 ? (
            <p className="mt-2 text-sm text-muted-foreground">
              {vi.minibar.reportNoData}
            </p>
          ) : (
            <>
              <dl className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
                <div>
                  <dt className="text-sm text-muted-foreground">
                    {vi.minibar.reportRevenue}
                  </dt>
                  <dd className="text-lg font-semibold">
                    <MoneyText amount={report.revenue} />
                  </dd>
                </div>
                <div>
                  <dt className="text-sm text-muted-foreground">
                    {vi.minibar.reportRoomsChecked}
                  </dt>
                  <dd className="text-lg font-semibold">
                    {formatNumber(report.roomsChecked)}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm text-muted-foreground">
                    {vi.minibar.reportLavieSold}
                  </dt>
                  <dd className="text-lg font-semibold">
                    {formatNumber(report.lavieQty)}
                  </dd>
                </div>
                <div>
                  <dt className="text-sm text-muted-foreground">
                    {vi.minibar.reportLaviePerRoom}
                  </dt>
                  <dd className="text-lg font-semibold">
                    {report.laviePerRoom === null
                      ? vi.common.noData
                      : formatNumber(
                          Math.round(report.laviePerRoom * 100) / 100,
                        )}
                  </dd>
                </div>
              </dl>
              {report.topItems.length > 0 ? (
                <table className="mt-4 w-full text-sm">
                  <thead>
                    <tr className="border-b text-left text-muted-foreground">
                      <th className="py-2 pr-2 font-medium">
                        {vi.minibar.itemName}
                      </th>
                      <th className="py-2 pr-2 text-right font-medium">
                        {vi.minibar.qty}
                      </th>
                      <th className="py-2 text-right font-medium">
                        {vi.minibar.amount}
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {report.topItems.map((item) => (
                      <tr key={item.item_id} className="border-b last:border-0">
                        <td className="py-2 pr-2">
                          {item.item_name ?? vi.minibar.itemNameHidden}
                          {item.item_code ? ` (${item.item_code})` : ""}
                        </td>
                        <td className="py-2 pr-2 text-right tabular-nums">
                          {formatNumber(item.qty)}
                        </td>
                        <td className="py-2 text-right">
                          <MoneyText amount={item.amount} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : null}
            </>
          )}
          <p className="mt-4 text-sm text-muted-foreground">
            {vi.minibar.reportCogsNote}
          </p>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.minibar.reportDasaniNote}
          </p>
        </section>
      ) : null}
    </div>
  );
}
