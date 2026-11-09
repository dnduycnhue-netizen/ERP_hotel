import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");
const pinSchema = z.string().regex(/^\d{4,6}$/, "Mã PIN phải gồm 4–6 chữ số.");

/** Mo phieu nhan nhap cho 1 PO (RPC `receiving_start`, T-023). */
export const receivingStartSchema = z.object({
  poId: uuidSchema,
  warehouseId: uuidSchema,
  directIssueWarehouseId: uuidSchema.optional().nullable(),
  clientUuid: uuidSchema.optional().nullable(),
});

/** Ket qua QC 1 dong nhan (gui kem khi ghi dong). */
const qcSchema = z.object({
  status: z.enum(["pass", "fail", "conditional"]),
  checklist: z.array(z.unknown()).optional().nullable(),
  temperature_c: z.number().optional().nullable(),
  reason: z
    .string()
    .trim()
    .max(1000, "Lý do tối đa 1000 ký tự.")
    .optional()
    .nullable(),
  supplier_signature_path: z.string().trim().max(500).optional().nullable(),
});

/** Ghi 1 dong nhan hang; goi lan 2 cung dong = can lai (RPC `receiving_record_line`, T-023). */
export const receivingRecordLineSchema = z.object({
  grId: uuidSchema,
  poLineId: uuidSchema,
  itemId: uuidSchema,
  gross: z.number().positive("Số lượng cân phải lớn hơn 0."),
  tare: z.number().nonnegative("Bì không được âm.").default(0),
  uom: z
    .string()
    .trim()
    .min(1, "Đơn vị tính không được để trống.")
    .optional()
    .nullable(),
  qc: qcSchema,
  lot: z
    .string()
    .trim()
    .max(100, "Số lô tối đa 100 ký tự.")
    .optional()
    .nullable(),
  expiry: dateSchema.optional().nullable(),
  photoIds: z.array(uuidSchema).optional().nullable(),
  clientUuid: uuidSchema.optional().nullable(),
});

/** Duyet nhan vuot tran cho 1 dong (RPC `receiving_override_line`, T-023). */
export const receivingOverrideLineSchema = z.object({
  grLineId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do vượt PO không được để trống."),
});

/** Ghi so phieu nhan: kiem PIN + SoD roi moi move kho (RPC `receiving_post`, T-023). */
export const receivingPostSchema = z.object({
  grId: uuidSchema,
  pin: pinSchema,
});

/** 1 dong tra hang da nhan ve NCC (RPC `supplier_return_post`, T-023). */
const supplierReturnLineSchema = z.object({
  grLineId: uuidSchema,
  qtyStock: z.number().positive("Số lượng trả phải lớn hơn 0."),
  reason: z
    .string()
    .trim()
    .max(1000, "Lý do tối đa 1000 ký tự.")
    .optional()
    .nullable(),
  photoIds: z.array(uuidSchema).optional().nullable(),
  supplierSignaturePath: z.string().trim().max(500).optional().nullable(),
});

/** Tra hang da nhan ve NCC (RPC `supplier_return_post`, T-023). */
export const supplierReturnPostSchema = z.object({
  grId: uuidSchema,
  lines: z
    .array(supplierReturnLineSchema)
    .min(1, "Cần ít nhất một dòng trả hàng."),
});

/** Dao phieu nhan da post (RPC `receiving_reverse`, T-023). */
export const receivingReverseSchema = z.object({
  grId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do đảo phiếu không được để trống."),
});

/** Luu mau checklist QC theo nhom hang (RPC `admin_qc_template_save`, T-023). */
export const qcTemplateSaveSchema = z.object({
  orgId: uuidSchema,
  itemGroupId: uuidSchema,
  checklist: z.array(z.unknown()).min(1, "Checklist cần ít nhất một mục."),
});

/** Xoa mau checklist QC (RPC `admin_qc_template_delete`, T-023). */
export const qcTemplateDeleteSchema = z.object({
  templateId: uuidSchema,
});

/** Loc danh sach phieu nhan (RPC `receiving_list_receipts`, T-023). */
export const receivingListReceiptsSchema = z.object({
  propertyId: uuidSchema,
  status: z
    .enum(["draft", "needs_recount", "posted", "reversed"])
    .optional()
    .nullable(),
  search: z
    .string()
    .trim()
    .max(100, "Từ khóa tối đa 100 ký tự.")
    .optional()
    .nullable(),
  limit: z.number().int().min(1).max(100).default(20),
  offset: z.number().int().min(0).default(0),
});

export type ReceivingStartInput = z.infer<typeof receivingStartSchema>;
export type ReceivingRecordLineInput = z.infer<
  typeof receivingRecordLineSchema
>;
export type ReceivingOverrideLineInput = z.infer<
  typeof receivingOverrideLineSchema
>;
export type ReceivingPostInput = z.infer<typeof receivingPostSchema>;
export type SupplierReturnPostInput = z.infer<typeof supplierReturnPostSchema>;
export type ReceivingReverseInput = z.infer<typeof receivingReverseSchema>;
export type QcTemplateSaveInput = z.infer<typeof qcTemplateSaveSchema>;
export type QcTemplateDeleteInput = z.infer<typeof qcTemplateDeleteSchema>;
export type ReceivingListReceiptsInput = z.infer<
  typeof receivingListReceiptsSchema
>;
