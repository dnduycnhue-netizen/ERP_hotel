import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { FrontdeskCheckDetail } from "@/components/minibar/frontdesk-check-detail";
import { MobileCheckForm } from "@/components/minibar/mobile-check-form";
import {
  getMinibarCheck,
  getMinibarPerms,
  listMinibarItems,
  listMinibarPrices,
} from "@/features/minibar/queries";

/**
 * Kiểm minibar 1 phòng — mobile buồng phòng (T-035).
 * Phiếu chưa kiểm → lưới món nhập số thiếu; phiếu đã kiểm xong →
 * xem lại kết quả (chỉ đọc với buồng phòng).
 */
export default async function MobileMinibarDetailPage({
  params,
}: {
  params: Promise<{ p: string; checkId: string }>;
}) {
  const { p: propertyId, checkId } = await params;

  const perms = await getMinibarPerms(propertyId);
  if (!perms.canCheck) {
    notFound();
  }

  const detailRes = await getMinibarCheck(checkId);
  if (!detailRes.ok) {
    return <ErrorState description={detailRes.error} />;
  }
  if (detailRes.data.check.property_id !== propertyId) {
    notFound();
  }

  const { check } = detailRes.data;
  if (check.checked_by !== null) {
    return (
      <FrontdeskCheckDetail
        propertyId={propertyId}
        detail={detailRes.data}
        perms={perms}
      />
    );
  }

  const [itemsRes, pricesRes] = await Promise.all([
    listMinibarItems(propertyId),
    listMinibarPrices(propertyId),
  ]);
  if (!itemsRes.ok) {
    return <ErrorState description={itemsRes.error} />;
  }
  if (!pricesRes.ok) {
    return <ErrorState description={pricesRes.error} />;
  }

  return (
    <MobileCheckForm
      propertyId={propertyId}
      check={check}
      items={itemsRes.data}
      prices={pricesRes.data}
    />
  );
}
