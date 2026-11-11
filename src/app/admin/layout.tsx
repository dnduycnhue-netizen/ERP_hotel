import type { ReactNode } from "react";
import Link from "next/link";
import { connection } from "next/server";
import { redirect } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { hasChainPerm } from "@/features/admin";
import { hasAdminConfigPermission } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { listAccessibleProperties } from "@/lib/supabase/access";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";

/**
 * Mọi trang quản trị đều đọc session + quyền qua cookies() nên không thể
 * prerender tĩnh (Next 16 Cache Components).
 * - `export const instant = false`: opt-out khỏi instant navigation
 *   validation (route đọc session thì không prefetch được) — cấu hình
 *   thật của Next, giữ nguyên.
 * - `await connection()` dưới đây mới là thứ chặn prerender: không có
 *   nó, Next thử prerender trang và nổ lỗi `Date.now()` khi Supabase
 *   nạp session (gặp ngày 11/11/2026 ở /admin/organizations,
 *   /admin/roles). Xem `docs/OPEN-QUESTIONS.md` Q202.
 */
export const instant = false;

export default async function AdminLayout({
  children,
}: Readonly<{ children: ReactNode }>) {
  await connection();
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);
  if (!user) {
    redirect("/login");
  }

  const [canRoles, canUsers, canOrg, properties] = await Promise.all([
    hasChainPerm(supabase, "admin.roles.manage"),
    hasChainPerm(supabase, "admin.users.manage"),
    hasChainPerm(supabase, "admin.org.manage"),
    listAccessibleProperties(supabase),
  ]);

  async function hasConfigAccess(permission: string): Promise<boolean> {
    if (await hasAdminConfigPermission(supabase, permission, null)) {
      return true;
    }
    // Kiểm tra theo từng khách sạn không phụ thuộc nhau nên chạy song song;
    // giữ nguyên ngữ nghĩa: đúng khi có bất kỳ phạm vi nào cấp quyền.
    const perProperty = await Promise.all(
      properties.map((property) =>
        hasAdminConfigPermission(supabase, permission, property.id),
      ),
    );
    return perProperty.some(Boolean);
  }

  const [canSettings, canApprovalRules, canAlertRules] = await Promise.all([
    hasConfigAccess("admin.settings.manage"),
    hasConfigAccess("admin.approval_rules.manage"),
    hasConfigAccess("admin.alert_rules.manage"),
  ]);

  if (
    !canRoles &&
    !canUsers &&
    !canOrg &&
    !canSettings &&
    !canApprovalRules &&
    !canAlertRules
  ) {
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
            {canOrg ? (
              <Link
                href="/admin/organizations"
                className="text-primary hover:underline"
              >
                {vi.admin.organizations}
              </Link>
            ) : null}
            {canSettings ? (
              <Link
                href="/admin/settings"
                className="text-primary hover:underline"
              >
                {vi.admin.settings}
              </Link>
            ) : null}
            {canApprovalRules ? (
              <Link
                href="/admin/approval-rules"
                className="text-primary hover:underline"
              >
                {vi.admin.approvalRules}
              </Link>
            ) : null}
            {canAlertRules ? (
              <Link
                href="/admin/alert-rules"
                className="text-primary hover:underline"
              >
                {vi.admin.alertRules}
              </Link>
            ) : null}
            <Link
              href="/settings/password"
              className="text-primary hover:underline"
            >
              {vi.password.changePasswordTitle}
            </Link>
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
