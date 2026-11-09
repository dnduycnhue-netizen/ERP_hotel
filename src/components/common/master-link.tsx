"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu vực danh mục vật tư & cơ cấu của khách sạn.
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function MasterLink({ propertyId }: { propertyId: string }) {
  const canItemView = useCan("item.view");
  const canItemManage = useCan("item.manage");
  const canWarehouseManage = useCan("warehouse.manage");
  const canRoomManage = useCan("room.manage");
  const canSupplierView = useCan("supplier.view");
  const canPriceView = useCan("price.view");

  const canView =
    canItemView ||
    canItemManage ||
    canWarehouseManage ||
    canRoomManage ||
    canSupplierView ||
    canPriceView;

  if (!canView) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/master/items`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.master.title}
    </Link>
  );
}
