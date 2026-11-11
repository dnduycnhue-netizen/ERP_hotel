import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);

/**
 * Loại dọn phòng của chuẩn setup (M07 §07.02, migration 310000):
 * cùng 1 item có thể vừa có định mức/phòng vừa có định mức/khách
 * (unique theo room_type_id × clean_type × item_id × per_guest).
 */
export const roomCleanTypeSchema = z.enum([
  "checkout",
  "stayover",
  "vip",
  "child",
]);
export type RoomCleanType = z.infer<typeof roomCleanTypeSchema>;

/** Lưu (thêm/sửa) 1 dòng tiêu chuẩn phòng (RPC `room_setup_standard_set`). */
export const roomSetupStandardSaveSchema = z.object({
  propertyId: uuidSchema,
  roomTypeId: uuidSchema,
  cleanType: roomCleanTypeSchema,
  itemId: uuidSchema,
  qty: z.number().min(0, vi.common.quantityNonNegative),
  perGuest: z.boolean().default(false),
});
export type RoomSetupStandardSaveInput = z.infer<
  typeof roomSetupStandardSaveSchema
>;

/** Xóa 1 dòng tiêu chuẩn phòng (RPC `room_setup_standard_delete`, C7). */
export const roomSetupStandardDeleteSchema = z.object({
  propertyId: uuidSchema,
  standardId: uuidSchema,
});
export type RoomSetupStandardDeleteInput = z.infer<
  typeof roomSetupStandardDeleteSchema
>;
