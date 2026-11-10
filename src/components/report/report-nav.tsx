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
      className="flex flex-wrap items-center gap-1 border-b pb-2"
    >
      <Link
        href={`/${propertyId}/reports`}
        className={cn(
          "rounded-md px-3 py-1.5 text-sm",
          pathname === `/${propertyId}/reports`
            ? "bg-primary/10 font-medium text-primary"
            : "text-muted-foreground hover:text-foreground",
        )}
      >
        {vi.reports.indexTitle}
      </Link>
      {REPORT_META.filter((m) => perms[m.code]).map((m) => {
        const href = `/${propertyId}/reports/${m.slug}`;
        return (
          <Link
            key={m.code}
            href={href}
            className={cn(
              "rounded-md px-3 py-1.5 text-sm",
              pathname === href || pathname.startsWith(`${href}/`)
                ? "bg-primary/10 font-medium text-primary"
                : "text-muted-foreground hover:text-foreground",
            )}
          >
            {m.title}
          </Link>
        );
      })}
    </nav>
  );
}
