import { ErrorState } from "@/components/common/error-state";
import { CountOpenForm } from "@/components/count/count-open-form";
import { listWarehouses } from "@/features/master/queries";

/** Mở đợt kiểm kê (bản desktop, T-033) — dùng chung form với mobile. */
export default async function CountNewPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const warehouses = await listWarehouses(propertyId);
  if (warehouses.length === 0) {
    return <ErrorState />;
  }

  return (
    <CountOpenForm
      propertyId={propertyId}
      warehouses={warehouses}
      afterOpenHref={(countId) => `/${propertyId}/inventory/counts/${countId}`}
    />
  );
}
