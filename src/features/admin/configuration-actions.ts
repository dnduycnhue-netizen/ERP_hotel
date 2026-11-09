"use server";

import { revalidatePath } from "next/cache";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import {
  alertRuleSaveSchema,
  approvalRuleSaveSchema,
  configRuleIdSchema,
  settingSaveSchema,
} from "./configuration-schemas";
import { callAdminRpc, type AdminActionResult } from "./rpc";

async function authenticated(): Promise<AdminActionResult<never> | null> {
  const supabase = await createClient();
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) {
    return { ok: false, error: getRpcErrorMessage(null) };
  }
  return null;
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

function parseObject(value: string): Record<string, unknown> {
  const parsed: unknown = JSON.parse(value);
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error("Expected a JSON object after schema validation.");
  }
  return parsed as Record<string, unknown>;
}

export async function saveSettingAction(
  input: unknown,
): Promise<AdminActionResult<{ key: string; value: string }>> {
  const gate = await authenticated();
  if (gate) return gate;
  const parsed = settingSaveSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ key: string; value: string }>(
    supabase,
    "admin_setting_save",
    {
      p_org_id: parsed.data.orgId,
      p_property_id: parsed.data.propertyId,
      p_key: parsed.data.key,
      p_value: parsed.data.value,
    },
  );
  if (result.ok) {
    revalidatePath("/admin/settings");
  }
  return result;
}

export async function saveApprovalRuleAction(
  input: unknown,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authenticated();
  if (gate) return gate;
  const parsed = approvalRuleSaveSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_approval_rule_save",
    {
      p_rule: {
        id: parsed.data.id,
        org_id: parsed.data.orgId,
        property_id: parsed.data.propertyId,
        doc_type: parsed.data.docType,
        min_amount: parsed.data.minAmount,
        max_amount: parsed.data.maxAmount || null,
        item_group_id: parsed.data.itemGroupId || null,
        condition: parseObject(parsed.data.condition),
        step: parsed.data.step,
        approver_role_id: parsed.data.approverRoleId,
        approver_user_id: parsed.data.approverUserId,
        required_perm: parsed.data.requiredPerm,
      },
    },
  );
  if (result.ok) {
    revalidatePath("/admin/approval-rules");
  }
  return result;
}

export async function deleteApprovalRuleAction(
  ruleId: string,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authenticated();
  if (gate) return gate;
  const parsed = configRuleIdSchema.safeParse({ ruleId });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_approval_rule_delete",
    { p_rule_id: parsed.data.ruleId },
  );
  if (result.ok) {
    revalidatePath("/admin/approval-rules");
  }
  return result;
}

export async function saveAlertRuleAction(
  input: unknown,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authenticated();
  if (gate) return gate;
  const parsed = alertRuleSaveSchema.safeParse(input);
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_alert_rule_save",
    {
      p_rule: {
        id: parsed.data.id,
        org_id: parsed.data.orgId,
        property_id: parsed.data.propertyId,
        code: parsed.data.code,
        threshold: parseObject(parsed.data.threshold),
        channels: parsed.data.channels,
        urgent: parsed.data.urgent,
        active: parsed.data.active,
      },
    },
  );
  if (result.ok) {
    revalidatePath("/admin/alert-rules");
  }
  return result;
}

export async function deleteAlertRuleAction(
  ruleId: string,
): Promise<AdminActionResult<{ id: string }>> {
  const gate = await authenticated();
  if (gate) return gate;
  const parsed = configRuleIdSchema.safeParse({ ruleId });
  if (!parsed.success) return firstIssue(parsed);
  const supabase = await createClient();
  const result = await callAdminRpc<{ id: string }>(
    supabase,
    "admin_alert_rule_delete",
    { p_rule_id: parsed.data.ruleId },
  );
  if (result.ok) {
    revalidatePath("/admin/alert-rules");
  }
  return result;
}
