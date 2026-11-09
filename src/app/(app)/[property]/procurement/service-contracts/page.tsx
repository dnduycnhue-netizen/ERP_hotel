import { ErrorState } from "@/components/common/error-state";
import { ContractList } from "@/components/service/contract-list";
import {
  getServicePerms,
  listServiceContracts,
} from "@/features/service/queries";
import { listSuppliers } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/** Danh sách hợp đồng dịch vụ (T-042). */
export default async function ServiceContractsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [contractsRes, perms] = await Promise.all([
    listServiceContracts(propertyId),
    getServicePerms(propertyId),
  ]);
  const suppliers = await listSuppliers({ propertyId });

  if (!contractsRes.ok) {
    return <ErrorState description={contractsRes.error} />;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl font-semibold">{vi.service.listTitle}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.service.listHint}
        </p>
      </div>
      <ContractList
        propertyId={propertyId}
        contracts={contractsRes.data}
        suppliers={suppliers}
        canManageContract={perms.canManageContract}
      />
    </div>
  );
}
