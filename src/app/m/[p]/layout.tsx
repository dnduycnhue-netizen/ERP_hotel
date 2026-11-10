import type { Viewport } from "next";
import type { ReactNode } from "react";
import { notFound, redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MobileBottomNav } from "@/components/mobile/mobile-bottom-nav";
import { MobileHeader } from "@/components/mobile/mobile-header";
import { MobileOfflineBanner } from "@/components/mobile/mobile-offline-banner";
import { InstallPrompt } from "@/components/pwa/install-prompt";
import { vi } from "@/i18n/vi";
import { PermissionsProvider } from "@/lib/permissions/permissions-provider";
import { listAccessibleProperties } from "@/lib/supabase/access";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";
import { signOut } from "../../(auth)/login/actions";

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
};

/**
 * Layout màn hình hiện trường `/m/[p]` (T-024, shell chuẩn hóa W1).
 *
 * Cùng cơ chế bảo vệ như layout văn phòng: chưa đăng nhập → /login;
 * tài khoản bị khóa → màn hình báo không dùng được; khách sạn không
 * thuộc quyền → 404.
 *
 * Shell mobile (W1): `MobileHeader` sticky (tên màn + tên khách sạn +
 * nút back khi ở trang con) + `MobileBottomNav` cố định dưới đáy (4
 * đích: Nhận hàng / Kiểm kê / Buồng phòng / Minibar, mục active tím
 * #7B68EE) + `MobileOfflineBanner`. Nội dung chừa padding đáy cho tab
 * bar (`pb` = chiều cao tab ~56px + safe-area iOS) và dùng chữ cơ bản
 * 16px. Các màn con (W2/W3/W4) chỉ render nội dung bên trong shell.
 */
export default async function MobilePropertyLayout({
  children,
  params,
}: Readonly<{
  children: ReactNode;
  params: Promise<{ p: string }>;
}>) {
  const { p: propertyId } = await params;
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    redirect("/login");
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("active")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError) {
    console.error("Unable to verify the current profile.", profileError);
    throw profileError;
  }

  if (!profile?.active) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-muted/40 px-4 py-10">
        <section className="w-full max-w-lg rounded-xl border bg-card p-6 shadow-sm">
          <h1 className="text-xl font-semibold">
            {vi.auth.accountUnavailable}
          </h1>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            {vi.auth.accountUnavailableDescription}
          </p>
          <form action={signOut} className="mt-6">
            <Button type="submit">{vi.auth.signOut}</Button>
          </form>
        </section>
      </main>
    );
  }

  const [properties, { data: myPermissions }] = await Promise.all([
    listAccessibleProperties(supabase),
    supabase.rpc("my_permissions", { p_property: propertyId }),
  ]);

  const currentProperty = properties.find(({ id }) => id === propertyId);
  if (!currentProperty) {
    notFound();
  }

  return (
    <PermissionsProvider
      key={propertyId}
      propertyId={propertyId}
      initialPermissions={myPermissions ?? []}
    >
      <div className="min-h-screen bg-muted/30 text-base">
        <MobileHeader
          propertyId={currentProperty.id}
          propertyName={currentProperty.name}
        />
        <main className="mx-auto max-w-2xl px-4 pt-4 pb-[calc(4.5rem+env(safe-area-inset-bottom))]">
          <div className="mb-4">
            <InstallPrompt />
            <MobileOfflineBanner />
          </div>
          {children}
        </main>
        <MobileBottomNav propertyId={currentProperty.id} />
      </div>
    </PermissionsProvider>
  );
}
