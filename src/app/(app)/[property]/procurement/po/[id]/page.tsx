import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { PoDetail } from "@/components/procurement/po-detail";
import { getPo, listApprovalSteps } from "@/features/procurement/queries";

export default async function ProcurementPoDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: poId } = await params;

  const [poRes, stepsRes] = await Promise.all([
    getPo(propertyId, poId),
    listApprovalSteps(propertyId, "po", poId),
  ]);

  if (!poRes.ok) {
    return <ErrorState description={poRes.error} />;
  }
  if (!poRes.data.po) {
    notFound();
  }

  return (
    <PoDetail
      propertyId={propertyId}
      po={poRes.data.po}
      lines={poRes.data.lines}
      steps={stepsRes.ok ? stepsRes.data : []}
    />
  );
}
