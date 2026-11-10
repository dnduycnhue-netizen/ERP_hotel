import { z } from "zod";

const uuid = z
  .string()
  .regex(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    "ID không đúng định dạng.",
  );

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");

const nullableDate = dateString.nullable();

const roleCode = z
  .string()
  .trim()
  .toLowerCase()
  .regex(
    /^[a-z0-9_]{2,40}$/,
    "Mã vai trò chỉ gồm chữ thường, số và gạch dưới, dài 2–40 ký tự.",
  );

export const saveRoleSchema = z.object({
  id: uuid.optional(),
  orgId: uuid,
  code: roleCode,
  nameVi: z.string().trim().min(1, "Vui lòng nhập tên vai trò."),
  description: z.string().trim().nullable().optional(),
});

export const copyRoleSchema = z.object({
  roleId: uuid,
  newName: z.string().trim().min(1, "Vui lòng nhập tên vai trò mới."),
});

export const roleIdSchema = z.object({ roleId: uuid });

export const setRolePermissionsSchema = z.object({
  roleId: uuid,
  permissionCodes: z
    .array(z.string().regex(/^[a-z0-9._]+$/, "Mã quyền không hợp lệ."))
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
  reason: z.string().trim().min(1, "Vui lòng nhập lý do thu hồi."),
});

export const setOverrideSchema = z.object({
  userId: uuid,
  propertyId: uuid.nullable(),
  permissionCode: z.string().regex(/^[a-z0-9._]+$/, "Mã quyền không hợp lệ."),
  effect: z.enum(["allow", "deny"]),
  validTo: nullableDate,
  reason: z.string().trim().min(1, "Vui lòng nhập lý do."),
});

export const setPinSchema = z.object({
  userId: uuid,
  pin: z.string().regex(/^[0-9]{4,6}$/, "Mã PIN phải gồm 4–6 chữ số."),
});

export const createUserSchema = z.object({
  employeeCode: z
    .string()
    .trim()
    .toUpperCase()
    .regex(
      /^[A-Z0-9_-]{2,20}$/,
      "Mã nhân viên chỉ gồm chữ hoa, số, gạch dưới và gạch ngang, dài 2–20 ký tự.",
    ),
  fullName: z.string().trim().min(1, "Vui lòng nhập họ tên."),
  email: z
    .string()
    .trim()
    .toLowerCase()
    .email("Email không đúng định dạng.")
    .optional()
    .or(z.literal("")),
  phone: z.string().trim().optional(),
  password: z
    .string()
    .min(12, "Mật khẩu tạm phải có ít nhất 12 ký tự.")
    .max(128, "Mật khẩu tạm tối đa 128 ký tự.")
    .optional()
    .or(z.literal("")),
  roleIds: z.array(uuid),
  propertyId: uuid.nullable(),
});

export const resetPasswordSchema = z.object({
  userId: uuid,
  password: z
    .string()
    .min(12, "Mật khẩu tạm phải có ít nhất 12 ký tự.")
    .max(128, "Mật khẩu tạm tối đa 128 ký tự.")
    .optional()
    .or(z.literal("")),
});

export type CreateUserInput = z.infer<typeof createUserSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;

export const setActiveSchema = z.object({
  userId: uuid,
  active: z.boolean(),
  reason: z.string().trim().nullable().optional(),
});

export type SaveRoleInput = z.infer<typeof saveRoleSchema>;
export type AssignRoleInput = z.infer<typeof assignRoleSchema>;
export type SetOverrideInput = z.infer<typeof setOverrideSchema>;
