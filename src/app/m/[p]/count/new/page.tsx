import { ErrorState } from "@/components/common/error-state";
import { CountOpenForm } from "@/components/count/count-open-form";
import { listWarehouses } from "@/features/master/queries";

/** Mở đợt kiểm kê mobile (T-033). */
export default async function MobileCountNewPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;
  const warehouses = await listWarehouses(propertyId);
  if (warehouses.length === 0) {
    return <ErrorState />;
  }

  return (
    <CountOpenForm
      propertyId={propertyId}
      warehouses={warehouses}
      afterOpenBase={`/m/${propertyId}/count`}
    />
  );
}
