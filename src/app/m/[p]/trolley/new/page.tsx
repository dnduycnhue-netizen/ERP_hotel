import { notFound } from "next/navigation";
import { EmptyState } from "@/components/common/empty-state";
import { MobileTrolleyOpenForm } from "@/components/trolley/mobile-trolley-open-form";
import { listWarehouses } from "@/features/master/queries";
import { getTrolleyPerms } from "@/features/trolley/queries";
import { vi } from "@/i18n/vi";

/** Mở ca xe đẩy mới — mobile buồng phòng (bổ sung T-034). */
export default async function MobileTrolleyNewPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;

  const perms = await getTrolleyPerms(propertyId);
  if (!perms.canOperate) {
    notFound();
  }

  const warehouses = await listWarehouses(propertyId);
  const trolleyWarehouses = warehouses
    .filter((w) => w.kind === "trolley")
    .map((w) => ({ id: w.id, code: w.code, name: w.name }));
  if (trolleyWarehouses.length === 0) {
    return <EmptyState title={vi.trolley.noTrolleyWarehouse} />;
  }

  return (
    <MobileTrolleyOpenForm
      propertyId={propertyId}
      trolleyWarehouses={trolleyWarehouses}
    />
  );
}
