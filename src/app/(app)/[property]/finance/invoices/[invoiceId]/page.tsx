import { ErrorState } from "@/components/common/error-state";
import { InvoiceDetailView } from "@/components/finance/invoice-detail";
import { getFinancePerms, getInvoice } from "@/features/finance/queries";
import { createClient } from "@/lib/supabase/server";

/** Chi tiết hóa đơn (T-041): dòng + kết quả khớp + Khớp / Duyệt. */
export default async function InvoiceDetailPage({
  params,
}: {
  params: Promise<{ property: string; invoiceId: string }>;
}) {
  const { property: propertyId, invoiceId } = await params;
  const supabase = await createClient();

  const [{ data: userData }, detailRes, perms] = await Promise.all([
    supabase.auth.getUser(),
    getInvoice(invoiceId),
    getFinancePerms(propertyId),
  ]);

  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }

  return (
    <div className="space-y-4">
      <InvoiceDetailView
        propertyId={propertyId}
        detail={detailRes.data}
        canManageInvoice={perms.canManageInvoice}
        canApproveInvoice={perms.canApproveInvoice}
        isCreator={detailRes.data.invoice.created_by === userData.user?.id}
      />
    </div>
  );
}
