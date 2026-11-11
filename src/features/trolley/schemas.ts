import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);

/** Tên ca xe đẩy (T-034, Q46): ca mặc định 'day'; KS 2 ca dùng thêm 'morning'/'evening'. */
export const trolleyShiftSchema = z.enum(["day", "morning", "evening"]);
export type TrolleyShiftName = z.infer<typeof trolleyShiftSchema>;

/** Loại dọn phòng cho `p_rooms_done` (T-034, Q45 — phục vụ đối chiếu lý thuyết P2). */
export const trolleyCleanTypeSchema = z.enum([
  "checkout",
  "stayover",
  "vip",
  "child",
]);
export type TrolleyCleanType = z.infer<typeof trolleyCleanTypeSchema>;

/** 1 dòng đếm: mã vật tư + số lượng đã đếm (RPC `_hk_parse_counts`, T-034). */
export const trolleyCountItemSchema = z.object({
  itemId: uuidSchema,
  qty: z.number().min(0, vi.common.quantityNonNegative),
});
export type TrolleyCountItem = z.infer<typeof trolleyCountItemSchema>;

/** 1 phòng đã dọn trong ca (tùy chọn khi đóng ca). */
export const trolleyRoomsDoneItemSchema = z.object({
  roomId: uuidSchema,
  cleanType: trolleyCleanTypeSchema,
  guests: z.number().int().min(0, vi.trolley.guestCountNonNegative).optional(),
});
export type TrolleyRoomsDoneItem = z.infer<typeof trolleyRoomsDoneItemSchema>;

/** Mở ca xe đẩy (RPC `trolley_shift_open`, T-034). */
export const trolleyShiftOpenSchema = z.object({
  propertyId: uuidSchema,
  trolleyWh: uuidSchema,
  shift: trolleyShiftSchema,
  businessDate: dateSchema,
  counts: z.array(trolleyCountItemSchema),
});
export type TrolleyShiftOpenInput = z.infer<typeof trolleyShiftOpenSchema>;

/** Đóng ca xe đẩy (RPC `trolley_shift_close`, T-034). */
export const trolleyShiftCloseSchema = z.object({
  shiftId: uuidSchema,
  counts: z.array(trolleyCountItemSchema),
  roomsDone: z.array(trolleyRoomsDoneItemSchema).default([]),
});
export type TrolleyShiftCloseInput = z.infer<typeof trolleyShiftCloseSchema>;
