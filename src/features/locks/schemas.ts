import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);
const reasonSchema = z
  .string()
  .trim()
  .min(1, vi.procurement.detail.reasonRequired)
  .max(500, vi.common.reasonMax500);
const yearSchema = z
  .number()
  .int(vi.locks.yearMustBeInteger)
  .min(1, vi.locks.yearInvalid)
  .max(9999, vi.locks.yearInvalid);
const monthSchema = z
  .number()
  .int(vi.locks.monthMustBeInteger)
  .min(1, vi.locks.monthRange1To12)
  .max(12, vi.locks.monthRange1To12);

/** Khoa 1 ngay nghiep vu cua 1 kho (RPC `day_lock`, 120000). */
export const dayLockSchema = z.object({
  propertyId: uuidSchema,
  warehouseId: uuidSchema,
  businessDate: dateSchema,
  shift: z.string().trim().max(50, vi.locks.shiftMax50).optional().nullable(),
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
