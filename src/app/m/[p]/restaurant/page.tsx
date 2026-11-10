import Link from "next/link";
import { notFound } from "next/navigation";
import { getRestaurantPerms } from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

/**
 * Hub Nhà hàng mobile (W4): Bếp / Bán theo món / Buffet / Đặt tiệc.
 * Chỉ hiện mục mà user có quyền dùng; không có quyền nhà hàng nào → 404
 * (mẫu layout desktop `restaurant/layout.tsx`).
 */
export default async function MobileRestaurantHubPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;
  const perms = await getRestaurantPerms(propertyId);
  if (!perms.canView) {
    notFound();
  }

  const links = [
    {
      href: `/m/${propertyId}/restaurant/kitchen`,
      title: vi.restaurant.navKitchen,
      hint: vi.restaurant.kitchenHint,
      show: true,
    },
    {
      href: `/m/${propertyId}/restaurant/sales`,
      title: vi.restaurant.navSales,
      hint: vi.restaurant.salesHint,
      show: true,
    },
    {
      href: `/m/${propertyId}/restaurant/buffet`,
      title: vi.restaurant.navBuffet,
      hint: vi.restaurant.buffetHint,
      show: perms.canManageBuffet || perms.canView,
    },
    {
      href: `/m/${propertyId}/restaurant/banquets`,
      title: vi.restaurant.navBanquets,
      hint: vi.restaurant.banquetsHint,
      show: true,
    },
  ].filter((l) => l.show);

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.title}</h1>
        <p className="mt-1 text-base text-muted-foreground">
          {vi.restaurant.mobile.hubHint}
        </p>
      </div>
      <div className="flex flex-col gap-3">
        {links.map((link) => (
          <Link
            key={link.href}
            href={link.href}
            className="block min-h-11 rounded-xl border bg-card p-4 hover:bg-muted"
          >
            <span className="block text-base font-semibold">{link.title}</span>
            <span className="mt-1 block text-base text-muted-foreground">
              {link.hint}
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
