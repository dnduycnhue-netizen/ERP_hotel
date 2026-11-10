import { ErrorState } from "@/components/common/error-state";
import { PaymentRequestDetailView } from "@/components/finance/payment-request-detail";
import {
  getFinancePerms,
  getPaymentRequest,
  todayVn,
} from "@/features/finance/queries";
import { listSuppliers } from "@/features/master/queries";

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
    <div className="space-y-4">
      <PaymentRequestDetailView
        propertyId={propertyId}
        detail={detailRes.data}
        canApprovePayment={perms.canApprovePayment}
        canMarkPaid={perms.canMarkPaid}
        bankChangedRecently={bankChangedRecently}
      />
    </div>
  );
}
