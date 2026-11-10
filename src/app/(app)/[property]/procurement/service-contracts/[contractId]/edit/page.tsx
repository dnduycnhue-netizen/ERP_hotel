import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { ContractForm } from "@/components/service/contract-form";
import {
  getServiceContract,
  getServicePerms,
} from "@/features/service/queries";
import {
  listCostCenters,
  listExpenseCategories,
  listSuppliers,
} from "@/features/master/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/** Sửa hợp đồng dịch vụ (T-042). */
export default async function EditServiceContractPage({
  params,
}: {
  params: Promise<{ property: string; contractId: string }>;
}) {
  const { property: propertyId, contractId } = await params;
  const perms = await getServicePerms(propertyId);

  if (!perms.canManageContract) {
    return <ErrorState description={vi.service.noPermissionContract} />;
  }

  const detailRes = await getServiceContract(contractId);
  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }
  if (detailRes.data.contract.property_id !== propertyId) {
    notFound();
  }

  const [suppliers, expenseCategories, costCenters] = await Promise.all([
    listSuppliers({ propertyId }),
    listExpenseCategories(propertyId),
    listCostCenters(propertyId),
  ]);

  return (
    <div className="space-y-4">
      <PageHeader title={vi.service.editTitle} />
      <ContractForm
        propertyId={propertyId}
        contract={detailRes.data.contract}
        suppliers={suppliers}
        expenseCategories={expenseCategories}
        costCenters={costCenters}
      />
    </div>
  );
}
