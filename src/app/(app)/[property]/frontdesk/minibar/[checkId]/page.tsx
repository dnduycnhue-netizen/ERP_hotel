import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { FrontdeskCheckDetail } from "@/components/minibar/frontdesk-check-detail";
import {
  getMinibarCheck,
  getMinibarPerms,
} from "@/features/minibar/queries";

/** Chi tiết phiếu kiểm minibar — lễ tân (T-035). */
export default async function FrontdeskMinibarDetailPage({
  params,
}: {
  params: Promise<{ property: string; checkId: string }>;
}) {
  const { property: propertyId, checkId } = await params;

  const [detailRes, perms] = await Promise.all([
    getMinibarCheck(checkId),
    getMinibarPerms(propertyId),
  ]);

  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }
  if (detailRes.data.check.property_id !== propertyId) {
    notFound();
  }

  return (
    <FrontdeskCheckDetail
      propertyId={propertyId}
      detail={detailRes.data}
      perms={perms}
    />
  );
}
