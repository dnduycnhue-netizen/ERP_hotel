import { ErrorState } from "@/components/common/error-state";
import { AdvanceList } from "@/components/finance/advance-list";
import { listAdvances } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";

/** Danh sách tạm ứng (T-041): trạng thái + hạn quyết toán. */
export default async function FinanceAdvancesPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const advancesRes = await listAdvances(propertyId, { pageSize: 100 });
  if (!advancesRes.ok) {
    return <ErrorState description={advancesRes.error} />;
  }

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">{vi.finance.advancesTitle}</h1>
      <AdvanceList propertyId={propertyId} advances={advancesRes.data.rows} />
    </div>
  );
}
