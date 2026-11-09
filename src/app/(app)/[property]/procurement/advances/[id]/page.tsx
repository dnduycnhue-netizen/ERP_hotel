import { ErrorState } from "@/components/common/error-state";
import { AdvanceDetail } from "@/components/procurement/advance-detail";
import { getAdvance } from "@/features/procurement/queries";

export default async function ProcurementAdvanceDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: advanceId } = await params;

  const res = await getAdvance(propertyId, advanceId);

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return <AdvanceDetail propertyId={propertyId} detail={res.data} />;
}
