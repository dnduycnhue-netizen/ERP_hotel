import type { ReactNode } from "react";
import Link from "next/link";
import { redirect } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { hasChainPerm } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/**
 * Mọi trang quản trị đều đọc session + quyền qua cookies() nên không thể
 * prerender tĩnh (Next 16 Cache Components): opt-out theo đúng hướng dẫn
 * của Next cho route đọc session — giữ chặn trên server theo request.
 */
export const instant = false;

export default async function AdminLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  const supabase = await createClient();
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError && userError.name !== "AuthSessionMissingError") {
    throw userError;
  }
  if (!userData.user) {
    redirect("/login");
  }

  const [canRoles, canUsers] = await Promise.all([
    hasChainPerm(supabase, "admin.roles.manage"),
    hasChainPerm(supabase, "admin.users.manage"),
  ]);

  if (!canRoles && !canUsers) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-muted/30 px-4">
        <div className="w-full max-w-lg rounded-lg border bg-card">
          <ErrorState
            title={vi.admin.noAccessTitle}
            description={vi.admin.noAccessDescription}
          />
          <p className="pb-6 text-center text-sm">
            <Link href="/" className="text-primary hover:underline">
              {vi.admin.backToDashboard}
            </Link>
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-muted/30">
      <header className="border-b bg-background">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center gap-4 px-4 py-4 sm:px-6">
          <Link className="font-semibold tracking-tight" href="/admin/roles">
            {vi.admin.title}
          </Link>
          <nav className="flex gap-4 text-sm">
            {canRoles ? (
              <Link
                href="/admin/roles"
                className="text-primary hover:underline"
              >
                {vi.admin.roles}
              </Link>
            ) : null}
            {canUsers ? (
              <Link
                href="/admin/users"
                className="text-primary hover:underline"
              >
                {vi.admin.users}
              </Link>
            ) : null}
          </nav>
          <Link
            href="/"
            className="ml-auto text-sm text-muted-foreground hover:underline"
          >
            {vi.admin.backToDashboard}
          </Link>
        </div>
      </header>
      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6">{children}</main>
    </div>
  );
}
