import { ErrorState } from "@/components/common/error-state";
import { MobileReturnsList } from "@/components/receiving/mobile-returns-list";
import { listSupplierReturnsAction } from "@/features/receiving/actions";

/**
 * Danh sách phiếu trả hàng NCC trên mobile (T-026).
 * Loc theo trang thai qua ?status=recorded|posted|cancelled.
 * RPC `supplier_return_list` chi tra gia khi caller co `po.view_price`.
 */
export default async function MobileReturnsPage({
  params,
  searchParams,
}: {
  params: Promise<{ p: string }>;
  searchParams: Promise<{ status?: string }>;
}) {
  const { p: propertyId } = await params;
  const { status } = await searchParams;

  const res = await listSupplierReturnsAction({
    propertyId,
    status:
      status === "recorded" || status === "posted" || status === "cancelled"
        ? status
        : null,
    limit: 50,
    offset: 0,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return (
    <MobileReturnsList
      returns={res.data.returns}
      total={res.data.total}
      propertyId={propertyId}
    />
  );
}
