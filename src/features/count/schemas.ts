import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);
const pinSchema = z.string().regex(/^\d{4,6}$/, vi.common.pinFormat);

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

/** 1 dong chi tiet dem: { qty, uom } hoac mang cac phan tu nhu vay (RPC `count_record_line`, T-032). R30: qty 0 hop le (het hang), chi tu choi so am. */
export const countDetailItemSchema = z.object({
  qty: z.number().nonnegative(vi.common.quantityNonNegative),
  uom: z.string().trim().min(1, vi.common.uomRequired),
});

/** Mo dot kiem ke (RPC `count_open`, T-032). */
export const countOpenSchema = z.object({
  warehouseId: uuidSchema,
  kind: countKindSchema,
  businessDate: dateSchema,
  counterIds: z
    .array(uuidSchema)
    .min(1, vi.count.needAtLeastOneCounter)
    .max(10, vi.count.max10Counters),
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
    .positive(vi.count.bottleWeightPositive)
    .optional()
    .nullable(),
  clientUuid: uuidSchema.optional().nullable(),
});

/** Nop dot kiem ke: 1 PIN cho moi nguoi dem, khop khong phu thuoc thu tu (RPC `count_submit`, T-032). */
export const countSubmitSchema = z.object({
  countId: uuidSchema,
  pins: z
    .array(pinSchema)
    .min(1, vi.count.needAtLeastOnePin)
    .max(10, vi.count.max10Pins),
});

/** 1 ly do cho dong do khi khoa dot (RPC `count_lock`, T-032). */
export const countLockReasonSchema = z.object({
  lineId: uuidSchema,
  reasonCode: countReasonCodeSchema,
  explanation: z
    .string()
    .trim()
    .max(1000, vi.count.explanationMax1000)
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
  reason: z.string().trim().min(1, vi.common.cancelReasonRequired),
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
