import { ErrorState } from "@/components/common/error-state";
import { ScheduleList } from "@/components/service/schedule-list";
import {
  getServicePerms,
  listServiceContracts,
  listServicePos,
  listServiceSchedules,
} from "@/features/service/queries";
import { todayVn } from "@/features/finance/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/**
 * Lịch kỳ dịch vụ theo tháng + PO dịch vụ lẻ chờ nghiệm thu (T-042).
 * `?month=YYYY-MM`, mặc định tháng hiện tại (giờ Việt Nam).
 */
export default async function ServiceSchedulesPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ month?: string }>;
}) {
  const { property: propertyId } = await params;
  const { month } = await searchParams;
  const currentMonth = todayVn().slice(0, 7);
  const selectedMonth =
    month && /^\d{4}-\d{2}$/.test(month) ? month : currentMonth;

  const [schedulesRes, posRes, contractsRes, perms] = await Promise.all([
    listServiceSchedules(propertyId, { month: selectedMonth }),
    listServicePos(propertyId, { onlyPending: true }),
    listServiceContracts(propertyId),
    getServicePerms(propertyId),
  ]);

  if (!schedulesRes.ok) {
    return <ErrorState description={schedulesRes.error} />;
  }
  if (!posRes.ok) {
    return <ErrorState description={posRes.error} />;
  }
  if (!contractsRes.ok) {
    return <ErrorState description={contractsRes.error} />;
  }

  return (
    <div className="space-y-4">
      <PageHeader
        title={vi.service.schedulesTitle}
        description={vi.service.schedulesHint}
      />
      <ScheduleList
        propertyId={propertyId}
        month={selectedMonth}
        schedules={schedulesRes.data}
        pendingPos={posRes.data}
        contracts={contractsRes.data}
        canAccept={perms.canAccept}
      />
    </div>
  );
}
