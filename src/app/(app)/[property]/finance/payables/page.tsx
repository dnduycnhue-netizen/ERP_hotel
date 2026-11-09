import { ErrorState } from "@/components/common/error-state";
import { PayablesView } from "@/components/finance/payables-view";
import {
  getApAging,
  getFinancePerms,
  listApLedger,
} from "@/features/finance/queries";
import { listSuppliers } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/** Công nợ nhà cung cấp (T-041): tuổi nợ theo due_date + sổ chi tiết. */
export default async function FinancePayablesPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [agingRes, ledgerRes, perms] = await Promise.all([
    getApAging(propertyId),
    listApLedger(propertyId),
    getFinancePerms(propertyId),
  ]);
  const suppliers = await listSuppliers({ propertyId });

  if (
    !perms.canViewAp &&
    !perms.canManageInvoice &&
    !perms.canApproveInvoice &&
    !perms.canRequestPayment &&
    !perms.canApprovePayment &&
    !perms.canMarkPaid
  ) {
    return <ErrorState description={vi.finance.noPermissionAp} />;
  }
  if (!agingRes.ok) {
    return <ErrorState description={agingRes.error} />;
  }
  if (!ledgerRes.ok) {
    return <ErrorState description={ledgerRes.error} />;
  }

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">{vi.finance.payablesTitle}</h1>
      <PayablesView
        aging={agingRes.data}
        ledger={ledgerRes.data}
        suppliers={suppliers}
      />
    </div>
  );
}
