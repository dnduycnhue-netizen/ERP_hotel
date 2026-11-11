import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuid = z.string().uuid();
export const configRuleIdSchema = z.object({ ruleId: uuid });

const settingKey = z.enum([
  "price_spike_pct",
  "receiving_tolerance_pct",
  "market_advance_deadline_hours",
  "waste_approval_threshold_vnd",
  "count_random_items",
  "count_variance_threshold_pct",
  "count_without_cc_factor",
  "invoice_price_tolerance_pct",
]);

const decimalString = z
  .string()
  .trim()
  .regex(/^\d+(?:\.\d+)?$/, vi.admin.enterNonNegativeNumber);

const jsonObjectString = z
  .string()
  .trim()
  .refine((value) => {
    try {
      const parsed: unknown = JSON.parse(value);
      return (
        typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)
      );
    } catch {
      return false;
    }
  }, vi.admin.configValueMustBeValidJson);

export const settingSaveSchema = z.object({
  orgId: uuid,
  propertyId: uuid.nullable(),
  key: settingKey,
  value: decimalString,
});

export const approvalRuleSaveSchema = z
  .object({
    id: uuid.nullable(),
    orgId: uuid,
    propertyId: uuid.nullable(),
    docType: z
      .string()
      .trim()
      .regex(/^[a-z][a-z0-9_]{1,39}$/, vi.admin.docCodeInvalid),
    minAmount: decimalString,
    maxAmount: z.union([decimalString, z.literal("")]),
    itemGroupId: z.union([uuid, z.literal("")]),
    condition: jsonObjectString,
    step: z.number().int().min(1).max(100),
    approverRoleId: uuid.nullable(),
    approverUserId: uuid.nullable(),
    requiredPerm: z
      .string()
      .trim()
      .regex(/^[a-z0-9._]+$/, vi.admin.permissionCodeInvalid),
  })
  .refine(
    (value) =>
      (value.approverRoleId === null) !== (value.approverUserId === null),
    {
      message: vi.admin.configSelectExactlyOneRoleOrApprover,
      path: ["approverRoleId"],
    },
  );

export const alertRuleSaveSchema = z.object({
  id: uuid.nullable(),
  orgId: uuid,
  propertyId: uuid.nullable(),
  code: z
    .string()
    .trim()
    .regex(/^[A-Z][A-Z0-9_]{1,63}$/, vi.admin.alertCodeInvalid),
  threshold: jsonObjectString,
  channels: z.array(z.enum(["app", "email", "webpush", "zalo"])).min(1),
  urgent: z.boolean(),
  active: z.boolean(),
});

export type SettingSaveInput = z.infer<typeof settingSaveSchema>;
export type ApprovalRuleSaveInput = z.infer<typeof approvalRuleSaveSchema>;
export type AlertRuleSaveInput = z.infer<typeof alertRuleSaveSchema>;
