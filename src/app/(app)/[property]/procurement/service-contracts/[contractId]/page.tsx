import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { ContractDetail } from "@/components/service/contract-detail";
import {
  getServiceContract,
  getServicePerms,
} from "@/features/service/queries";

/** Chi tiết hợp đồng dịch vụ + lịch các kỳ (T-042). */
export default async function ServiceContractDetailPage({
  params,
}: {
  params: Promise<{ property: string; contractId: string }>;
}) {
  const { property: propertyId, contractId } = await params;

  const [detailRes, perms] = await Promise.all([
    getServiceContract(contractId),
    getServicePerms(propertyId),
  ]);

  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }
  if (detailRes.data.contract.property_id !== propertyId) {
    notFound();
  }

  return (
    <ContractDetail
      propertyId={propertyId}
      detail={detailRes.data}
      canManageContract={perms.canManageContract}
      canAccept={perms.canAccept}
    />
  );
}
