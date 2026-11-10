import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { StandardsManager } from "@/components/housekeeping/standards-manager";
import {
  getHousekeepingPerms,
  listRoomSetupStandards,
  listStandardItems,
} from "@/features/housekeeping/queries";
import { listRoomTypes } from "@/features/master/queries";

/** Quản lý tiêu chuẩn setup phòng (C7): thêm/sửa/xóa/xem định mức. */
export default async function StandardsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const perms = await getHousekeepingPerms(propertyId);
  if (!perms.canManageStandard && !perms.canOperateTrolley) {
    notFound();
  }

  const [standardsRes, roomTypes, itemsRes] = await Promise.all([
    listRoomSetupStandards(propertyId),
    listRoomTypes(propertyId),
    listStandardItems(propertyId),
  ]);
  if (!standardsRes.ok) {
    return <ErrorState description={standardsRes.error} />;
  }
  if (!itemsRes.ok) {
    return <ErrorState description={itemsRes.error} />;
  }

  return (
    <StandardsManager
      propertyId={propertyId}
      standards={standardsRes.data}
      roomTypes={roomTypes}
      items={itemsRes.data}
      canManage={perms.canManageStandard}
    />
  );
}
