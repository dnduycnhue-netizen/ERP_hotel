import { ErrorState } from "@/components/common/error-state";
import { ContractForm } from "@/components/service/contract-form";
import { getServicePerms } from "@/features/service/queries";
import {
  listCostCenters,
  listExpenseCategories,
  listSuppliers,
} from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/** Tạo hợp đồng dịch vụ mới (T-042). */
export default async function NewServiceContractPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const perms = await getServicePerms(propertyId);

  if (!perms.canManageContract) {
    return <ErrorState description={vi.service.noPermissionContract} />;
  }

  const [suppliers, expenseCategories, costCenters] = await Promise.all([
    listSuppliers({ propertyId }),
    listExpenseCategories(propertyId),
    listCostCenters(propertyId),
  ]);

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">{vi.service.createTitle}</h1>
      <ContractForm
        propertyId={propertyId}
        contract={null}
        suppliers={suppliers}
        expenseCategories={expenseCategories}
        costCenters={costCenters}
      />
    </div>
  );
}
