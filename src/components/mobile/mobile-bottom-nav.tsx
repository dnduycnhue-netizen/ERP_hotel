"use client";

import {
  BedDouble,
  ClipboardList,
  PackageCheck,
  Refrigerator,
  UtensilsCrossed,
  type LucideIcon,
} from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

type BottomNavItem = {
  href: string;
  label: string;
  Icon: LucideIcon;
};

/**
 * Bottom tab nav cho màn hình hiện trường `/m/[p]` (W1).
 *
 * Thay thanh pill `MobileNav` cũ ở đầu trang (ADR-006 giữ `MobileNav`
 * cho giai đoạn 1 — xem Q174): tab cố định dưới đáy, chạm được bằng
 * một tay, mục đang chọn tím #7B68EE (`text-brand`) kèm `aria-current`.
 * Chỉ hiện mục mà user có quyền dùng (cùng mã quyền như `MobileNav`):
 * nhận hàng `receiving.view`, kiểm kê 1 trong 5 quyền `count.*`,
 * minibar `minibar.check`, xe đẩy `hk.trolley.operate`.
 *
 * Đáy tab chừa `env(safe-area-inset-bottom)` cho iPhone có notch/home
 * indicator; layout `/m/[p]` phải chừa padding đáy tương ứng cho nội
 * dung (xem `MobilePropertyLayout`).
 */
export function MobileBottomNav({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();

  // Mỗi useCan phải gọi vô điều kiện (không OR trực tiếp trên lời gọi
  // hook — ESLint react-hooks/rules-of-hooks bắt lỗi này).
  const canReceive = useCan("receiving.view");
  const canCountOpen = useCan("count.open");
  const canCountPerform = useCan("count.perform");
  const canCountViewVariance = useCan("count.view_variance");
  const canCountLock = useCan("count.lock");
  const canCountAdjustApprove = useCan("count.adjust.approve");
  const canMinibarCheck = useCan("minibar.check");
  const canTrolleyOperate = useCan("hk.trolley.operate");
  const canRestaurantView = useCan("restaurant.view");

  const canCount =
    canCountOpen ||
    canCountPerform ||
    canCountViewVariance ||
    canCountLock ||
    canCountAdjustApprove;

  const items: BottomNavItem[] = [];
  if (canReceive) {
    items.push({
      href: `/m/${propertyId}/receive`,
      label: vi.mobile.navReceive,
      Icon: PackageCheck,
    });
  }
  if (canCount) {
    items.push({
      href: `/m/${propertyId}/count`,
      label: vi.mobile.navCount,
      Icon: ClipboardList,
    });
  }
  if (canRestaurantView) {
    items.push({
      href: `/m/${propertyId}/restaurant`,
      label: vi.mobile.navRestaurant,
      Icon: UtensilsCrossed,
    });
  }
  if (canTrolleyOperate) {
    items.push({
      href: `/m/${propertyId}/trolley`,
      label: vi.mobile.navTrolley,
      Icon: BedDouble,
    });
  }
  if (canMinibarCheck) {
    items.push({
      href: `/m/${propertyId}/minibar`,
      label: vi.mobile.navMinibar,
      Icon: Refrigerator,
    });
  }

  if (items.length === 0) {
    return null;
  }

  return (
    <nav
      aria-label={vi.mobile.navLabel}
      className="fixed inset-x-0 bottom-0 z-40 border-t bg-background pb-[env(safe-area-inset-bottom)]"
    >
      <ul className="mx-auto flex max-w-2xl">
        {items.map(({ href, label, Icon }) => {
          const isActive = pathname.startsWith(href);
          return (
            <li key={href} className="min-w-0 flex-1">
              <Link
                href={href}
                aria-current={isActive ? "page" : undefined}
                className={cn(
                  "flex min-h-14 flex-col items-center justify-center gap-0.5 px-1 py-2 text-[11px] leading-tight font-medium transition-colors",
                  isActive
                    ? "text-brand"
                    : "text-muted-foreground hover:text-foreground",
                )}
              >
                <Icon
                  className={cn("size-5", isActive && "stroke-[2.5]")}
                  aria-hidden
                />
                <span className="truncate">{label}</span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
