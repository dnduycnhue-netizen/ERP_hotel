import { ErrorState } from "@/components/common/error-state";
import { MobileTaskList } from "@/components/receiving/mobile-task-list";
import { listWarehouses } from "@/features/master/queries";
import { listReceivingTasks } from "@/features/receiving/queries";

/**
 * Màn hình nhận hàng mobile — danh sách "Hàng chờ nhận hôm nay" (T-024,
 * docs/06-UI-UX.md §3.1): tên NCC, số dòng, ngày hẹn giao. KHÔNG số lượng,
 * KHÔNG giá — mù ở tầng dữ liệu (RPC `receiving_list_tasks` chỉ trả
 * po_id/doc_no/supplier/channel/expected_date/line_count).
 */
export default async function MobileReceivePage({
  params,
  searchParams,
}: {
  params: Promise<{ p: string }>;
  searchParams: Promise<{ posted?: string }>;
}) {
  const { p: propertyId } = await params;
  const { posted } = await searchParams;

  const [tasksRes, warehouses] = await Promise.all([
    listReceivingTasks(propertyId),
    listWarehouses(propertyId),
  ]);

  if (!tasksRes.ok) {
    return <ErrorState description={tasksRes.error} />;
  }

  return (
    <MobileTaskList
      tasks={tasksRes.data}
      propertyId={propertyId}
      warehouses={warehouses}
      posted={posted === "1"}
    />
  );
}
