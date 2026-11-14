import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);
const pinSchema = z.string().regex(/^\d{4,6}$/, vi.common.pinFormat);

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
    .max(1000, vi.common.reasonMax1000)
    .optional()
    .nullable(),
  supplier_signature_path: z.string().trim().max(500).optional().nullable(),
  /** Hàng hỏng một phần (theo ĐVT ghi nhận, nhỏ hơn số thực nhận) — Q277. */
  rejected_qty: z.number().positive().optional().nullable(),
  reject_reason: z.string().trim().max(300).optional().nullable(),
});

/** Ghi 1 dong nhan hang; goi lan 2 cung dong = can lai (RPC `receiving_record_line`, T-023). */
export const receivingRecordLineSchema = z.object({
  grId: uuidSchema,
  poLineId: uuidSchema,
  itemId: uuidSchema,
  gross: z.number().positive(vi.receiving.weighedQuantityPositive),
  tare: z.number().nonnegative(vi.receiving.tareNonNegative).default(0),
  uom: z.string().trim().min(1, vi.common.uomRequired).optional().nullable(),
  qc: qcSchema,
  lot: z
    .string()
    .trim()
    .max(100, vi.receiving.lotNumberMax100)
    .optional()
    .nullable(),
  expiry: dateSchema.optional().nullable(),
  photoIds: z.array(uuidSchema).optional().nullable(),
  /** Thiết bị không có camera: xác nhận + lý do thay cho ảnh (Q274). */
  photoWaivedReason: z.string().trim().max(300).optional().nullable(),
  clientUuid: uuidSchema.optional().nullable(),
});

/** Duyet nhan vuot tran cho 1 dong (RPC `receiving_override_line`, T-023). */
export const receivingOverrideLineSchema = z.object({
  grLineId: uuidSchema,
  reason: z.string().trim().min(1, vi.receiving.overPoReasonRequired),
});

/** Ghi so phieu nhan: kiem PIN + SoD roi moi move kho (RPC `receiving_post`, T-023). */
export const receivingPostSchema = z.object({
  grId: uuidSchema,
  pin: pinSchema,
  /** Phiếu không có ảnh nào: xác nhận không có camera + lý do khi ghi sổ (Q278). */
  photoWaivedReason: z.string().trim().max(300).optional().nullable(),
});

/** 1 dong tra hang da nhan ve NCC (RPC `supplier_return_post`, T-023). */
const supplierReturnLineSchema = z.object({
  grLineId: uuidSchema,
  qtyStock: z.number().positive(vi.receiving.returnQuantityPositive),
  reason: z
    .string()
    .trim()
    .max(1000, vi.common.reasonMax1000)
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
    .min(1, vi.receiving.needAtLeastOneReturnLine),
});

/** Dao phieu nhan da post (RPC `receiving_reverse`, T-023). */
export const receivingReverseSchema = z.object({
  grId: uuidSchema,
  reason: z.string().trim().min(1, vi.receiving.reverseReasonRequired),
});

/** Luu mau checklist QC theo nhom hang (RPC `admin_qc_template_save`, T-023). */
export const qcTemplateSaveSchema = z.object({
  orgId: uuidSchema,
  itemGroupId: uuidSchema,
  checklist: z
    .array(z.unknown())
    .min(1, vi.receiving.checklistNeedsAtLeastOneItem),
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
    .max(100, vi.common.keywordMax100)
    .optional()
    .nullable(),
  limit: z.number().int().min(1).max(100).default(20),
  offset: z.number().int().min(0).default(0),
});

/** Loc danh sach phieu tra NCC (RPC `supplier_return_list`, T-026). */
export const supplierReturnListSchema = z.object({
  propertyId: uuidSchema,
  status: z.enum(["recorded", "posted", "cancelled"]).optional().nullable(),
  search: z
    .string()
    .trim()
    .max(100, vi.common.keywordMax100)
    .optional()
    .nullable(),
  limit: z.number().int().min(1).max(100).default(20),
  offset: z.number().int().min(0).default(0),
});

/** Xac nhan NCC da lay hang ve (RPC `supplier_return_confirm`, T-026). */
export const supplierReturnConfirmSchema = z.object({
  returnId: uuidSchema,
  supplierSignaturePath: z.string().trim().max(500).optional().nullable(),
  photoIds: z.array(uuidSchema).optional().nullable(),
});

/** Huy phieu tra QC fail (RPC `supplier_return_cancel`, T-026). */
export const supplierReturnCancelSchema = z.object({
  returnId: uuidSchema,
  reason: z.string().trim().min(1, vi.receiving.cancelReturnReasonRequired),
});

/** Dong cua phieu nhan da post con tra duoc (RPC `supplier_return_eligible_lines`, T-026). */
export const supplierReturnEligibleLinesSchema = z.object({
  grId: uuidSchema,
});

/** Loc danh sach phieu cho hau kiem anh (RPC `receiving_list_photo_reviews`, C2). */
export const photoReviewListSchema = z.object({
  propertyId: uuidSchema,
  reviewStatus: z
    .enum(["pending", "approved", "rejected"])
    .optional()
    .nullable(),
  search: z
    .string()
    .trim()
    .max(100, vi.common.keywordMax100)
    .optional()
    .nullable(),
  limit: z.number().int().min(1).max(100).default(20),
  offset: z.number().int().min(0).default(0),
});

/** Duyet / tu choi anh cua 1 phieu nhan (RPC `receiving_review_photos`, C2). */
export const photoReviewSchema = z
  .object({
    grId: uuidSchema,
    decision: z.enum(["approved", "rejected"]),
    reason: z
      .string()
      .trim()
      .max(1000, vi.common.reasonMax1000)
      .optional()
      .nullable(),
  })
  .superRefine((value, ctx) => {
    if (value.decision === "rejected" && !value.reason) {
      ctx.addIssue({
        code: "custom",
        message: vi.receiving.photoReviewReasonRequired,
        path: ["reason"],
      });
    }
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
export type SupplierReturnListInput = z.infer<typeof supplierReturnListSchema>;
export type SupplierReturnConfirmInput = z.infer<
  typeof supplierReturnConfirmSchema
>;
export type SupplierReturnCancelInput = z.infer<
  typeof supplierReturnCancelSchema
>;
export type SupplierReturnEligibleLinesInput = z.infer<
  typeof supplierReturnEligibleLinesSchema
>;
export type PhotoReviewListInput = z.infer<typeof photoReviewListSchema>;
export type PhotoReviewInput = z.infer<typeof photoReviewSchema>;
