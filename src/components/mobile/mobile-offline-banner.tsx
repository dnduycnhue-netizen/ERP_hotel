import { OfflineBanner } from "@/components/common/offline-banner";

/**
 * Banner trạng thái mạng + đồng bộ offline cho màn hình hiện trường
 * (W1) — điểm vào duy nhất từ shell mobile.
 *
 * Không viết lại logic: `OfflineBanner` (`@/components/common/`)
 * vẫn là nguồn sự thật duy nhất (trạng thái `useOfflineSync`, nút
 * đồng bộ lại / hủy thao tác lỗi). Wrapper này tồn tại để mọi màn
 * mobile chỉ import từ `@/components/mobile/*` và để W1 có chỗ gắn
 * chuẩn mobile sau này (vd vị trí sticky dưới header) mà không sửa
 * component dùng chung.
 */
export function MobileOfflineBanner() {
  return <OfflineBanner />;
}
