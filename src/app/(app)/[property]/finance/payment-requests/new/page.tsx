import { ErrorState } from "@/components/common/error-state";
import { PaymentRequestForm } from "@/components/finance/payment-request-form";
import {
  getFinancePerms,
  listPayableInvoices,
} from "@/features/finance/queries";
import { listSuppliers } from "@/features/master/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/** Tạo đề nghị thanh toán (T-041): chọn NCC → hóa đơn còn lại → số tiền. */
export default async function NewPaymentRequestPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ supplierId?: string }>;
}) {
  const { property: propertyId } = await params;
  const { supplierId = "" } = await searchParams;

  const [suppliers, perms] = await Promise.all([
    listSuppliers({ propertyId }),
    getFinancePerms(propertyId),
  ]);

  if (!perms.canRequestPayment) {
    return <ErrorState description={vi.finance.noPermissionPayment} />;
  }

  let payableInvoices = null;
  if (supplierId !== "") {
    const res = await listPayableInvoices(propertyId, supplierId);
    if (!res.ok) {
      return <ErrorState description={res.error} />;
    }
    payableInvoices = res.data;
  }

  return (
    <div className="space-y-4">
      <PageHeader title={vi.finance.newPaymentRequest} />
      <PaymentRequestForm
        key={supplierId}
        propertyId={propertyId}
        suppliers={suppliers}
        selectedSupplierId={supplierId}
        payableInvoices={payableInvoices}
      />
    </div>
  );
}
