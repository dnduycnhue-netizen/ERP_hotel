import { ErrorState } from "@/components/common/error-state";
import { PaymentRequestList } from "@/components/finance/payment-request-list";
import {
  getFinancePerms,
  listPaymentRequests,
  type PaymentRequestStatus,
} from "@/features/finance/queries";
import { listSuppliers } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

const VALID_STATUSES = new Set([
  "draft",
  "submitted",
  "approved",
  "paid",
  "cancelled",
]);

/** Danh sách đề nghị thanh toán (T-041). */
export default async function FinancePaymentRequestsPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ status?: string }>;
}) {
  const { property: propertyId } = await params;
  const { status = "" } = await searchParams;

  const [requestsRes, perms] = await Promise.all([
    listPaymentRequests(propertyId),
    getFinancePerms(propertyId),
  ]);
  const suppliers = await listSuppliers({ propertyId });

  if (!requestsRes.ok) {
    return <ErrorState description={requestsRes.error} />;
  }

  const initialStatus: "" | PaymentRequestStatus = VALID_STATUSES.has(status)
    ? (status as PaymentRequestStatus)
    : "";

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">
        {vi.finance.paymentRequestsTitle}
      </h1>
      <PaymentRequestList
        propertyId={propertyId}
        requests={requestsRes.data}
        suppliers={suppliers}
        canRequestPayment={perms.canRequestPayment}
        initialStatus={initialStatus}
      />
    </div>
  );
}
