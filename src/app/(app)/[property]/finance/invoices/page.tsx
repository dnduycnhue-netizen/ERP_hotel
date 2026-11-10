import { ErrorState } from "@/components/common/error-state";
import { InvoiceList } from "@/components/finance/invoice-list";
import { getFinancePerms, listInvoices } from "@/features/finance/queries";
import { listSuppliers } from "@/features/master/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/** Danh sách hóa đơn NCC (T-041). */
export default async function FinanceInvoicesPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [invoicesRes, perms] = await Promise.all([
    listInvoices(propertyId),
    getFinancePerms(propertyId),
  ]);
  const suppliers = await listSuppliers({ propertyId });

  if (!invoicesRes.ok) {
    return <ErrorState description={invoicesRes.error} />;
  }

  return (
    <div className="space-y-4">
      <PageHeader title={vi.finance.invoicesTitle} />
      <InvoiceList
        propertyId={propertyId}
        invoices={invoicesRes.data}
        suppliers={suppliers}
        canManageInvoice={perms.canManageInvoice}
      />
    </div>
  );
}
