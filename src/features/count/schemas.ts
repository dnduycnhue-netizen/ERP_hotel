import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");
const pinSchema = z.string().regex(/^\d{4,6}$/, "Mã PIN phải gồm 4–6 chữ số.");

export const countKindSchema = z.enum(["monthly_full", "cycle"]);
export type CountKindInput = z.infer<typeof countKindSchema>;

export const countReasonCodeSchema = z.enum([
  "lost",
  "damaged",
  "expired",
  "theft",
  "miscount",
  "supplier_short",
  "other",
]);
export type CountReasonCode = z.infer<typeof countReasonCodeSchema>;

/** 1 dong chi tiet dem: { qty, uom } hoac mang cac phan tu nhu vay (RPC `count_record_line`, T-032). */
export const countDetailItemSchema = z.object({
  qty: z.number().positive("Số lượng phải lớn hơn 0."),
  uom: z.string().trim().min(1, "Đơn vị tính không được để trống."),
});

/** Mo dot kiem ke (RPC `count_open`, T-032). */
export const countOpenSchema = z.object({
  warehouseId: uuidSchema,
  kind: countKindSchema,
  businessDate: dateSchema,
  counterIds: z
    .array(uuidSchema)
    .min(1, "Cần ít nhất một người đếm.")
    .max(10, "Tối đa 10 người đếm."),
  clientUuid: uuidSchema.optional().nullable(),
});

/** Ghi 1 dong dem (RPC `count_record_line`, T-032). */
export const countRecordLineSchema = z.object({
  countId: uuidSchema,
  itemId: uuidSchema,
  detail: z
    .union([countDetailItemSchema, z.array(countDetailItemSchema).min(1)])
    .optional()
    .nullable(),
  bottleWeightG: z
    .number()
    .positive("Cân chai phải lớn hơn 0.")
    .optional()
    .nullable(),
  clientUuid: uuidSchema.optional().nullable(),
});

/** Nop dot kiem ke: 1 PIN cho moi nguoi dem, khop khong phu thuoc thu tu (RPC `count_submit`, T-032). */
export const countSubmitSchema = z.object({
  countId: uuidSchema,
  pins: z
    .array(pinSchema)
    .min(1, "Cần ít nhất một mã PIN.")
    .max(10, "Tối đa 10 mã PIN."),
});

/** 1 ly do cho dong do khi khoa dot (RPC `count_lock`, T-032). */
export const countLockReasonSchema = z.object({
  lineId: uuidSchema,
  reasonCode: countReasonCodeSchema,
  explanation: z
    .string()
    .trim()
    .max(1000, "Giải thích tối đa 1000 ký tự.")
    .optional()
    .nullable(),
});

/** Khoa dot kiem ke (RPC `count_lock`, T-032). */
export const countLockSchema = z.object({
  countId: uuidSchema,
  reasons: z.array(countLockReasonSchema).optional().nullable(),
});

/** Ghi dieu chinh chenh lech vao so (RPC `count_adjust_post`, T-032). */
export const countAdjustPostSchema = z.object({
  countId: uuidSchema,
});

/** Them nguoi dem vao dot dang mo/dang dem (RPC `count_add_counter`, T-032). */
export const countAddCounterSchema = z.object({
  countId: uuidSchema,
  userId: uuidSchema,
});

/** Huy dot kiem ke (RPC `count_cancel`, T-032). */
export const countCancelSchema = z.object({
  countId: uuidSchema,
  reason: z.string().trim().min(1, "Lý do hủy không được để trống."),
});

/** Liet ke nguoi duoc dem tai kho (RPC `count_list_counters`, T-033). */
export const countListCountersSchema = z.object({
  propertyId: uuidSchema,
  warehouseId: uuidSchema,
});

/** Loc danh sach dot kiem ke (doc truc tiep `stock_counts`). */
export const countListFilterSchema = z.object({
  propertyId: uuidSchema,
  status: z
    .enum([
      "open",
      "counting",
      "recount",
      "submitted",
      "locked",
      "adjusted",
      "cancelled",
    ])
    .optional()
    .nullable(),
  warehouseId: uuidSchema.optional().nullable(),
  limit: z.number().int().min(1).max(100).default(20),
  offset: z.number().int().min(0).default(0),
});

export type CountOpenInput = z.infer<typeof countOpenSchema>;
export type CountRecordLineInput = z.infer<typeof countRecordLineSchema>;
export type CountSubmitInput = z.infer<typeof countSubmitSchema>;
export type CountLockReasonInput = z.infer<typeof countLockReasonSchema>;
export type CountLockInput = z.infer<typeof countLockSchema>;
export type CountAdjustPostInput = z.infer<typeof countAdjustPostSchema>;
export type CountAddCounterInput = z.infer<typeof countAddCounterSchema>;
export type CountCancelInput = z.infer<typeof countCancelSchema>;
export type CountListCountersInput = z.infer<typeof countListCountersSchema>;
export type CountListFilterInput = z.infer<typeof countListFilterSchema>;
