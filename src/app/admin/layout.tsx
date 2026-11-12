import type { ReactNode } from "react";
import Link from "next/link";
import { connection } from "next/server";
import { redirect } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { AppShell } from "@/components/shell/app-shell";
import { hasChainPerm } from "@/features/admin";
import { hasAdminConfigPermission } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { PermissionsProvider } from "@/lib/permissions/permissions-provider";
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

  const [canRoles, canUsers, canOrg, canHealth, properties] = await Promise.all([
    hasChainPerm(supabase, "admin.roles.manage"),
    hasChainPerm(supabase, "admin.users.manage"),
    hasChainPerm(supabase, "admin.org.manage"),
    hasChainPerm(supabase, "admin.health.view"),
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
    !canAlertRules &&
    !canHealth
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

  // Quyền cấp chuỗi + tên hiển thị cho vỏ ClickUp: my_permissions(null)
  // trả quyền cấp chuỗi; full_name đọc 1 câu profiles theo user.id —
  // không gọi getUser() lần 2 (user đã có từ getAuthenticatedUser).
  const [{ data: chainPermissions }, { data: profile }] = await Promise.all([
    supabase.rpc("my_permissions", { p_property: null }),
    supabase
      .from("profiles")
      .select("full_name")
      .eq("id", user.id)
      .maybeSingle(),
  ]);

  return (
    <PermissionsProvider
      propertyId={null}
      initialPermissions={chainPermissions ?? []}
    >
      <AppShell
        mode="admin"
        adminNav={{
          roles: canRoles,
          users: canUsers,
          organizations: canOrg,
          settings: canSettings,
          approvalRules: canApprovalRules,
          alertRules: canAlertRules,
          health: canHealth,
        }}
        userEmail={user.email}
        userName={profile?.full_name ?? null}
      >
        {children}
      </AppShell>
    </PermissionsProvider>
  );
}
