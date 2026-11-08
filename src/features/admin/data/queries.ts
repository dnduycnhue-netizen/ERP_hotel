import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { listAccessibleProperties } from "@/lib/supabase/access";
import type { Database } from "@/lib/database.types";
import { callAdminRpc } from "../rpc";

type Client = SupabaseClient<Database>;

export type RoleRow = {
  id: string;
  org_id: string;
  code: string;
  name_vi: string;
  description: string | null;
  is_system: boolean;
  active: boolean;
  copied_from_id: string | null;
  created_at: string;
};

export type RoleSummary = RoleRow & {
  permissionCount: number;
  holderCount: number;
};

export type PermissionRow = {
  code: string;
  module: string;
  name_vi: string;
  description_vi: string;
  risk_level: "normal" | "sensitive" | "critical";
  sort_order: number;
};

export type UserRow = {
  id: string;
  employee_code: string | null;
  full_name: string;
  phone: string | null;
  active: boolean;
  created_at: string;
};

export type AssignmentRow = {
  id: string;
  user_id: string;
  role_id: string;
  role_code: string;
  role_name: string;
  property_id: string | null;
  property_name: string | null;
  outlet_ids: string[] | null;
  warehouse_ids: string[] | null;
  valid_from: string;
  valid_to: string | null;
  granted_by: string | null;
};

export type OverrideRow = {
  id: string;
  user_id: string;
  property_id: string | null;
  property_name: string | null;
  permission_code: string;
  permission_name: string;
  effect: "allow" | "deny";
  valid_from: string;
  valid_to: string | null;
  reason: string;
};

export type EffectivePermission = {
  code: string;
  module: string;
  name_vi: string;
  risk_level: string;
  granted: boolean;
  source: string | null;
  valid_to: string | null;
};

export type RoleHistoryEntry = {
  id: number;
  table_name: string;
  row_id: string;
  action: string;
  at: string;
  actor: string | null;
  new_data: unknown;
  old_data: unknown;
};

function todayVn(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/**
 * Người dùng có quyền quản trị toàn chuỗi không (`p_property = null`)?
 * Type sinh sẵn khai `p_property: string` nên truyền `null` cần ép kiểu
 * tại đúng một chỗ này.
 */
export async function hasChainPerm(
  supabase: Client,
  perm: string,
): Promise<boolean> {
  const caller = supabase.rpc as unknown as (
    fn: string,
    args: { p_property: string | null; p_perm: string },
  ) => Promise<{ data: boolean | null; error: unknown }>;
  const { data, error } = await caller("has_perm", {
    p_property: null,
    p_perm: perm,
  });
  if (error) {
    return false;
  }
  return data ?? false;
}

/** Tổ chức của khách sạn đầu tiên mà người dùng được truy cập. */
export async function getAdminOrgId(supabase: Client): Promise<string | null> {
  const properties = await listAccessibleProperties(supabase);
  if (properties.length === 0) {
    return null;
  }
  const { data } = await supabase
    .from("properties")
    .select("org_id")
    .eq("id", properties[0].id)
    .maybeSingle();
  return data?.org_id ?? null;
}

export async function listSodPairs(
  supabase: Client,
): Promise<[string, string][]> {
  const result = await callAdminRpc<string[][]>(
    supabase,
    "admin_sod_pairs",
    {},
  );
  if (!result.ok) {
    return [];
  }
  return (result.data ?? [])
    .filter((pair) => Array.isArray(pair) && pair.length === 2)
    .map(([a, b]) => [a, b] as [string, string]);
}

export async function listRoles(supabase: Client): Promise<RoleSummary[]> {
  const { data: roles, error } = await supabase
    .from("roles")
    .select(
      "id, org_id, code, name_vi, description, is_system, active, copied_from_id, created_at",
    )
    .order("name_vi");
  if (error) {
    throw error;
  }
  const { data: rolePerms } = await supabase
    .from("role_permissions")
    .select("role_id, permission_code");
  const { data: assignments } = await supabase
    .from("user_property_roles")
    .select("role_id, user_id, valid_from, valid_to");
  const today = todayVn();
  return (roles ?? []).map((role) => ({
    ...role,
    permissionCount: (rolePerms ?? []).filter((rp) => rp.role_id === role.id)
      .length,
    holderCount: new Set(
      (assignments ?? [])
        .filter(
          (a) =>
            a.role_id === role.id &&
            a.valid_from <= today &&
            (a.valid_to === null || a.valid_to >= today),
        )
        .map((a) => a.user_id),
    ).size,
  }));
}

export async function listPermissions(
  supabase: Client,
): Promise<PermissionRow[]> {
  const { data, error } = await supabase
    .from("permissions")
    .select("code, module, name_vi, description_vi, risk_level, sort_order")
    .order("sort_order");
  if (error) {
    throw error;
  }
  return (data ?? []) as PermissionRow[];
}

export async function getRoleDetail(
  supabase: Client,
  roleId: string,
): Promise<{ role: RoleRow; permissionCodes: string[] } | null> {
  const { data: role, error } = await supabase
    .from("roles")
    .select(
      "id, org_id, code, name_vi, description, is_system, active, copied_from_id, created_at",
    )
    .eq("id", roleId)
    .maybeSingle();
  if (error) {
    throw error;
  }
  if (!role) {
    return null;
  }
  const { data: rolePerms } = await supabase
    .from("role_permissions")
    .select("permission_code")
    .eq("role_id", roleId);
  return {
    role,
    permissionCodes: (rolePerms ?? []).map((rp) => rp.permission_code),
  };
}

export async function getRoleHistory(
  supabase: Client,
  roleId: string,
): Promise<RoleHistoryEntry[]> {
  const { data, error } = await supabase
    .from("audit_log")
    .select("id, table_name, row_id, action, at, actor, new_data, old_data")
    .or(
      `and(table_name.eq.roles,row_id.eq.${roleId}),and(table_name.eq.role_permissions,row_id.like.${roleId}:%)`,
    )
    .order("at", { ascending: false })
    .limit(50);
  if (error) {
    // Người dùng không có audit.view_all sẽ thấy danh sách rỗng thay vì lỗi.
    return [];
  }
  return (data ?? []).map((row) => ({
    ...row,
    new_data: row.new_data as unknown,
    old_data: row.old_data as unknown,
  }));
}

export async function listUsers(
  supabase: Client,
  query?: string,
): Promise<UserRow[]> {
  let request = supabase
    .from("profiles")
    .select("id, employee_code, full_name, phone, active, created_at")
    .order("full_name");
  if (query) {
    request = request.or(
      `full_name.ilike.%${query}%,employee_code.ilike.%${query}%`,
    );
  }
  const { data, error } = await request;
  if (error) {
    throw error;
  }
  return data ?? [];
}

export async function getUserProfile(
  supabase: Client,
  userId: string,
): Promise<UserRow | null> {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, employee_code, full_name, phone, active, created_at")
    .eq("id", userId)
    .maybeSingle();
  if (error) {
    throw error;
  }
  return data;
}

export async function listUserAssignments(
  supabase: Client,
  userId: string,
): Promise<AssignmentRow[]> {
  const { data, error } = await supabase
    .from("user_property_roles")
    .select(
      "id, user_id, role_id, property_id, outlet_ids, warehouse_ids, valid_from, valid_to, granted_by",
    )
    .eq("user_id", userId)
    .order("valid_from", { ascending: false });
  if (error) {
    throw error;
  }
  const roleIds = [...new Set((data ?? []).map((a) => a.role_id))];
  const propertyIds = [
    ...new Set((data ?? []).map((a) => a.property_id).filter(Boolean)),
  ] as string[];
  const { data: roles } =
    roleIds.length > 0
      ? await supabase
          .from("roles")
          .select("id, code, name_vi")
          .in("id", roleIds)
      : { data: [] };
  const { data: properties } =
    propertyIds.length > 0
      ? await supabase
          .from("properties")
          .select("id, name")
          .in("id", propertyIds)
      : { data: [] };
  const roleById = new Map((roles ?? []).map((r) => [r.id, r]));
  const propertyById = new Map((properties ?? []).map((p) => [p.id, p]));
  return (data ?? []).map((a) => ({
    ...a,
    role_code: roleById.get(a.role_id)?.code ?? "",
    role_name: roleById.get(a.role_id)?.name_vi ?? "",
    property_name: a.property_id
      ? (propertyById.get(a.property_id)?.name ?? null)
      : null,
  }));
}

export async function listUserOverrides(
  supabase: Client,
  userId: string,
): Promise<OverrideRow[]> {
  const { data, error } = await supabase
    .from("user_permission_overrides")
    .select(
      "id, user_id, property_id, permission_code, effect, valid_from, valid_to, reason",
    )
    .eq("user_id", userId)
    .order("valid_from", { ascending: false });
  if (error) {
    throw error;
  }
  const propertyIds = [
    ...new Set((data ?? []).map((o) => o.property_id).filter(Boolean)),
  ] as string[];
  const permissionCodes = [
    ...new Set((data ?? []).map((o) => o.permission_code)),
  ];
  const { data: properties } =
    propertyIds.length > 0
      ? await supabase
          .from("properties")
          .select("id, name")
          .in("id", propertyIds)
      : { data: [] };
  const { data: permissions } =
    permissionCodes.length > 0
      ? await supabase
          .from("permissions")
          .select("code, name_vi")
          .in("code", permissionCodes)
      : { data: [] };
  const propertyById = new Map((properties ?? []).map((p) => [p.id, p]));
  const permissionByCode = new Map((permissions ?? []).map((p) => [p.code, p]));
  return (data ?? []).map((o) => ({
    ...o,
    effect: o.effect as "allow" | "deny",
    property_name: o.property_id
      ? (propertyById.get(o.property_id)?.name ?? null)
      : null,
    permission_name:
      permissionByCode.get(o.permission_code)?.name_vi ?? o.permission_code,
  }));
}

export async function getEffectivePermissions(
  supabase: Client,
  userId: string,
  propertyId: string | null,
): Promise<EffectivePermission[]> {
  const result = await callAdminRpc<{
    permissions: EffectivePermission[];
  }>(supabase, "admin_user_effective_permissions", {
    p_user_id: userId,
    p_property_id: propertyId,
  });
  if (!result.ok) {
    throw new Error(result.error);
  }
  return result.data.permissions;
}
