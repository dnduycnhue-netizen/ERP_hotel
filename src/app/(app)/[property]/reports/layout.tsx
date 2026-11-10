import type { ReactNode } from "react";
import { ErrorState } from "@/components/common/error-state";
import { ReportsNav } from "@/components/report/report-nav";
import { getReportPerms, type ReportPerms } from "@/features/report/queries";
import { REPORT_CODES } from "@/features/report/definitions";
import { vi } from "@/i18n/vi";

/**
 * Layout khu Báo cáo (T-044): chặn người không có quyền xem báo cáo nào,
 * hiện thanh điều hướng các báo cáo được cấp quyền.
 */
export default async function ReportsLayout({
  params,
  children,
}: {
  params: Promise<{ property: string }>;
  children: ReactNode;
}) {
  const { property } = await params;
  const perms: ReportPerms = await getReportPerms(property);
  const canAny = REPORT_CODES.some((c) => perms[c]);

  if (!canAny) {
    return (
      <div className="space-y-4">
        <h1 className="text-2xl font-bold">{vi.reports.title}</h1>
        <ErrorState title={vi.reports.noPermission} />
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <h1 className="text-2xl font-bold">{vi.reports.title}</h1>
      <ReportsNav propertyId={property} perms={perms} />
      {children}
    </div>
  );
}
