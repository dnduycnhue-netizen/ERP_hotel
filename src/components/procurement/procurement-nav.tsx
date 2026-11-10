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
    {
      href: `/${propertyId}/procurement/market`,
      label: vi.procurement.nav.market,
    },
    {
      href: `/${propertyId}/procurement/advances`,
      label: vi.procurement.nav.advances,
    },
    {
      href: `/${propertyId}/procurement/service-contracts`,
      label: vi.procurement.nav.serviceContracts,
    },
  ];

  return (
    <nav
      aria-label={vi.procurement.nav.title}
      className="mb-6 flex gap-1 overflow-x-auto border-b"
    >
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
