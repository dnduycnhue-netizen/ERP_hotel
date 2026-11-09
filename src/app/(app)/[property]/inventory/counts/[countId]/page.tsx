import { ErrorState } from "@/components/common/error-state";
import { CountReportView } from "@/components/count/count-report-view";
import {
  getCount,
  getCountAdjustment,
  getCountPerms,
  getCountResult,
  listCounters,
} from "@/features/count/queries";

/**
 * Chi tiết đợt kiểm kê + biên bản chênh lệch (T-033): bảng v_count_result
 * chỉ trả dòng khi viewer có `count.view_variance` và không phải người đếm
 * (RLS ở view); khóa đợt / ghi điều chỉnh / hủy đợt kiểm tra quyền riêng.
 */
export default async function CountDetailPage({
  params,
}: {
  params: Promise<{ property: string; countId: string }>;
}) {
  const { property: propertyId, countId } = await params;

  const [countRes, resultRes, adjustmentRes, perms] = await Promise.all([
    getCount(countId),
    getCountResult(countId),
    getCountAdjustment(countId),
    getCountPerms(propertyId),
  ]);

  if (!countRes.ok) {
    return <ErrorState description={countRes.error} />;
  }
  if (!resultRes.ok) {
    return <ErrorState description={resultRes.error} />;
  }
  if (!adjustmentRes.ok) {
    return <ErrorState description={adjustmentRes.error} />;
  }

  const count = countRes.data;
  const countersRes = perms.canOpen
    ? await listCounters(propertyId, count.warehouse_id)
    : { ok: false as const, error: "" };
  const counters = countersRes.ok ? countersRes.data : [];

  return (
    <CountReportView
      count={count}
      result={resultRes.data}
      adjustment={adjustmentRes.data}
      counters={counters}
      canLock={perms.canLock}
      canAdjustApprove={perms.canAdjustApprove}
      canOpen={perms.canOpen}
      canViewVariance={perms.canViewVariance}
      canViewValue={perms.canViewValue}
      propertyId={propertyId}
    />
  );
}
