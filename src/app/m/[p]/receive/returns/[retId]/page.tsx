import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { MobileReturnDetail } from "@/components/receiving/mobile-return-detail";
import { getSupplierReturnAction } from "@/features/receiving/actions";

/** Chi tiet phieu tra hang NCC tren mobile — xac nhan / huy (T-026). */
export default async function MobileReturnDetailPage({
  params,
}: {
  params: Promise<{ p: string; retId: string }>;
}) {
  const { p: propertyId, retId } = await params;

  const res = await getSupplierReturnAction(retId);

  if (!res.ok) {
    // supplier_return_get chi ra ERR_INVALID_VALUE khi khong tim thay
    // phieu (theo quy uoc cua module receiving, T-023).
    if (res.error.includes("ERR_INVALID_VALUE")) {
      notFound();
    }
    return <ErrorState description={res.error} />;
  }

  return <MobileReturnDetail detail={res.data} propertyId={propertyId} />;
}
