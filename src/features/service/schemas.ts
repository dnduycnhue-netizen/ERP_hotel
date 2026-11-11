import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);

export const billingCycleSchema = z.enum([
  "monthly",
  "quarterly",
  "yearly",
  "per_visit",
]);
export type BillingCycle = z.infer<typeof billingCycleSchema>;

export const contractStatusSchema = z.enum([
  "draft",
  "active",
  "suspended",
  "expired",
  "cancelled",
]);
export type ContractStatus = z.infer<typeof contractStatusSchema>;

/** Tạo / cập nhật hợp đồng dịch vụ (RPC `service_contract_save`). */
export const contractSaveSchema = z.object({
  propertyId: uuidSchema,
  contractId: uuidSchema.optional().nullable(),
  title: z.string().trim().min(1, vi.service.contractNameRequired),
  supplierId: uuidSchema,
  expenseCategoryId: uuidSchema,
  costCenterId: uuidSchema,
  startDate: dateSchema,
  endDate: dateSchema.optional().nullable(),
  billingCycle: billingCycleSchema,
  amountPerCycle: z.number().nonnegative(vi.service.amountPerPeriodNonNegative),
  renewNoticeDays: z
    .number()
    .int(vi.service.renewalReminderDaysMustBeInteger)
    .min(0, vi.service.renewalReminderDaysNonNegative)
    .default(30),
  status: contractStatusSchema.default("active"),
});
export type ContractSaveInput = z.infer<typeof contractSaveSchema>;

/** Sinh lịch kỳ cho 1 tháng (RPC `service_schedule_generate`). */
export const scheduleGenerateSchema = z.object({
  propertyId: uuidSchema,
  month: dateSchema,
});
export type ScheduleGenerateInput = z.infer<typeof scheduleGenerateSchema>;

/**
 * Nghiệm thu kỳ hợp đồng HOẶC PO dịch vụ lẻ (RPC `service_accept`).
 * Đúng 1 trong 2 id được truyền (Q75). Rating 1–5 tùy chọn, ảnh là danh
 * sách id attachment đã upload (xem `uploadCapturedPhoto`), note là ghi
 * chú tùy chọn lưu vào `service_acceptances.note` (Q81).
 */
export const serviceAcceptSchema = z
  .object({
    propertyId: uuidSchema,
    scheduleId: uuidSchema.optional().nullable(),
    poId: uuidSchema.optional().nullable(),
    rating: z
      .number()
      .int(vi.service.ratingMustBeInteger)
      .min(1, vi.service.ratingRange1To5)
      .max(5, vi.service.ratingRange1To5)
      .optional()
      .nullable(),
    note: z
      .string()
      .trim()
      .max(1000, vi.common.noteMax1000)
      .optional()
      .nullable(),
    photos: z.array(uuidSchema).default([]),
  })
  .refine((v) => (v.scheduleId == null) !== (v.poId == null), {
    message: vi.service.acceptExactlyOnePeriodOrPo,
  });
export type ServiceAcceptInput = z.infer<typeof serviceAcceptSchema>;
