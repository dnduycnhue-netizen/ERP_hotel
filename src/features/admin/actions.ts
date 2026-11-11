"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";
import { callAdminRpc, type AdminActionResult } from "./rpc";
import {
  assignRoleSchema,
  copyRoleSchema,
  createOrgSchema,
  createUserSchema,
  resetPasswordSchema,
  revokeRoleSchema,
  roleIdSchema,
  saveRoleSchema,
  setActiveSchema,
  setOverrideSchema,
  setPinSchema,
  setRolePermissionsSchema,
  updateLegalEntityNameSchema,
  type AssignRoleInput,
  type CreateOrgInput,
  type CreateUserInput,
  type ResetPasswordInput,
  type SaveRoleInput,
  type SetOverrideInput,
  type UpdateLegalEntityNameInput,
} from "./schemas";

type SetPermissionsResult = {
  added: string[];
  removed: string[];
  conflicts: { permission_a: string; permission_b: string }[];
  critical_changed: boolean;
};

async function requireUserId(): Promise<string | null> {
  const supabase = await createClient();
  const { data } = await supabase.auth.getUser();
  return data.user?.id ?? null;
}

function firstIssue<T>(parsed: {
  success: false;
  error: { issues: { message: string }[] };
}): AdminActionResult<T> {
  return {
    ok: false,
    error: parsed.error.issues[0]?.message ?? getRpcErrorMessage(null),
  };
}

async function authed(): Promise<AdminActionResult<never> | null> {
  const userId = await requireUserId();
  if (!userId) {
    return { ok: false, error: getRpcErrorMessage(null) };
  }
  return null;
}

export type CreateUserResult = {
  user_id: string;
  login_email: string;
  temp_password: string;
  employee_code: string;
};

export type ResetPasswordResult = {
  user_id: string;
  temp_password: string;
};

export type CreateOrgResult = {
  org_id: string;
  legal_entity_id: string;
  property_id: string;
};

function edgeFunctionErrorMessage(code: string | null): string {
  if (code && code in vi.admin.edgeFunctionErrors) {
    return vi.admin.edgeFunctionErrors[
      code as keyof typeof vi.admin.edgeFunctionErrors
    ];
  }
  return getRpcErrorMessage(null);
}

async function extractEdgeErrorCode(error: unknown): Promise<string | null> {
  const context = (error as { context?: unknown } | null)?.context;
  if (context && typeof (context as Response).json === "function") {
    try {
      const payload = (await (context as Response).json()) as Record<
        string,
        unknown
      >;
      return typeof payload.error === "string" ? payload.error : null;
    } catch {
      return null;
    }
  }
  return null;
}

/**
 * Gọi Edge Function quản trị (admin-create-user / admin-reset-password).
 * Đây là lần đầu app gọi Edge Function từ Next.js — dùng
 * `supabase.functions.invoke` trên SSR server client. Edge Function tự
 * kiểm tra quyền admin.users.manage qua user_has_perm; server action chỉ
 * kiểm tra đã đăng nhập (như các action RPC khác).
 */
async function invokeAdminFunction<T>(
  functionName: string,
  body: Record<string, unknown>,
): Promise<AdminActionResult<T>> {
  const supabase = await createClient();
  const { data, error } = await supabase.functions.invoke<
    Record<string, unknown>
  >(functionName, { body });
  if (error) {
    const code = await extractEdgeErrorCode(error);
    return { ok: false, error: edgeFunctionErrorMessage(code) };
  }
  if (!data || data.ok !== true) {
    const code = typeof data?.error === "string" ? data.error : null;
    return { ok: false, error: edgeFunctionErrorMessage(code) };
  }
  return { ok: true, data: data as unknown as T };
}

/** Tạo tài khoản mới (gọi Edge Function admin-create-user). */
export async function createUserAction(
  input: CreateUserInput,
): Promise<AdminActionResult<CreateUserResult>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = createUserSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const d = parsed.data;
  const result = await invokeAdminFunction<CreateUserResult>(
    "admin-create-user",
    {
      employeeCode: d.employeeCode,
      fullName: d.fullName,
      email: d.email || undefined,
      phone: d.phone || undefined,
      password: d.password || undefined,
      roles: d.roleIds.map((roleId) => ({
        roleId,
        propertyId: d.propertyId ?? undefined,
      })),
    },
  );
  if (result.ok) revalidatePath("/admin/users");
  return result;
}

/**
 * Tạo tổ chức + pháp nhân + khách sạn trong 1 lần (C5, RPC admin_org_create).
 * RPC tự kiểm tra quyền admin.org.manage, seed vai trò mẫu của tổ chức mới
 * và gán người tạo làm sys_admin + owner toàn chuỗi của tổ chức mới.
 */
export async function createOrgAction(
  input: CreateOrgInput,
): Promise<AdminActionResult<CreateOrgResult>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = createOrgSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const d = parsed.data;
  const result = await callAdminRpc<CreateOrgResult>(
    supabase,
    "admin_org_create",
    {
      p_org: {
        org_name: d.orgName,
        legal_code: d.legalCode,
        legal_name: d.legalName,
        tax_code: d.taxCode || null,
        accounting_regime: d.accountingRegime,
        costing_method: d.costingMethod,
        property_code: d.propertyCode,
        property_name: d.propertyName,
        address: d.address || null,
        sod_profile: d.sodProfile,
        rooms_count: d.roomsCount,
      },
    },
  );
  if (result.ok) revalidatePath("/admin/organizations");
  return result;
}

/**
 * Đổi tên pháp nhân (Q209, RPC admin_legal_entity_update). RPC tự kiểm
 * tra quyền admin.org.manage; chỉ đổi cột name, không đổi mã/tổ chức.
 */
export async function updateLegalEntityNameAction(
  input: UpdateLegalEntityNameInput,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = updateLegalEntityNameSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const d = parsed.data;
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_legal_entity_update",
    {
      p_legal_entity_id: d.legalEntityId,
      p_name: d.name,
    },
  );
  if (result.ok) revalidatePath(`/admin/organizations/${d.orgId}`);
  return result;
}

/** Đặt lại mật khẩu cho một tài khoản khác (gọi Edge Function admin-reset-password). */
export async function resetUserPasswordAction(
  input: ResetPasswordInput,
): Promise<AdminActionResult<ResetPasswordResult>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = resetPasswordSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const result = await invokeAdminFunction<ResetPasswordResult>(
    "admin-reset-password",
    {
      userId: parsed.data.userId,
      password: parsed.data.password || undefined,
    },
  );
  if (result.ok) revalidatePath(`/admin/users/${parsed.data.userId}/access`);
  return result;
}

/** Quyền của tôi tại một khách sạn (dùng cho hook `useCan`). */
export async function getMyPermissionsAction(
  propertyId: string | null,
): Promise<string[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  if (error) {
    throw error;
  }
  return data ?? [];
}

export async function saveRoleAction(
  input: SaveRoleInput,
): Promise<AdminActionResult<{ id: string; code: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = saveRoleSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string; code: string }>(
    supabase,
    "admin_role_save",
    {
      p_role: {
        id: parsed.data.id ?? null,
        org_id: parsed.data.orgId,
        code: parsed.data.code,
        name_vi: parsed.data.nameVi,
        description: parsed.data.description ?? null,
      },
    },
  );
  if (result.ok) {
    revalidatePath("/admin/roles");
  }
  return result;
}

export async function copyRoleAction(
  roleId: string,
  newName: string,
): Promise<AdminActionResult<{ id: string; code: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = copyRoleSchema.safeParse({ roleId, newName });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string; code: string }>(
    supabase,
    "admin_role_copy",
    { p_role_id: roleId, p_new_name: newName.trim() },
  );
  if (result.ok) {
    revalidatePath("/admin/roles");
  }
  return result;
}

export async function deactivateRoleAction(
  roleId: string,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = roleIdSchema.safeParse({ roleId });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_role_deactivate",
    { p_role_id: roleId },
  );
  if (result.ok) {
    revalidatePath("/admin/roles");
  }
  return result;
}

export async function setRolePermissionsAction(
  roleId: string,
  permissionCodes: string[],
): Promise<AdminActionResult<SetPermissionsResult>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = setRolePermissionsSchema.safeParse({
    roleId,
    permissionCodes,
  });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<SetPermissionsResult>(
    supabase,
    "admin_role_set_permissions",
    { p_role_id: roleId, p_permission_codes: permissionCodes },
  );
  if (result.ok) {
    revalidatePath(`/admin/roles/${roleId}`);
    revalidatePath("/admin/roles");
  }
  return result;
}

export async function assignRoleAction(
  input: AssignRoleInput,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = assignRoleSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_user_assign_role",
    {
      p_user_id: parsed.data.userId,
      p_role_id: parsed.data.roleId,
      p_property_id: parsed.data.propertyId,
      p_outlet_ids: parsed.data.outletIds,
      p_warehouse_ids: parsed.data.warehouseIds,
      p_valid_from: parsed.data.validFrom,
      p_valid_to: parsed.data.validTo,
    },
  );
  if (result.ok) {
    revalidatePath(`/admin/users/${parsed.data.userId}/access`);
  }
  return result;
}

export async function revokeRoleAction(
  assignmentId: string,
  reason: string,
  userId: string,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = revokeRoleSchema.safeParse({ assignmentId, reason });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_user_revoke_role",
    { p_assignment_id: assignmentId, p_reason: reason.trim() },
  );
  if (result.ok) {
    revalidatePath(`/admin/users/${userId}/access`);
  }
  return result;
}

export async function setOverrideAction(
  input: SetOverrideInput,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = setOverrideSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_permission_override_set",
    {
      p_user_id: parsed.data.userId,
      p_property_id: parsed.data.propertyId,
      p_permission_code: parsed.data.permissionCode,
      p_effect: parsed.data.effect,
      p_valid_to: parsed.data.validTo,
      p_reason: parsed.data.reason,
    },
  );
  if (result.ok) {
    revalidatePath(`/admin/users/${parsed.data.userId}/access`);
  }
  return result;
}

export async function setPinAction(
  userId: string,
  pin: string,
): Promise<AdminActionResult<{ user_id: string }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = setPinSchema.safeParse({ userId, pin });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ user_id: string }>(
    supabase,
    "admin_user_set_pin",
    { p_user_id: userId, p_pin: pin },
  );
  return result;
}

export async function setActiveAction(
  userId: string,
  active: boolean,
  reason?: string,
): Promise<AdminActionResult<{ user_id: string; active: boolean }>> {
  const gate = await authed();
  if (gate) return gate;
  const parsed = setActiveSchema.safeParse({
    userId,
    active,
    reason: reason ?? null,
  });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ user_id: string; active: boolean }>(
    supabase,
    "admin_user_set_active",
    {
      p_user_id: userId,
      p_active: active,
      p_reason: reason?.trim() || null,
    },
  );
  if (result.ok) {
    revalidatePath(`/admin/users/${userId}/access`);
    revalidatePath("/admin/users");
  }
  return result;
}
