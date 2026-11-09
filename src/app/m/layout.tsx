import type { ReactNode } from "react";
import { Suspense } from "react";
import { vi } from "@/i18n/vi";

/**
 * Nhóm route hiện trường `/m`: bọc mọi trang trong Suspense như layout
 * văn phòng (`(app)/layout.tsx`) để trang động (đọc `params`,
 * `searchParams`, cookie phiên) không bị prerender lúc build.
 */
export default function MobileLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  return (
    <Suspense
      fallback={
        <main
          aria-busy="true"
          aria-live="polite"
          className="flex min-h-screen items-center justify-center px-6"
        >
          <p className="text-sm text-muted-foreground">{vi.common.loading}</p>
        </main>
      }
    >
      {children}
    </Suspense>
  );
}
