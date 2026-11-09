import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { PrDetail } from "@/components/procurement/pr-detail";
import { getPr, listApprovalSteps } from "@/features/procurement/queries";
import { listSuppliers } from "@/features/master/queries";

export default async function ProcurementPrDetailPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: prId } = await params;

  const [prRes, stepsRes, suppliers] = await Promise.all([
    getPr(propertyId, prId),
    listApprovalSteps(propertyId, "pr", prId),
    listSuppliers({ propertyId, status: "active" }),
  ]);

  if (!prRes.ok) {
    return <ErrorState description={prRes.error} />;
  }
  if (!prRes.data.pr) {
    notFound();
  }

  return (
    <PrDetail
      propertyId={propertyId}
      pr={prRes.data.pr}
      lines={prRes.data.lines}
      steps={stepsRes.ok ? stepsRes.data : []}
      suppliers={suppliers}
    />
  );
}
