import { ErrorState } from "@/components/common/error-state";
import { FrontdeskCheckList } from "@/components/minibar/frontdesk-check-list";
import { listRooms } from "@/features/master/queries";
import { getMinibarPerms, listMinibarChecks } from "@/features/minibar/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/** Màn lễ tân — minibar (T-035): phòng chờ kiểm + phiếu đang mở. */
export default async function FrontdeskMinibarPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const today = new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });

  const [rooms, openRes, allRes, perms] = await Promise.all([
    listRooms(propertyId),
    listMinibarChecks(propertyId, "pending_charge"),
    listMinibarChecks(propertyId, null),
    getMinibarPerms(propertyId),
  ]);

  if (!openRes.ok) {
    return <ErrorState description={openRes.error} />;
  }
  if (!allRes.ok) {
    return <ErrorState description={allRes.error} />;
  }

  const doneToday = allRes.data.filter(
    (c) =>
      c.business_date === today &&
      (c.status === "charged" ||
        c.status === "waived" ||
        c.status === "late_charge"),
  );

  return (
    <div className="space-y-4">
      <PageHeader title={vi.minibar.frontdeskTitle} />
      <FrontdeskCheckList
        propertyId={propertyId}
        rooms={rooms}
        openChecks={openRes.data}
        doneToday={doneToday}
        canRequestCheck={perms.canRequestCheck}
      />
    </div>
  );
}
