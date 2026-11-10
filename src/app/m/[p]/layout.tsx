import type { Viewport } from "next";
import type { ReactNode } from "react";
import { notFound, redirect } from "next/navigation";
import { Button } from "@/components/ui/button";
import { MobileNav } from "@/components/common/mobile-nav";
import { OfflineBanner } from "@/components/common/offline-banner";
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
 * Layout màn hình hiện trường `/m/[p]` (T-024).
 *
 * Cùng cơ chế bảo vệ như layout văn phòng: chưa đăng nhập → /login;
 * tài khoản bị khóa → màn hình báo không dùng được; khách sạn không
 * thuộc quyền → 404. Header gọn cho một tay: tên app + tên khách sạn.
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
      <div className="min-h-screen bg-muted/30">
        <header className="sticky top-0 z-10 border-b bg-background">
          <div className="mx-auto flex max-w-2xl items-center justify-between gap-3 px-4 py-3">
            <a
              className="truncate font-semibold tracking-tight"
              href={`/m/${currentProperty.id}/receive`}
            >
              {vi.appName}
            </a>
            <span className="shrink-0 text-sm text-muted-foreground">
              {currentProperty.name}
            </span>
          </div>
        </header>
        <main className="mx-auto max-w-2xl px-4 py-6">
          <MobileNav propertyId={currentProperty.id} />
          <div className="mb-4">
            <InstallPrompt />
            <OfflineBanner />
          </div>
          {children}
        </main>
      </div>
    </PermissionsProvider>
  );
}
