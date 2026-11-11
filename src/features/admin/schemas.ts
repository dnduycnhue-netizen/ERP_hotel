import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuid = z
  .string()
  .regex(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    vi.admin.idInvalidFormat,
  );

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);

const nullableDate = dateString.nullable();

const roleCode = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9_]{2,40}$/, vi.admin.roleCodeFormat);

export const saveRoleSchema = z.object({
  id: uuid.optional(),
  orgId: uuid,
  code: roleCode,
  nameVi: z.string().trim().min(1, vi.admin.enterRoleName),
  description: z.string().trim().nullable().optional(),
});

export const copyRoleSchema = z.object({
  roleId: uuid,
  newName: z.string().trim().min(1, vi.admin.enterNewRoleName),
});

export const roleIdSchema = z.object({ roleId: uuid });

export const setRolePermissionsSchema = z.object({
  roleId: uuid,
  permissionCodes: z
    .array(z.string().regex(/^[a-z0-9._]+$/, vi.admin.permissionCodeInvalid))
    .default([]),
});

export const assignRoleSchema = z.object({
  userId: uuid,
  roleId: uuid,
  propertyId: uuid.nullable(),
  outletIds: z.array(uuid).nullable(),
  warehouseIds: z.array(uuid).nullable(),
  validFrom: nullableDate,
  validTo: nullableDate,
});

export const revokeRoleSchema = z.object({
  assignmentId: uuid,
  reason: z.string().trim().min(1, vi.admin.enterRevokeReason),
});

export const setOverrideSchema = z.object({
  userId: uuid,
  propertyId: uuid.nullable(),
  permissionCode: z
    .string()
    .regex(/^[a-z0-9._]+$/, vi.admin.permissionCodeInvalid),
  effect: z.enum(["allow", "deny"]),
  validTo: nullableDate,
  reason: z.string().trim().min(1, vi.admin.enterReason),
});

export const setPinSchema = z.object({
  userId: uuid,
  pin: z.string().regex(/^[0-9]{4,6}$/, vi.common.pinFormat),
});

export const createUserSchema = z.object({
  employeeCode: z
    .string()
    .trim()
    .toUpperCase()
    .regex(/^[A-Z0-9_-]{2,20}$/, vi.admin.employeeCodeFormat),
  fullName: z.string().trim().min(1, vi.admin.enterFullName),
  email: z
    .string()
    .trim()
    .toLowerCase()
    .email(vi.admin.emailInvalidFormat)
    .optional()
    .or(z.literal("")),
  phone: z.string().trim().optional(),
  password: z
    .string()
    .min(12, vi.admin.tempPasswordTooShort)
    .max(128, vi.admin.tempPasswordTooLong)
    .optional()
    .or(z.literal("")),
  roleIds: z.array(uuid).min(1, vi.admin.selectAtLeastOneRole),
  propertyId: uuid.nullable(),
});

export const resetPasswordSchema = z.object({
  userId: uuid,
  password: z
    .string()
    .min(12, vi.admin.tempPasswordTooShort)
    .max(128, vi.admin.tempPasswordTooLong)
    .optional()
    .or(z.literal("")),
});

const orgCode = z
  .string()
  .trim()
  .toUpperCase()
  .regex(/^[A-Z0-9_-]{2,20}$/, vi.admin.codeFormat);

/**
 * Tạo tổ chức + pháp nhân + khách sạn trong 1 lần (C5, RPC admin_org_create).
 * Trường bắt buộc và miền giá trị bám đúng DDL: organizations.name,
 * legal_entities (code unique theo org, accounting_regime TT99/TT133,
 * costing_method moving_avg/fifo), properties (code unique theo org,
 * sod_profile with_cc/without_cc, rooms_count >= 0).
 */
export const createOrgSchema = z.object({
  orgName: z.string().trim().min(1, vi.admin.enterOrgName),
  legalCode: orgCode,
  legalName: z.string().trim().min(1, vi.admin.enterLegalEntityName),
  taxCode: z.string().trim().optional().or(z.literal("")),
  accountingRegime: z.enum(["TT99", "TT133"]).default("TT99"),
  costingMethod: z.enum(["moving_avg", "fifo"]).default("moving_avg"),
  propertyCode: orgCode,
  propertyName: z.string().trim().min(1, vi.admin.enterPropertyName),
  address: z.string().trim().optional().or(z.literal("")),
  sodProfile: z.enum(["with_cc", "without_cc"]).default("with_cc"),
  roomsCount: z
    .number()
    .int(vi.admin.roomCountMustBeInteger)
    .min(0, vi.admin.roomCountNonNegative)
    .default(0),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
export type CreateOrgInput = z.infer<typeof createOrgSchema>;

/**
 * Đổi tên pháp nhân (Q209): orgId chỉ để revalidate trang chi tiết sau
 * khi lưu; RPC chỉ nhận legalEntityId + name.
 */
export const updateLegalEntityNameSchema = z.object({
  orgId: uuid,
  legalEntityId: uuid,
  name: z
    .string()
    .trim()
    .min(1, vi.admin.enterLegalEntityName)
    .max(200, vi.admin.legalEntityNameMax200),
});

export type UpdateLegalEntityNameInput = z.infer<
  typeof updateLegalEntityNameSchema
>;

export const setActiveSchema = z.object({
  userId: uuid,
  active: z.boolean(),
  reason: z.string().trim().nullable().optional(),
});

export type SaveRoleInput = z.infer<typeof saveRoleSchema>;
export type AssignRoleInput = z.infer<typeof assignRoleSchema>;
export type SetOverrideInput = z.infer<typeof setOverrideSchema>;
