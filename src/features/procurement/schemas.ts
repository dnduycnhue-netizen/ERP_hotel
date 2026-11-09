import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");

const prLineSchema = z.object({
  id: uuidSchema.optional(),
  itemId: uuidSchema.optional().nullable(),
  description: z
    .string()
    .trim()
    .max(500, "Mô tả tối đa 500 ký tự.")
    .optional()
    .nullable(),
  qty: z.number().positive("Số lượng phải lớn hơn 0."),
  uom: z.string().trim().min(1, "Đơn vị tính không được để trống."),
  expenseCategoryId: uuidSchema.optional().nullable(),
  costCenterId: uuidSchema.optional().nullable(),
  reason: z
    .string()
    .trim()
    .max(500, "Lý do tối đa 500 ký tự.")
    .optional()
    .nullable(),
});

export const prSaveDraftSchema = z.object({
  propertyId: uuidSchema,
  id: uuidSchema.optional(),
  outletId: uuidSchema.optional().nullable(),
  kind: z.enum(["stock", "service"]).default("stock"),
  needDate: dateSchema.optional().nullable(),
  note: z
    .string()
    .trim()
    .max(1000, "Ghi chú tối đa 1000 ký tự.")
    .optional()
    .nullable(),
  lines: z.array(prLineSchema),
});

export const prSubmitSchema = z.object({
  propertyId: uuidSchema,
  prId: uuidSchema,
});

export const prDecideSchema = z.object({
  propertyId: uuidSchema,
  prId: uuidSchema,
  decision: z.enum(["approved", "rejected"]),
  comment: z
    .string()
    .trim()
    .max(1000, "Nhận xét tối đa 1000 ký tự.")
    .optional()
    .nullable(),
});

export const prCancelSchema = z.object({
  propertyId: uuidSchema,
  prId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do hủy không được để trống."),
});

export const poCreateFromPrSchema = z.object({
  propertyId: uuidSchema,
  prLineIds: z.array(uuidSchema).min(1, "Chọn ít nhất một dòng yêu cầu mua."),
  supplierId: uuidSchema,
  channel: z.enum(["contract", "quote", "market"]),
});

const poLineSchema = z.object({
  id: uuidSchema.optional(),
  itemId: uuidSchema.optional().nullable(),
  description: z
    .string()
    .trim()
    .max(500, "Mô tả tối đa 500 ký tự.")
    .optional()
    .nullable(),
  qty: z.number().positive("Số lượng phải lớn hơn 0."),
  uom: z.string().trim().min(1, "Đơn vị tính không được để trống."),
  unitPrice: z
    .number()
    .nonnegative("Đơn giá không được âm.")
    .optional()
    .nullable(),
  expenseCategoryId: uuidSchema.optional().nullable(),
  costCenterId: uuidSchema.optional().nullable(),
});

export const poSaveDraftSchema = z.object({
  propertyId: uuidSchema,
  id: uuidSchema,
  expectedDate: dateSchema.optional().nullable(),
  overCeilingReason: z
    .string()
    .trim()
    .max(1000, "Lý do vượt trần tối đa 1000 ký tự.")
    .optional()
    .nullable(),
  lines: z.array(poLineSchema),
});

export const poSubmitSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
});

export const approvalDecideSchema = z.object({
  propertyId: uuidSchema,
  docType: z.enum(["pr", "po"]),
  docId: uuidSchema,
  decision: z.enum(["approved", "rejected"]),
  comment: z
    .string()
    .trim()
    .max(1000, "Nhận xét tối đa 1000 ký tự.")
    .optional()
    .nullable(),
});

export const poSendSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
});

export const poCloseSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do đóng không được để trống."),
});

export const poCancelSchema = z.object({
  propertyId: uuidSchema,
  poId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do hủy không được để trống."),
});

export const itemSearchSchema = z.object({
  propertyId: uuidSchema,
  search: z.string().trim().max(100, "Từ khóa tối đa 100 ký tự."),
});

export const approvalDelegationSaveSchema = z.object({
  orgId: uuidSchema,
  id: uuidSchema.optional(),
  fromUser: uuidSchema,
  toUser: uuidSchema,
  propertyId: uuidSchema.optional().nullable(),
  validFrom: dateSchema,
  validTo: dateSchema,
  reason: z
    .string()
    .trim()
    .max(500, "Lý do tối đa 500 ký tự.")
    .optional()
    .nullable(),
});

export type PrSaveDraftInput = z.infer<typeof prSaveDraftSchema>;
export type PrSubmitInput = z.infer<typeof prSubmitSchema>;
export type PrDecideInput = z.infer<typeof prDecideSchema>;
export type PrCancelInput = z.infer<typeof prCancelSchema>;
export type PoCreateFromPrInput = z.infer<typeof poCreateFromPrSchema>;
export type PoSaveDraftInput = z.infer<typeof poSaveDraftSchema>;
export type PoSubmitInput = z.infer<typeof poSubmitSchema>;
export type ApprovalDecideInput = z.infer<typeof approvalDecideSchema>;
export type PoSendInput = z.infer<typeof poSendSchema>;
export type PoCloseInput = z.infer<typeof poCloseSchema>;
export type PoCancelInput = z.infer<typeof poCancelSchema>;
export type ApprovalDelegationSaveInput = z.infer<
  typeof approvalDelegationSaveSchema
>;
export type ItemSearchInput = z.infer<typeof itemSearchSchema>;
