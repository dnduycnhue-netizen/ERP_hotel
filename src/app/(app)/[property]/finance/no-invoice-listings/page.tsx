import { ErrorState } from "@/components/common/error-state";
import { NoInvoiceForm } from "@/components/finance/no-invoice-form";
import { NoInvoiceList } from "@/components/finance/no-invoice-list";
import {
  getFinancePerms,
  listNoInvoiceListings,
} from "@/features/finance/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/** Bảng kê mua hàng không hóa đơn (T-041): danh sách + nhập mới + duyệt. */
export default async function FinanceNoInvoiceListingsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [listingsRes, perms] = await Promise.all([
    listNoInvoiceListings(propertyId, null),
    getFinancePerms(propertyId),
  ]);

  if (!listingsRes.ok) {
    return <ErrorState description={listingsRes.error} />;
  }

  return (
    <div className="space-y-4">
      <PageHeader title={vi.finance.listingsTitle} />
      {perms.canManageInvoice ? (
        <NoInvoiceForm propertyId={propertyId} />
      ) : (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.finance.noPermissionListing}
        </p>
      )}
      <NoInvoiceList
        propertyId={propertyId}
        listings={listingsRes.data}
        canApproveInvoice={perms.canApproveInvoice}
      />
    </div>
  );
}
