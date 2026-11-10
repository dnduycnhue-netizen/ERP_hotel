"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

export type FinanceNavPerms = {
  canInvoices: boolean;
  canPayables: boolean;
  canAdvances: boolean;
  canPaymentRequests: boolean;
  canListings: boolean;
};

/**
 * Thanh điều hướng trong khu Tài chính (T-041).
 * Chỉ hiện mục mà người dùng có quyền xem; mục đang mở được tô đậm.
 */
export function FinanceNav({
  propertyId,
  perms,
}: {
  propertyId: string;
  perms: FinanceNavPerms;
}) {
  const pathname = usePathname();
  const items: Array<{
    href: string;
    label: string;
    active: boolean;
    show: boolean;
  }> = [
    {
      href: `/${propertyId}/finance`,
      label: vi.finance.overviewTitle,
      active: pathname === `/${propertyId}/finance`,
      show: true,
    },
    {
      href: `/${propertyId}/finance/invoices`,
      label: vi.finance.navInvoices,
      active: pathname.startsWith(`/${propertyId}/finance/invoices`),
      show: perms.canInvoices,
    },
    {
      href: `/${propertyId}/finance/payables`,
      label: vi.finance.navPayables,
      active: pathname.startsWith(`/${propertyId}/finance/payables`),
      show: perms.canPayables,
    },
    {
      href: `/${propertyId}/finance/advances`,
      label: vi.finance.navAdvances,
      active: pathname.startsWith(`/${propertyId}/finance/advances`),
      show: perms.canAdvances,
    },
    {
      href: `/${propertyId}/finance/payment-requests`,
      label: vi.finance.navPaymentRequests,
      active: pathname.startsWith(`/${propertyId}/finance/payment-requests`),
      show: perms.canPaymentRequests,
    },
    {
      href: `/${propertyId}/finance/no-invoice-listings`,
      label: vi.finance.navNoInvoiceListings,
      active: pathname.startsWith(`/${propertyId}/finance/no-invoice-listings`),
      show: perms.canListings,
    },
  ];
  return (
    <nav
      className="mb-6 flex gap-1 overflow-x-auto border-b"
      aria-label={vi.finance.title}
    >
      {items
        .filter((i) => i.show)
        .map((i) => (
          <Link
            key={i.href}
            href={i.href}
            aria-current={i.active ? "page" : undefined}
            className={cn(
              "shrink-0 border-b-2 px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-2 focus-visible:ring-brand/40",
              i.active
                ? "border-brand text-brand"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
          >
            {i.label}
          </Link>
        ))}
    </nav>
  );
}
