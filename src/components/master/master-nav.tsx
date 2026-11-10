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
    {
      href: `/${propertyId}/master/suppliers`,
      label: vi.master.nav.suppliers,
    },
    {
      href: `/${propertyId}/master/prices`,
      label: vi.master.nav.prices,
    },
    {
      href: `/${propertyId}/master/import`,
      label: vi.master.nav.import,
    },
  ];

  return (
    <nav className="mb-6 flex gap-1 overflow-x-auto border-b">
      {links.map((link) => {
        const isActive = pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "shrink-0 border-b-2 px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-2 focus-visible:ring-brand/40",
              isActive
                ? "border-brand text-brand"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
