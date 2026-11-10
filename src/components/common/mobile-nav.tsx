"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useCan } from "@/lib/permissions/permissions-provider";
import { cn } from "@/lib/utils";
import { vi } from "@/i18n/vi";

/**
 * Điều hướng nhanh màn hình hiện trường (T-035): Nhận hàng / Kiểm kê /
 * Kiểm minibar / Xe đẩy. Chỉ hiện mục mà user có quyền dùng. Mobile
 * trước đây không có nav chung nên các màn chỉ liên kết qua lại bằng
 * link "←".
 */
export function MobileNav({ propertyId }: { propertyId: string }) {
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

  const canCount =
    canCountOpen ||
    canCountPerform ||
    canCountViewVariance ||
    canCountLock ||
    canCountAdjustApprove;

  const links: { href: string; label: string }[] = [];
  if (canReceive) {
    links.push({
      href: `/m/${propertyId}/receive`,
      label: vi.receiving.tasksTitle,
    });
  }
  if (canCount) {
    links.push({
      href: `/m/${propertyId}/count`,
      label: vi.count.countsTitle,
    });
  }
  if (canMinibarCheck) {
    links.push({
      href: `/m/${propertyId}/minibar`,
      label: vi.minibar.mobileTitle,
    });
  }
  if (canTrolleyOperate) {
    links.push({
      href: `/m/${propertyId}/trolley`,
      label: vi.trolley.mobileTitle,
    });
  }

  if (links.length === 0) {
    return null;
  }

  return (
    <nav className="mb-4 flex flex-wrap gap-2">
      {links.map((link) => {
        const isActive = pathname.startsWith(link.href);
        return (
          <Link
            key={link.href}
            href={link.href}
            className={cn(
              "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
              isActive
                ? "bg-primary text-primary-foreground shadow-sm"
                : "bg-card text-muted-foreground hover:bg-muted hover:text-foreground",
            )}
          >
            {link.label}
          </Link>
        );
      })}
    </nav>
  );
}
