import { ErrorState } from "@/components/common/error-state";
import { PaymentRequestDetailView } from "@/components/finance/payment-request-detail";
import {
  getFinancePerms,
  getPaymentRequest,
  todayVn,
} from "@/features/finance/queries";
import { listApprovalSteps } from "@/features/procurement/queries";
import { listSuppliers } from "@/features/master/queries";
import { vi } from "@/i18n/vi";

/** Chi tiết đề nghị thanh toán (T-041): dòng + tiến trình + duyệt + đã trả. */
export default async function PaymentRequestDetailPage({
  params,
}: {
  params: Promise<{ property: string; requestId: string }>;
}) {
  const { property: propertyId, requestId } = await params;

  const [detailRes, perms] = await Promise.all([
    getPaymentRequest(requestId),
    getFinancePerms(propertyId),
  ]);

  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }

  // Timeline duyệt chi tiết (Q73): đọc qua `approval_timeline` với
  // doc_type 'payment_request'. Người chỉ có quyền xem công nợ
  // (ap.view) mà không có payment.* sẽ bị ERR_FORBIDDEN ở RPC này —
  // trang chi tiết vẫn hiện bình thường, chỉ không có khung bước duyệt.
  const stepsRes = await listApprovalSteps(
    propertyId,
    "payment_request",
    requestId,
  );
  const approvalSteps = stepsRes.ok ? stepsRes.data : [];

  // NCC đổi STK trong 30 ngày gần nhất → đề nghị cần thêm bước duyệt
  // owner (05 §8, quyết định T-040). Đọc từ `suppliers.bank_changed_at`,
  // so sánh theo ngày giờ Việt Nam như RPC (bank_changed_at at time zone
  // 'Asia/Ho_Chi_Minh')::date >= today - 30.
  const suppliers = await listSuppliers({ propertyId });
  const supplier = suppliers.find(
    (s) => s.id === detailRes.data.request.supplier_id,
  );
  const bankChangedAt = supplier?.bank_changed_at ?? null;
  const today = todayVn();
  const thirtyDaysAgo = new Date(
    new Date(`${today}T00:00:00+07:00`).getTime() - 30 * 86400000,
  ).toLocaleDateString("en-CA", { timeZone: "Asia/Ho_Chi_Minh" });
  const bankChangedRecently =
    bankChangedAt !== null &&
    new Date(bankChangedAt).toLocaleDateString("en-CA", {
      timeZone: "Asia/Ho_Chi_Minh",
    }) >= thirtyDaysAgo;

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">
        {vi.finance.paymentRequestsTitle}
      </h1>
      <PaymentRequestDetailView
        propertyId={propertyId}
        detail={detailRes.data}
        approvalSteps={approvalSteps}
        canApprovePayment={perms.canApprovePayment}
        canMarkPaid={perms.canMarkPaid}
        bankChangedRecently={bankChangedRecently}
      />
    </div>
  );
}
