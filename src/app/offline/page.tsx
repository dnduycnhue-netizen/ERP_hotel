import type { Metadata } from "next";
import { WifiOff } from "lucide-react";
import { OfflineRetryButton } from "@/components/pwa/offline-retry-button";
import { vi } from "@/i18n/vi";

export const metadata: Metadata = {
  title: vi.pwa.offlinePageTitle,
};

/**
 * Trang du phong khi mat mang (T-046). Service worker tra ve trang nay
 * khi khong mo duoc trang nao (vd lan dau mo app luc mat mang).
 * Khong hien du lieu nguoi dung, khong can dang nhap — proxy.ts mien
 * /offline khoi chuyen huong ve /login.
 */
export default function OfflinePage() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
      <section className="w-full max-w-lg rounded-xl border bg-card p-6 text-center shadow-sm">
        <WifiOff className="mx-auto size-10" aria-hidden />
        <h1 className="mt-4 text-xl font-semibold">
          {vi.pwa.offlinePageTitle}
        </h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          {vi.pwa.offlinePageHint}
        </p>
        <OfflineRetryButton />
      </section>
    </main>
  );
}
