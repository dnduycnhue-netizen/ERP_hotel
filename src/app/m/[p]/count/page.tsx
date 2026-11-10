import { ErrorState } from "@/components/common/error-state";
import { MobileCountList } from "@/components/count/mobile-count-list";
import { listCounts } from "@/features/count/queries";

/** Danh sách đợt kiểm kê mobile (T-033). */
export default async function MobileCountListPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;

  const res = await listCounts({
    propertyId,
    status: null,
    warehouseId: null,
    limit: 50,
    offset: 0,
  });
  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return <MobileCountList counts={res.data.items} propertyId={propertyId} />;
}
