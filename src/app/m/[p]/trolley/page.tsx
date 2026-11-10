import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { MobileTrolleyList } from "@/components/trolley/mobile-trolley-list";
import { listWarehouses } from "@/features/master/queries";
import { getTrolleyPerms, listTrolleyShifts } from "@/features/trolley/queries";

/** Danh sách ca xe đẩy — mobile buồng phòng (bổ sung T-034). */
export default async function MobileTrolleyListPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;

  const perms = await getTrolleyPerms(propertyId);
  if (!perms.canOperate) {
    notFound();
  }

  const [shiftsRes, warehouses] = await Promise.all([
    listTrolleyShifts(propertyId),
    listWarehouses(propertyId),
  ]);
  if (!shiftsRes.ok) {
    return <ErrorState description={shiftsRes.error} />;
  }

  const trolleyWarehouses = warehouses
    .filter((w) => w.kind === "trolley")
    .map((w) => ({ id: w.id, code: w.code, name: w.name }));

  return (
    <MobileTrolleyList
      shifts={shiftsRes.data}
      trolleyWarehouses={trolleyWarehouses}
      propertyId={propertyId}
    />
  );
}
