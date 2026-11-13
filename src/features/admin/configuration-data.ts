import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database.types";
import { listAccessibleProperties } from "@/lib/supabase/access";
import { callAdminRpc } from "./rpc";
import { getAdminOrgId } from "./data/queries";

type Client = SupabaseClient<Database>;

export type SettingEntry = {
  key:
    | "price_spike_pct"
    | "receiving_tolerance_pct"
    | "market_advance_deadline_hours"
    | "waste_approval_threshold_vnd"
    | "count_random_items"
    | "count_variance_threshold_pct"
    | "count_recount_threshold_pct"
    | "count_without_cc_factor"
    | "invoice_price_tolerance_pct"
    | "rule.R25.enabled"
    | "rule.R18.enabled"
    | "rule.R32.enabled"
    | "rule.SELF_PR.enabled"
    | "rule.SELF_REQ.enabled"
    | "rule.SELF_WASTE.enabled";
  value: string;
  source: "property" | "organization" | "default";
};

export type ApprovalRule = {
  id: string;
  org_id: string;
  property_id: string | null;
  doc_type: string;
  min_amount: string;
  max_amount: string | null;
  item_group_id: string | null;
  condition: Record<string, unknown>;
  step: number;
  approver_role_id: string | null;
  approver_role_name: string | null;
  approver_user_id: string | null;
  required_perm: string;
};

export type ApprovalApprovers = {
  roles: { id: string; name: string }[];
  users: { id: string; name: string; employee_code: string | null }[];
};

export type AlertRule = {
  id: string;
  org_id: string;
  property_id: string | null;
  code: string;
  threshold: Record<string, unknown>;
  channels: ("app" | "email" | "webpush" | "zalo")[];
  urgent: boolean;
  active: boolean;
};

export type AdminConfigScope = {
  orgId: string | null;
  propertyId: string | null;
  properties: Awaited<ReturnType<typeof listAccessibleProperties>>;
  canManage: boolean;
};

async function readAdminRpc<T>(
  supabase: Client,
  name: string,
  args: Record<string, unknown>,
): Promise<T> {
  const result = await callAdminRpc<T>(supabase, name, args);
  if (!result.ok) {
    throw new Error(result.error);
  }
  return result.data;
}

export async function hasAdminConfigPermission(
  supabase: Client,
  permission: string,
  propertyId: string | null,
): Promise<boolean> {
  if (propertyId === null) {
    const caller = supabase.rpc.bind(supabase) as unknown as (
      fn: string,
      args: { p_property: string | null; p_perm: string },
    ) => Promise<{ data: boolean | null; error: { message: string } | null }>;
    const { data, error } = await caller("has_perm", {
      p_property: null,
      p_perm: permission,
    });
    if (error) {
      throw error;
    }
    return data ?? false;
  }

  const { data, error } = await supabase.rpc("has_perm", {
    p_property: propertyId,
    p_perm: permission,
  });
  if (error) {
    throw error;
  }
  return data;
}

export async function resolveAdminConfigScope(
  supabase: Client,
  permission: string,
  requestedPropertyId?: string | null,
): Promise<AdminConfigScope> {
  const [orgId, accessibleProperties] = await Promise.all([
    getAdminOrgId(supabase),
    listAccessibleProperties(supabase),
  ]);
  let properties = accessibleProperties;
  if (!orgId) {
    return { orgId, propertyId: null, properties, canManage: false };
  }
  if (properties.length > 0) {
    const { data, error } = await supabase
      .from("properties")
      .select("id")
      .eq("org_id", orgId)
      .in(
        "id",
        properties.map(({ id }) => id),
      );
    if (error) {
      throw error;
    }
    const orgPropertyIds = new Set((data ?? []).map(({ id }) => id));
    properties = properties.filter(({ id }) => orgPropertyIds.has(id));
  }

  const canManageChain = await hasAdminConfigPermission(
    supabase,
    permission,
    null,
  );
  const availableProperties = canManageChain
    ? properties
    : (
        await Promise.all(
          properties.map(async (property) => ({
            property,
            canManage: await hasAdminConfigPermission(
              supabase,
              permission,
              property.id,
            ),
          })),
        )
      )
        .filter(({ canManage }) => canManage)
        .map(({ property }) => property);

  if (requestedPropertyId !== undefined) {
    if (requestedPropertyId === null) {
      return {
        orgId,
        propertyId: null,
        properties: availableProperties,
        canManage: canManageChain,
      };
    }
    const property = availableProperties.find(
      ({ id }) => id === requestedPropertyId,
    );
    if (!property) {
      return {
        orgId,
        propertyId: null,
        properties: availableProperties,
        canManage: false,
      };
    }
    return {
      orgId,
      propertyId: property.id,
      properties: availableProperties,
      canManage: canManageChain
        ? await hasAdminConfigPermission(supabase, permission, property.id)
        : true,
    };
  }

  if (canManageChain) {
    return {
      orgId,
      propertyId: null,
      properties: availableProperties,
      canManage: true,
    };
  }

  if (availableProperties.length > 0) {
    return {
      orgId,
      propertyId: availableProperties[0].id,
      properties: availableProperties,
      canManage: true,
    };
  }
  return {
    orgId,
    propertyId: null,
    properties: availableProperties,
    canManage: false,
  };
}

export function listSettingEntries(
  supabase: Client,
  orgId: string,
  propertyId: string | null,
): Promise<SettingEntry[]> {
  return readAdminRpc(supabase, "admin_settings_list", {
    p_org_id: orgId,
    p_property_id: propertyId,
  });
}

export function listApprovalRules(
  supabase: Client,
  orgId: string,
  propertyId: string | null,
): Promise<ApprovalRule[]> {
  return readAdminRpc(supabase, "admin_approval_rules_list", {
    p_org_id: orgId,
    p_property_id: propertyId,
  });
}

export function listApprovalApprovers(
  supabase: Client,
  orgId: string,
  propertyId: string | null,
): Promise<ApprovalApprovers> {
  return readAdminRpc(supabase, "admin_approval_approvers_list", {
    p_org_id: orgId,
    p_property_id: propertyId,
  });
}

export type ApprovalDelegation = {
  id: string;
  org_id: string;
  from_user: string;
  to_user: string;
  property_id: string | null;
  valid_from: string;
  valid_to: string;
  reason: string | null;
};

/**
 * Danh sách ủy quyền duyệt (C9). Đọc trực tiếp bảng `approval_delegations`
 * (policy `approval_delegations_select`: người ủy quyền / người được ủy
 * quyền / người có `admin.approval_rules.manage`). `database.types.ts`
 * chưa có bảng này nên ép kiểu có chủ đích tại đúng chỗ này
 * (mẫu alerts/queries.ts). Phạm vi chuỗi chỉ liệt kê ủy quyền toàn chuỗi;
 * phạm vi khách sạn liệt kê ủy quyền của khách sạn đó + toàn chuỗi.
 */
export async function listApprovalDelegations(
  supabase: Client,
  orgId: string,
  propertyId: string | null,
): Promise<ApprovalDelegation[]> {
  const untyped = supabase as unknown as SupabaseClient;
  let query = untyped
    .from("approval_delegations")
    .select(
      "id, org_id, from_user, to_user, property_id, valid_from, valid_to, reason",
    )
    .eq("org_id", orgId);
  if (propertyId === null) {
    query = query.is("property_id", null);
  } else {
    query = query.or(`property_id.eq.${propertyId},property_id.is.null`);
  }
  const { data, error } = await query.order("valid_from", {
    ascending: false,
  });
  if (error) {
    throw error;
  }
  return (data ?? []) as unknown as ApprovalDelegation[];
}

export function listAlertRules(
  supabase: Client,
  orgId: string,
  propertyId: string | null,
): Promise<AlertRule[]> {
  return readAdminRpc(supabase, "admin_alert_rules_list", {
    p_org_id: orgId,
    p_property_id: propertyId,
  });
}
