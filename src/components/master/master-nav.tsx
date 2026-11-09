"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { vi } from "@/i18n/vi";

export function MasterNav({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();

  const links = [
    { href: `/${propertyId}/master/items`, label: vi.master.nav.items },
    {
      href: `/${propertyId}/master/item-groups`,
      label: vi.master.nav.itemGroups,
    },
    { href: `/${propertyId}/master/uoms`, label: vi.master.nav.uoms },
    {
      href: `/${propertyId}/master/warehouses`,
      label: vi.master.nav.warehouses,
    },
    { href: `/${propertyId}/master/rooms`, label: vi.master.nav.rooms },
    { href: `/${propertyId}/master/outlets`, label: vi.master.nav.outlets },
    {
      href: `/${propertyId}/master/expense-categories`,
      label: vi.master.nav.expenseCategories,
    },
  ];

  return (
    <nav className="flex flex-wrap gap-2 border-b pb-3 mb-6">
      {links.map((link) => {
        const isActive = pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            className={cn(
              "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
              isActive
                ? "bg-primary text-primary-foreground shadow-sm"
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
