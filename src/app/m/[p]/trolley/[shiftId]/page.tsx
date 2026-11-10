import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { MobileTrolleyWorkspace } from "@/components/trolley/mobile-trolley-workspace";
import {
  getTrolleyPerms,
  getTrolleyShift,
  listTrolleyParLevels,
  listTrolleyRooms,
} from "@/features/trolley/queries";

/**
 * Ca xe đẩy — mobile buồng phòng (bổ sung T-034).
 * Ca đang mở → đếm cuối ca + đóng ca; ca đã đóng → xem tiêu hao.
 */
export default async function MobileTrolleyShiftPage({
  params,
}: {
  params: Promise<{ p: string; shiftId: string }>;
}) {
  const { p: propertyId, shiftId } = await params;

  const perms = await getTrolleyPerms(propertyId);
  if (!perms.canOperate) {
    notFound();
  }

  const detailRes = await getTrolleyShift(shiftId);
  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }
  const detail = detailRes.data;
  if (detail.shift.property_id !== propertyId) {
    notFound();
  }

  const [parRes, roomsRes] = await Promise.all([
    listTrolleyParLevels(propertyId, detail.shift.trolley_warehouse_id),
    listTrolleyRooms(propertyId),
  ]);
  if (!parRes.ok) {
    return <ErrorState description={parRes.error} />;
  }
  if (!roomsRes.ok) {
    return <ErrorState description={roomsRes.error} />;
  }

  return (
    <MobileTrolleyWorkspace
      detail={detail}
      parItems={parRes.data}
      rooms={roomsRes.data}
      propertyId={propertyId}
    />
  );
}
