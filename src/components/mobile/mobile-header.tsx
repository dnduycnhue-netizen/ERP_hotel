"use client";

import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { ContextHelpLink } from "@/components/help/context-help-link";
import { vi } from "@/i18n/vi";

/**
 * Header chuẩn cho màn hình hiện trường `/m/[p]` (W1).
 *
 * Một header duy nhất cho mọi màn mobile: tên màn (suy ra từ route),
 * tên khách sạn đang chọn, nút back về màn danh sách khi đang ở trang
 * con (chi tiết phiếu / form mới). Sticky trên cùng, chừa
 * `env(safe-area-inset-top)` cho iPhone có notch.
 *
 * Các màn con của W2/W3/W4 KHÔNG tự render header riêng — tiêu đề lấy
 * từ bảng dưới đây. Màn mới thêm route thì bổ sung 1 dòng vào
 * `SECTION_TITLES`; trang con tự động có nút back về màn danh sách.
 */
const SECTION_TITLES: Record<string, string> = {
  receive: vi.mobile.navReceive,
  count: vi.mobile.navCount,
  trolley: vi.mobile.navTrolley,
  minibar: vi.mobile.navMinibar,
  help: vi.help.nav,
};

export function MobileHeader({
  propertyId,
  propertyName,
}: {
  propertyId: string;
  propertyName: string;
}) {
  const pathname = usePathname();
  // /m/[p]/<section>/... → section = đoạn thứ 3.
  const segments = pathname.split("/").filter(Boolean);
  const section = segments[2] ?? "";
  const title = SECTION_TITLES[section] ?? vi.appName;
  const listHref = `/m/${propertyId}/${section}`;
  const isDetailPage = segments.length > 3 && section !== "";

  return (
    <header className="sticky top-0 z-40 border-b bg-background pt-[env(safe-area-inset-top)]">
      <div className="mx-auto flex max-w-2xl items-center gap-1 px-2 py-2">
        {isDetailPage ? (
          <Link
            href={listHref}
            aria-label={vi.common.back}
            className="flex min-h-11 min-w-11 shrink-0 items-center justify-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          >
            <ArrowLeft className="size-5" aria-hidden />
          </Link>
        ) : (
          <span className="min-w-11 shrink-0" aria-hidden />
        )}
        <div className="min-w-0 flex-1 px-1">
          <h1 className="truncate text-center text-base leading-tight font-semibold">
            {title}
          </h1>
          <p className="truncate text-center text-xs text-muted-foreground">
            {propertyName}
          </p>
        </div>
        <div className="flex min-w-11 shrink-0 items-center justify-center">
          <ContextHelpLink
            basePath={`/m/${propertyId}/help`}
            className="size-11"
          />
        </div>
      </div>
    </header>
  );
}
