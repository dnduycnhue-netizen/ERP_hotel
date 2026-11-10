"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { vi } from "@/i18n/vi";

/**
 * Điều hướng nhanh khu Nhà hàng mobile (W4).
 * Dùng tạm thay cho mục Nhà hàng trong MobileNav chung của W1 — sau khi
 * gộp, W1 thêm link `/m/[p]/restaurant` vào shell thì bỏ nav này
 * (xem Q192).
 */
export function MobileRestaurantNav({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();
  const links = [
    {
      href: `/m/${propertyId}/restaurant/kitchen`,
      label: vi.restaurant.navKitchen,
    },
    {
      href: `/m/${propertyId}/restaurant/sales`,
      label: vi.restaurant.navSales,
    },
    {
      href: `/m/${propertyId}/restaurant/buffet`,
      label: vi.restaurant.navBuffet,
    },
    {
      href: `/m/${propertyId}/restaurant/banquets`,
      label: vi.restaurant.navBanquets,
    },
  ];
  return (
    <nav className="mb-4 flex flex-wrap gap-2">
      {links.map((link) => {
        const isActive = pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            className={cn(
              "inline-flex min-h-11 items-center rounded-lg px-3 py-2 text-base font-medium",
              isActive
                ? "bg-[#7B68EE] text-white shadow-sm"
                : "bg-card text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
