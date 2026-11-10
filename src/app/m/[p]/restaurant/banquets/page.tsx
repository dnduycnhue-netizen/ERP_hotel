import { ErrorState } from "@/components/common/error-state";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import { MobileBanquetStatusButtons } from "@/components/restaurant/mobile-restaurant-actions";
import { MobileRestaurantNav } from "@/components/restaurant/mobile-restaurant-nav";
import {
  getBanquet,
  getRestaurantPerms,
  listBanquets,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

function vnDate(offsetDays = 0): string {
  return new Date(Date.now() + offsetDays * 86_400_000).toLocaleDateString(
    "en-CA",
    { timeZone: "Asia/Ho_Chi_Minh" },
  );
}

function statusLabel(status: string): string {
  if (status === "new") return vi.restaurant.mobile.statusNew;
  if (status === "confirmed") return vi.restaurant.mobile.statusConfirmed;
  if (status === "in_progress") return vi.restaurant.mobile.statusInProgress;
  if (status === "completed") return vi.restaurant.mobile.statusCompleted;
  return vi.restaurant.mobile.statusCancelled;
}

/**
 * Đặt tiệc — mobile (W4): tiệc 7 ngày tới + thực đơn từng tiệc; xác nhận /
 * bắt đầu / hoàn thành / hủy qua RPC `banquet_*` (đã kiểm quyền
 * `restaurant.banquet.manage` + trùng sảnh ở server). Tạo tiệc mới vẫn
 * làm trên bản desktop.
 */
export default async function MobileBanquetsPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;
  const from = vnDate(0);
  const to = vnDate(7);

  const [banquetsRes, perms] = await Promise.all([
    listBanquets(propertyId, from, to),
    getRestaurantPerms(propertyId),
  ]);
  if (!banquetsRes.ok) {
    return <ErrorState description={banquetsRes.error} />;
  }
  const banquets = banquetsRes.data;
  const details = await Promise.all(
    banquets.map((b) => getBanquet(propertyId, b.id)),
  );
  const dishesByBanquet = new Map(
    banquets.map((b, i) => [
      b.id,
      details[i]?.ok ? (details[i].data?.dishes ?? []) : [],
    ]),
  );

  return (
    <div className="space-y-6">
      <MobileRestaurantNav propertyId={propertyId} />
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.banquetsTitle}</h1>
        <p className="mt-1 text-base text-muted-foreground">
          {vi.restaurant.mobile.upcomingBanquets}
        </p>
      </div>

      {banquets.length === 0 ? (
        <p className="text-base text-muted-foreground">
          {vi.restaurant.mobile.noBanquetsUpcoming}
        </p>
      ) : (
        banquets.map((b) => (
          <article
            key={b.id}
            className="space-y-3 rounded-xl border bg-card p-4"
          >
            <div className="flex flex-wrap items-start justify-between gap-2">
              <h2 className="text-base font-semibold">
                {b.doc_no} — {b.customer_name}
              </h2>
              <span className="rounded-full bg-[#7B68EE]/10 px-3 py-1 text-base font-medium text-[#7B68EE]">
                {statusLabel(b.status)}
              </span>
            </div>
            <p className="text-base text-muted-foreground">
              {b.event_date} · {b.start_time}–{b.end_time} · {b.hall}
            </p>
            <p className="text-base text-muted-foreground">
              {vi.restaurant.guestsCount}: {formatNumber(b.guests_count)} ·{" "}
              {vi.restaurant.tablesCount}: {formatNumber(b.tables_count)}
              {b.deposit_amount > 0
                ? ` · ${vi.restaurant.depositAmount}: ${formatMoney(b.deposit_amount)}`
                : ""}
              {b.status === "cancelled" && b.cancel_reason
                ? ` · ${b.cancel_reason}`
                : ""}
            </p>
            {(dishesByBanquet.get(b.id) ?? []).length > 0 ? (
              <ul className="list-disc space-y-1 pl-5 text-base">
                {(dishesByBanquet.get(b.id) ?? []).map((d) => (
                  <li key={d.recipe_id}>
                    {d.recipe_name} — {formatNumber(d.qty)}{" "}
                    {vi.restaurant.servings.toLowerCase()}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-base text-muted-foreground">
                {vi.restaurant.noBanquets}
              </p>
            )}
            {perms.canManageBanquet ? (
              <MobileBanquetStatusButtons
                propertyId={propertyId}
                banquetId={b.id}
                status={b.status}
              />
            ) : null}
          </article>
        ))
      )}
    </div>
  );
}
