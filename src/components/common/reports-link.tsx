"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { BarChart3 } from "lucide-react";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import { REPORT_CODES, getReportMeta } from "@/features/report/definitions";

/**
 * Link "Báo cáo" trên header (T-044).
 * Hiện khi có bất kỳ quyền report.view.* nào.
 */
export function ReportsLink({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();

  // Gọi đủ 10 hook useCan theo thứ tự cố định (không gọi trong vòng lặp).
  const can0 = useCan(getReportMeta(REPORT_CODES[0]).permission);
  const can1 = useCan(getReportMeta(REPORT_CODES[1]).permission);
  const can2 = useCan(getReportMeta(REPORT_CODES[2]).permission);
  const can3 = useCan(getReportMeta(REPORT_CODES[3]).permission);
  const can4 = useCan(getReportMeta(REPORT_CODES[4]).permission);
  const can5 = useCan(getReportMeta(REPORT_CODES[5]).permission);
  const can6 = useCan(getReportMeta(REPORT_CODES[6]).permission);
  const can7 = useCan(getReportMeta(REPORT_CODES[7]).permission);
  const can8 = useCan(getReportMeta(REPORT_CODES[8]).permission);
  const can9 = useCan(getReportMeta(REPORT_CODES[9]).permission);
  const canAny = [
    can0,
    can1,
    can2,
    can3,
    can4,
    can5,
    can6,
    can7,
    can8,
    can9,
  ].some(Boolean);

  if (!canAny) return null;

  const active = pathname.startsWith(`/${propertyId}/reports`);
  return (
    <Link
      href={`/${propertyId}/reports`}
      className={
        active
          ? "inline-flex items-center gap-1.5 rounded-md bg-primary/10 px-2 py-1 text-sm font-medium text-primary"
          : "inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-sm text-muted-foreground hover:text-foreground"
      }
    >
      <BarChart3 className="h-4 w-4" />
      {vi.reports.title}
    </Link>
  );
}
