import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { formatMoney } from "@/components/common/money-text";
import {
  CancelBuffetButton,
  CloseBuffetForm,
} from "@/components/restaurant/restaurant-actions";
import { BuffetForm } from "@/components/restaurant/buffet-form";
import {
  getBuffetSession,
  getRestaurantPerms,
  listRecipes,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

function mealLabel(meal: string): string {
  if (meal === "breakfast") return vi.restaurant.mealBreakfast;
  if (meal === "lunch") return vi.restaurant.mealLunch;
  return vi.restaurant.mealDinner;
}

function sessionDocStatus(status: string) {
  if (status === "planned") return "new" as const;
  if (status === "open") return "in_progress" as const;
  if (status === "closed") return "completed" as const;
  return "cancelled" as const;
}

/** Chi tiết phiên buffet (M06): món, đóng phiên, hủy phiên. */
export default async function BuffetDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: sessionId } = await params;

  const [res, recipesRes, perms] = await Promise.all([
    getBuffetSession(propertyId, sessionId),
    listRecipes(propertyId),
    getRestaurantPerms(propertyId),
  ]);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }
  if (!res.data) {
    notFound();
  }
  const session = res.data;
  const editable =
    perms.canManageBuffet &&
    (session.status === "planned" || session.status === "open");
  const closable =
    perms.canManageBuffet &&
    (session.status === "planned" || session.status === "open");

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div>
          <h1 className="text-xl font-semibold">
            {vi.restaurant.buffetTitle} — {session.business_date} ·{" "}
            {mealLabel(session.meal)}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.restaurant.guestCount}: {session.guest_count}
            {session.price_per_guest !== null
              ? ` · ${vi.restaurant.pricePerGuest}: ${formatMoney(session.price_per_guest)}`
              : ""}
          </p>
        </div>
        <DocStatusBadge status={sessionDocStatus(session.status)} />
      </div>

      {session.dishes.length > 0 ? (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-left">
                <th className="px-3 py-2 font-medium">
                  {vi.restaurant.dishName}
                </th>
                <th className="px-3 py-2 text-right font-medium">
                  {vi.restaurant.plannedQty}
                </th>
              </tr>
            </thead>
            <tbody>
              {session.dishes.map((d) => (
                <tr key={d.recipe_id} className="border-b last:border-0">
                  <td className="px-3 py-2">{d.recipe_name}</td>
                  <td className="px-3 py-2 text-right tabular-nums">
                    {d.planned_qty}
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

      {session.notes ? (
        <p className="text-sm text-muted-foreground">{session.notes}</p>
      ) : null}

      {editable ? (
        <BuffetForm
          propertyId={propertyId}
          session={session}
          recipes={(recipesRes.ok ? recipesRes.data : []).map((r) => ({
            id: r.id,
            code: r.code,
            name: r.name,
          }))}
        />
      ) : null}

      {closable ? (
        <div className="flex flex-wrap gap-3">
          <CloseBuffetForm
            propertyId={propertyId}
            sessionId={session.id}
            defaultGuestCount={session.guest_count}
            defaultPricePerGuest={session.price_per_guest}
          />
          <CancelBuffetButton propertyId={propertyId} sessionId={session.id} />
        </div>
      ) : null}
    </div>
  );
}
