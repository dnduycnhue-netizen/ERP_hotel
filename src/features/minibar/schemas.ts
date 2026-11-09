import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");

/** 1 dòng thiếu trong phiếu kiểm: { item_id, missing_qty, near_expiry? }. */
export const minibarSubmitLineSchema = z.object({
  itemId: uuidSchema,
  missingQty: z.number().positive("Số thiếu phải lớn hơn 0."),
  nearExpiry: z.boolean().optional(),
});
export type MinibarSubmitLineInput = z.infer<typeof minibarSubmitLineSchema>;

/** Lễ tân yêu cầu kiểm minibar khi khách trả phòng (RPC `minibar_request_check`). */
export const minibarRequestCheckSchema = z.object({
  propertyId: uuidSchema,
  roomId: uuidSchema,
  trigger: z.enum(["checkout", "daily", "audit"]).default("checkout"),
});
export type MinibarRequestCheckInput = z.infer<
  typeof minibarRequestCheckSchema
>;

/** Buồng phòng nộp kết quả kiểm (RPC `minibar_submit_check`). */
export const minibarSubmitCheckSchema = z.object({
  propertyId: uuidSchema,
  checkId: uuidSchema,
  lines: z
    .array(minibarSubmitLineSchema)
    .min(1, "Cần ít nhất một món thiếu để gửi kết quả kiểm."),
  clientUuid: uuidSchema,
});
export type MinibarSubmitCheckInput = z.infer<typeof minibarSubmitCheckSchema>;

/** Lễ tân xác nhận đã thu + số folio (RPC `minibar_confirm_charge`). */
export const minibarConfirmChargeSchema = z.object({
  propertyId: uuidSchema,
  checkId: uuidSchema,
  folioNo: z.string().trim().min(1, "Số folio không được để trống."),
});
export type MinibarConfirmChargeInput = z.infer<
  typeof minibarConfirmChargeSchema
>;

/** Đề nghị miễn tiền minibar (RPC `minibar_request_waive`). */
export const minibarRequestWaiveSchema = z.object({
  propertyId: uuidSchema,
  checkId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do miễn không được để trống."),
});
export type MinibarRequestWaiveInput = z.infer<
  typeof minibarRequestWaiveSchema
>;

/** Quản lý duyệt/từ chối đề nghị miễn (RPC `minibar_decide_waive`). */
export const minibarDecideWaiveSchema = z.object({
  propertyId: uuidSchema,
  checkId: uuidSchema,
  decision: z.enum(["approved", "rejected"]),
  note: z.string().trim().max(1000, "Ghi chú tối đa 1000 ký tự.").optional().nullable(),
});
export type MinibarDecideWaiveInput = z.infer<typeof minibarDecideWaiveSchema>;

/** Chuyển phiếu sang thu muộn (RPC `minibar_mark_late_charge`). */
export const minibarMarkLateChargeSchema = z.object({
  propertyId: uuidSchema,
  checkId: uuidSchema,
  note: z.string().trim().max(1000, "Ghi chú tối đa 1000 ký tự.").optional().nullable(),
});
export type MinibarMarkLateChargeInput = z.infer<
  typeof minibarMarkLateChargeSchema
>;

/** Xóa sổ phiếu kiểm (RPC `minibar_write_off`, gm). */
export const minibarWriteOffSchema = z.object({
  propertyId: uuidSchema,
  checkId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do xóa sổ không được để trống."),
});
export type MinibarWriteOffInput = z.infer<typeof minibarWriteOffSchema>;

/** 1 dòng bổ sung: { item_id, qty, lot_id? } (RPC `minibar_refill`). */
export const minibarRefillLineSchema = z.object({
  itemId: uuidSchema,
  qty: z.number().positive("Số lượng phải lớn hơn 0."),
  lotId: uuidSchema.optional().nullable(),
});
export type MinibarRefillLineInput = z.infer<typeof minibarRefillLineSchema>;

/** Bổ sung minibar vào phòng (RPC `minibar_refill`). */
export const minibarRefillSchema = z.object({
  propertyId: uuidSchema,
  roomId: uuidSchema,
  lines: z
    .array(minibarRefillLineSchema)
    .min(1, "Cần ít nhất một món để bổ sung."),
});
export type MinibarRefillInput = z.infer<typeof minibarRefillSchema>;

/** Đặt giá minibar theo mốc hiệu lực (RPC `minibar_price_set`). */
export const minibarPriceSetSchema = z.object({
  propertyId: uuidSchema,
  itemId: uuidSchema,
  price: z.number().positive("Giá bán phải lớn hơn 0."),
  validFrom: dateSchema,
  validTo: dateSchema.optional().nullable(),
});
export type MinibarPriceSetInput = z.infer<typeof minibarPriceSetSchema>;

/** Đối soát minibar 1 ngày (RPC `minibar_reconcile`). */
export const minibarReconcileSchema = z.object({
  propertyId: uuidSchema,
  date: dateSchema,
});
export type MinibarReconcileInput = z.infer<typeof minibarReconcileSchema>;

/** Danh sách thu hồi hàng sắp hết hạn (RPC `minibar_recall_list`). */
export const minibarRecallListSchema = z.object({
  propertyId: uuidSchema,
  days: z.number().int().min(0).max(365).default(30),
});
export type MinibarRecallListInput = z.infer<typeof minibarRecallListSchema>;
