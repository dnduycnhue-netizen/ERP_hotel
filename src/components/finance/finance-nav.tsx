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
    <nav className="flex flex-wrap gap-2" aria-label={vi.finance.title}>
      {items
        .filter((i) => i.show)
        .map((i) => (
          <Link
            key={i.href}
            href={i.href}
            aria-current={i.active ? "page" : undefined}
            className={cn(
              "rounded-full border px-3 py-1.5 text-sm",
              i.active
                ? "border-primary bg-primary text-primary-foreground"
                : "bg-background text-foreground/80 hover:text-foreground",
            )}
          >
            {i.label}
          </Link>
        ))}
    </nav>
  );
}
