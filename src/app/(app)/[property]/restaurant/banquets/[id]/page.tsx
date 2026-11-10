import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { formatMoney } from "@/components/common/money-text";
import { BanquetStatusButtons } from "@/components/restaurant/restaurant-actions";
import { BanquetForm } from "@/components/restaurant/banquet-form";
import {
  getBanquet,
  getRestaurantPerms,
  listBanquetHalls,
  listRecipes,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

function banquetDocStatus(status: string) {
  if (status === "new") return "new" as const;
  if (status === "confirmed") return "confirmed" as const;
  if (status === "in_progress") return "in_progress" as const;
  if (status === "completed") return "completed" as const;
  return "cancelled" as const;
}

function depositStatusLabel(status: string) {
  return status === "paid"
    ? vi.restaurant.depositPaid
    : vi.restaurant.depositUnpaid;
}

/** Chi tiết tiệc (M06): thực đơn, chuyển trạng thái, hủy. */
export default async function BanquetDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: banquetId } = await params;

  const [res, recipesRes, hallsRes, perms] = await Promise.all([
    getBanquet(propertyId, banquetId),
    listRecipes(propertyId),
    listBanquetHalls(propertyId),
    getRestaurantPerms(propertyId),
  ]);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  if (!res.data) {
    notFound();
  }
  const banquet = res.data;
  const editable =
    perms.canManageBanquet &&
    (banquet.status === "new" || banquet.status === "confirmed");

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold">
            {banquet.doc_no} — {banquet.customer_name}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {banquet.event_date} · {banquet.start_time}–{banquet.end_time} ·{" "}
            {banquet.hall} · {vi.restaurant.tablesCount}:{" "}
            {banquet.tables_count ?? "—"} · {vi.restaurant.guestsCount}:{" "}
            {banquet.guests_count} · {vi.restaurant.depositAmount}:{" "}
            {formatMoney(banquet.deposit_amount)} (
            {depositStatusLabel(banquet.deposit_status)})
          </p>
          {banquet.customer_phone ? (
            <p className="mt-1 text-sm text-muted-foreground">
              {banquet.customer_phone}
            </p>
          ) : null}
        </div>
        <DocStatusBadge status={banquetDocStatus(banquet.status)} />
      </div>

      {banquet.dishes.length > 0 ? (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-left">
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.dishName}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.saleQty}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.unitPrice}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.saleAmount}
                </th>
              </tr>
            </thead>
            <tbody>
              {banquet.dishes.map((d) => (
                <tr key={d.recipe_id} className="border-b last:border-0">
                  <td className="px-3 py-2">{d.recipe_name}</td>
                  <td className="px-3 py-2 text-right tabular-nums">{d.qty}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {d.unit_price !== null ? formatMoney(d.unit_price) : "—"}
                  </td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {d.qty * (d.unit_price ?? 0) !== 0
                      ? formatMoney(d.qty * (d.unit_price ?? 0))
                      : "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <p className="text-sm text-muted-foreground">
          {vi.restaurant.noDishes}
        </p>
      )}

      {banquet.notes ? (
        <p className="text-sm text-muted-foreground">{banquet.notes}</p>
      ) : null}
      {banquet.cancel_reason ? (
        <p className="text-sm text-muted-foreground">
          {vi.restaurant.cancelReason}: {banquet.cancel_reason}
        </p>
      ) : null}

      {editable ? (
        <BanquetForm
          propertyId={propertyId}
          banquet={banquet}
          recipes={(recipesRes.ok ? recipesRes.data : []).map((r) => ({
            id: r.id,
            code: r.code,
            name: r.name,
            sale_price: r.sale_price,
          }))}
          halls={(hallsRes.ok ? hallsRes.data : []).map((h) => ({
            id: h.id,
            name: h.name,
            capacity: h.capacity,
            is_active: h.is_active,
          }))}
        />
      ) : null}

      {perms.canManageBanquet ? (
        <div className="flex flex-wrap gap-3">
          <BanquetStatusButtons
            propertyId={propertyId}
            banquetId={banquet.id}
            status={banquet.status}
          />
        </div>
      ) : null}
    </div>
  );
}
