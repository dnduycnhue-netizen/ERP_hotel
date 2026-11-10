import Link from "next/link";
import { getRestaurantPerms } from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

/** Trang chỉ mục khu Nhà hàng (M06): thẻ từng khu vực được cấp quyền. */
export default async function RestaurantIndexPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const perms = await getRestaurantPerms(propertyId);

  const cards: Array<{
    href: string;
    title: string;
    hint: string;
    show: boolean;
  }> = [
    {
      href: `/${propertyId}/restaurant/kitchen`,
      title: vi.restaurant.navKitchen,
      hint: vi.restaurant.kitchenHint,
      show: perms.canView,
    },
    {
      href: `/${propertyId}/restaurant/dishes`,
      title: vi.restaurant.navDishes,
      hint: vi.restaurant.dishesHint,
      show: perms.canView || perms.canManageDish,
    },
    {
      href: `/${propertyId}/restaurant/sales`,
      title: vi.restaurant.navSales,
      hint: vi.restaurant.salesHint,
      show:
        perms.canView ||
        perms.canRecordSale ||
        perms.canManageBuffet ||
        perms.canManageBanquet,
    },
    {
      href: `/${propertyId}/restaurant/buffet`,
      title: vi.restaurant.navBuffet,
      hint: vi.restaurant.buffetHint,
      show: perms.canView || perms.canManageBuffet,
    },
    {
      href: `/${propertyId}/restaurant/banquets`,
      title: vi.restaurant.navBanquets,
      hint: vi.restaurant.banquetsHint,
      show: perms.canView || perms.canManageBanquet,
    },
  ];
  const visible = cards.filter((c) => c.show);

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.title}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.restaurant.indexHint}
        </p>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        {visible.map((c) => (
          <article key={c.href} className="rounded-lg border p-4">
            <h2 className="text-base font-semibold">{c.title}</h2>
            <p className="mt-1 text-sm text-muted-foreground">{c.hint}</p>
            <Link
              href={c.href}
              className="mt-3 inline-flex h-8 items-center justify-center rounded-lg border border-border bg-background px-2.5 text-sm font-medium hover:bg-muted"
            >
              {vi.common.next}
            </Link>
          </article>
        ))}
      </div>
    </div>
  );
}
