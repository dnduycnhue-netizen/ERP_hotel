import { ErrorState } from "@/components/common/error-state";
import { formatNumber } from "@/components/common/money-text";
import {
  MobileBuffetCancelButton,
  MobileBuffetCloseForm,
} from "@/components/restaurant/mobile-restaurant-actions";
import {
  getBuffetSession,
  getRestaurantPerms,
  listBuffetSessions,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

function vnToday(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

function mealLabel(meal: string): string {
  if (meal === "breakfast") return vi.restaurant.mealBreakfast;
  if (meal === "lunch") return vi.restaurant.mealLunch;
  return vi.restaurant.mealDinner;
}

function statusLabel(status: string): string {
  if (status === "planned") return vi.restaurant.mobile.statusPlanned;
  if (status === "open") return vi.restaurant.mobile.statusOpen;
  if (status === "closed") return vi.restaurant.mobile.statusClosed;
  return vi.restaurant.mobile.statusCancelled;
}

/**
 * Buffet — mobile (W4): xem phiên hôm nay + món trong phiên; đóng phiên
 * (ghi doanh thu) / hủy phiên qua RPC `buffet_session_close` /
 * `buffet_session_cancel`. Tạo phiên mới vẫn làm trên bản desktop.
 */
export default async function MobileBuffetPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;
  const today = vnToday();

  const [sessionsRes, perms] = await Promise.all([
    listBuffetSessions(propertyId, today, today),
    getRestaurantPerms(propertyId),
  ]);
  if (!sessionsRes.ok) {
    return <ErrorState description={sessionsRes.error} />;
  }
  const sessions = sessionsRes.data;
  // Tối đa 1 phiên / buổi / ngày nên đọc thêm món từng phiên là đủ.
  const details = await Promise.all(
    sessions.map((s) => getBuffetSession(propertyId, s.id)),
  );
  const dishesBySession = new Map(
    sessions.map((s, i) => [
      s.id,
      details[i]?.ok ? (details[i].data?.dishes ?? []) : [],
    ]),
  );

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.buffetTitle}</h1>
        <p className="mt-1 text-base text-muted-foreground">
          {vi.restaurant.buffetHint}
        </p>
      </div>

      {sessions.length === 0 ? (
        <p className="text-base text-muted-foreground">
          {vi.restaurant.mobile.noBuffetToday}
        </p>
      ) : (
        sessions.map((s) => (
          <article
            key={s.id}
            className="space-y-3 rounded-xl border bg-card p-4"
          >
            <div className="flex flex-wrap items-start justify-between gap-2">
              <h2 className="text-base font-semibold">
                {mealLabel(s.meal)} · {s.business_date}
              </h2>
              <span className="rounded-full bg-[#7B68EE]/10 px-3 py-1 text-base font-medium text-[#7B68EE]">
                {statusLabel(s.status)}
              </span>
            </div>
            <p className="text-base text-muted-foreground">
              {vi.restaurant.guestCount}: {formatNumber(s.guest_count)}
              {s.price_per_guest !== null
                ? ` · ${vi.restaurant.pricePerGuest}: ${formatNumber(s.price_per_guest)}`
                : ""}
              {s.status === "cancelled" && s.cancel_reason
                ? ` · ${s.cancel_reason}`
                : ""}
            </p>
            {(dishesBySession.get(s.id) ?? []).length > 0 ? (
              <ul className="list-disc space-y-1 pl-5 text-base">
                {(dishesBySession.get(s.id) ?? []).map((d) => (
                  <li key={d.recipe_id}>
                    {d.recipe_name} — {formatNumber(d.planned_qty)}{" "}
                    {vi.restaurant.servings.toLowerCase()}
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-base text-muted-foreground">
                {vi.restaurant.noSessions}
              </p>
            )}
            {perms.canManageBuffet &&
            (s.status === "planned" || s.status === "open") ? (
              <>
                <MobileBuffetCloseForm
                  propertyId={propertyId}
                  sessionId={s.id}
                  defaultGuestCount={s.guest_count}
                  defaultPricePerGuest={s.price_per_guest}
                />
                <MobileBuffetCancelButton
                  propertyId={propertyId}
                  sessionId={s.id}
                />
              </>
            ) : null}
          </article>
        ))
      )}
    </div>
  );
}
