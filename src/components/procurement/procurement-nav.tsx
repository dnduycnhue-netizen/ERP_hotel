"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { vi } from "@/i18n/vi";

/** Tab điều hướng khu thu mua: yêu cầu mua, đơn mua, chờ tôi duyệt. */
export function ProcurementNav({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();

  const links = [
    { href: `/${propertyId}/procurement/pr`, label: vi.procurement.nav.pr },
    { href: `/${propertyId}/procurement/po`, label: vi.procurement.nav.po },
    {
      href: `/${propertyId}/procurement/approvals`,
      label: vi.procurement.nav.approvals,
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
