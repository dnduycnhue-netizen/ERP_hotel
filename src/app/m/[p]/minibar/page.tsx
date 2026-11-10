import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { MobileMinibarList } from "@/components/minibar/mobile-minibar-list";
import { getMinibarPerms, listMinibarChecks } from "@/features/minibar/queries";

/** Danh sách phòng chờ kiểm minibar — mobile buồng phòng (T-035). */
export default async function MobileMinibarListPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;

  const perms = await getMinibarPerms(propertyId);
  if (!perms.canCheck) {
    notFound();
  }

  const res = await listMinibarChecks(propertyId, "pending_charge");
  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return <MobileMinibarList checks={res.data} propertyId={propertyId} />;
}
