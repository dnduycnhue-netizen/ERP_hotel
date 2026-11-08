"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { callAdminRpc, type AdminActionResult } from "./rpc";
import {
  assignRoleSchema,
  copyRoleSchema,
  revokeRoleSchema,
  roleIdSchema,
  saveRoleSchema,
  setActiveSchema,
  setOverrideSchema,
  setPinSchema,
  setRolePermissionsSchema,
  type AssignRoleInput,
  type SaveRoleInput,
  type SetOverrideInput,
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
