"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";
import { REPORT_META, type ReportCode } from "@/features/report/definitions";

/**
 * Thanh điều hướng trong khu Báo cáo (T-044).
 * Chỉ hiện mục mà người dùng có quyền xem; mục đang mở được tô đậm.
 */
export function ReportsNav({
  propertyId,
  perms,
}: {
  propertyId: string;
  perms: Record<ReportCode, boolean>;
}) {
  const pathname = usePathname();
  return (
    <nav
      aria-label={vi.reports.title}
      className="mb-6 flex gap-1 overflow-x-auto border-b"
    >
      <Link
        href={`/${propertyId}/reports`}
        aria-current={
          pathname === `/${propertyId}/reports` ? "page" : undefined
        }
        className={cn(
          "shrink-0 border-b-2 px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-2 focus-visible:ring-brand/40",
          pathname === `/${propertyId}/reports`
            ? "border-brand text-brand"
            : "border-transparent text-muted-foreground hover:text-foreground",
        )}
      >
        {vi.reports.indexTitle}
      </Link>
      {REPORT_META.filter((m) => perms[m.code]).map((m) => {
        const href = `/${propertyId}/reports/${m.slug}`;
        const isActive = pathname === href || pathname.startsWith(`${href}/`);
        return (
          <Link
            key={m.code}
            href={href}
            aria-current={isActive ? "page" : undefined}
            className={cn(
              "shrink-0 border-b-2 px-3 py-2 text-sm font-medium whitespace-nowrap transition-colors outline-none focus-visible:ring-2 focus-visible:ring-brand/40",
              isActive
                ? "border-brand text-brand"
                : "border-transparent text-muted-foreground hover:text-foreground",
            )}
          >
            {m.title}
          </Link>
        );
      })}
    </nav>
  );
}
