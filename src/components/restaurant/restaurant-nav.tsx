"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCan } from "@/lib/permissions/permissions-provider";
import { cn } from "@/lib/utils";
import { vi } from "@/i18n/vi";

/** Tab điều hướng khu Nhà hàng (M06): ẩn tab mà user không có quyền xem. */
export function RestaurantNav({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();

  // Mỗi useCan phải gọi vô điều kiện (không OR trực tiếp trên lời gọi
  // hook — ESLint react-hooks/rules-of-hooks bắt lỗi này).
  const canView = useCan("restaurant.view");
  const canManageDish = useCan("restaurant.dish.manage");
  const canRecordSale = useCan("restaurant.sale.record");
  const canManageBuffet = useCan("restaurant.buffet.manage");
  const canManageBanquet = useCan("restaurant.banquet.manage");

  const links: { href: string; label: string }[] = [];
  if (
    canView ||
    canManageDish ||
    canRecordSale ||
    canManageBuffet ||
    canManageBanquet
  ) {
    links.push({
      href: `/${propertyId}/restaurant/kitchen`,
      label: vi.restaurant.navKitchen,
    });
  }
  if (canView || canManageDish) {
    links.push({
      href: `/${propertyId}/restaurant/dishes`,
      label: vi.restaurant.navDishes,
    });
  }
  if (canView || canRecordSale || canManageBuffet || canManageBanquet) {
    links.push({
      href: `/${propertyId}/restaurant/sales`,
      label: vi.restaurant.navSales,
    });
  }
  if (canView || canManageBuffet) {
    links.push({
      href: `/${propertyId}/restaurant/buffet`,
      label: vi.restaurant.navBuffet,
    });
  }
  if (canView || canManageBanquet) {
    links.push({
      href: `/${propertyId}/restaurant/banquets`,
      label: vi.restaurant.navBanquets,
    });
    links.push({
      href: `/${propertyId}/restaurant/halls`,
      label: vi.restaurant.navHalls,
    });
  }

  if (links.length === 0) return null;

  return (
    <nav
      aria-label={vi.restaurant.title}
      className="flex flex-wrap gap-1 border-b pb-2"
    >
      {links.map((link) => {
        const active = pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "rounded-lg px-3 py-1.5 text-sm font-medium",
              active
                ? "bg-primary text-primary-foreground"
                : "text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
