import { RoleList } from "@/components/admin/role-list";
import { connection } from "next/server";
import {
  getAdminOrgId,
  hasChainPerm,
  listPermissions,
  listRoles,
} from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

export default async function RolesPage() {
  // Chặn prerender (Q202): trang đọc session Supabase — không có dòng
  // này, Next 16 thử prerender và nổ lỗi `Date.now()` khi nạp session.
  await connection();
  const supabase = await createClient();
  const [orgId, roles, permissions] = await Promise.all([
    getAdminOrgId(supabase),
    listRoles(supabase),
    listPermissions(supabase),
  ]);
  const { data: rolePerms } = await supabase
    .from("role_permissions")
    .select("role_id, permission_code");
  const rolePermissions: Record<string, string[]> = {};
  for (const row of rolePerms ?? []) {
    const list = rolePermissions[row.role_id] ?? [];
    list.push(row.permission_code);
    rolePermissions[row.role_id] = list;
  }
  const canManage = await hasChainPerm(supabase, "admin.roles.manage");

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">
          {vi.admin.rolesTitle}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.admin.rolesDescription}
        </p>
      </div>
      <RoleList
        roles={roles}
        rolePermissions={rolePermissions}
        permissions={permissions}
        orgId={orgId}
        canManage={canManage}
      />
    </div>
  );
}
