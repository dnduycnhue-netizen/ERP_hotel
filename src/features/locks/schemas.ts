import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");
const reasonSchema = z
  .string()
  .trim()
  .min(1, "Lý do không được để trống.")
  .max(500, "Lý do tối đa 500 ký tự.");
const yearSchema = z
  .number()
  .int("Năm phải là số nguyên.")
  .min(1, "Năm không hợp lệ.")
  .max(9999, "Năm không hợp lệ.");
const monthSchema = z
  .number()
  .int("Tháng phải là số nguyên.")
  .min(1, "Tháng phải từ 1 đến 12.")
  .max(12, "Tháng phải từ 1 đến 12.");

/** Khoa 1 ngay nghiep vu cua 1 kho (RPC `day_lock`, 120000). */
export const dayLockSchema = z.object({
  propertyId: uuidSchema,
  warehouseId: uuidSchema,
  businessDate: dateSchema,
  shift: z.string().trim().max(50, "Ca tối đa 50 ký tự.").optional().nullable(),
});
export type DayLockInput = z.infer<typeof dayLockSchema>;

/** Mo khoa 1 ngay nghiep vu, bat buoc ly do (RPC `day_unlock`, 120000). */
export const dayUnlockSchema = z.object({
  propertyId: uuidSchema,
  lockId: uuidSchema,
  reason: reasonSchema,
});
export type DayUnlockInput = z.infer<typeof dayUnlockSchema>;

/** Xem truoc dieu kien khoa ky (RPC `period_close_check`, C1). */
export const periodCloseCheckSchema = z.object({
  entityId: uuidSchema,
  year: yearSchema,
  month: monthSchema,
});
export type PeriodCloseCheckInput = z.infer<typeof periodCloseCheckSchema>;

/** Khoa ky ke toan (RPC `period_close`, 120000 + 280000). */
export const periodCloseSchema = z.object({
  propertyId: uuidSchema,
  entityId: uuidSchema,
  year: yearSchema,
  month: monthSchema,
});
export type PeriodCloseInput = z.infer<typeof periodCloseSchema>;

/** Mo lai ky ke toan, bat buoc ly do (RPC `period_reopen`, 120000). */
export const periodReopenSchema = z.object({
  propertyId: uuidSchema,
  periodId: uuidSchema,
  reason: reasonSchema,
});
export type PeriodReopenInput = z.infer<typeof periodReopenSchema>;
