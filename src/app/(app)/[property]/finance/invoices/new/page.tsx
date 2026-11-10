import { ErrorState } from "@/components/common/error-state";
import { InvoiceForm } from "@/components/finance/invoice-form";
import { getFinancePerms } from "@/features/finance/queries";
import { listSuppliers } from "@/features/master/queries";
import { getPo, listPos } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/** Nhập hóa đơn mới (T-041): chọn NCC → đơn mua → nhập dòng. */
export default async function NewInvoicePage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ supplierId?: string; poId?: string }>;
}) {
  const { property: propertyId } = await params;
  const { supplierId = "", poId = "" } = await searchParams;

  const [suppliers, posRes, perms] = await Promise.all([
    listSuppliers({ propertyId }),
    listPos(propertyId, { pageSize: 100 }),
    getFinancePerms(propertyId),
  ]);

  if (!perms.canManageInvoice) {
    return <ErrorState description={vi.finance.noPermissionInvoice} />;
  }
  if (!posRes.ok) {
    return <ErrorState description={posRes.error} />;
  }

  let poLines = null;
  if (poId !== "") {
    const poRes = await getPo(propertyId, poId);
    if (!poRes.ok) {
      return <ErrorState description={poRes.error} />;
    }
    poLines = poRes.data.lines;
  }

  return (
    <div className="space-y-4">
      <PageHeader title={vi.finance.newInvoice} />
      <InvoiceForm
        key={poId}
        propertyId={propertyId}
        suppliers={suppliers}
        pos={posRes.data.rows}
        selectedSupplierId={supplierId}
        selectedPoId={poId}
        poLines={poLines}
      />
    </div>
  );
}
