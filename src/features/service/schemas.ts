import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");

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
  title: z.string().trim().min(1, "Tên hợp đồng không được để trống."),
  supplierId: uuidSchema,
  expenseCategoryId: uuidSchema,
  costCenterId: uuidSchema,
  startDate: dateSchema,
  endDate: dateSchema.optional().nullable(),
  billingCycle: billingCycleSchema,
  amountPerCycle: z.number().nonnegative("Số tiền mỗi kỳ không được âm."),
  renewNoticeDays: z
    .number()
    .int("Số ngày nhắc gia hạn phải là số nguyên.")
    .min(0, "Số ngày nhắc gia hạn không được âm.")
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
      .int("Đánh giá phải là số nguyên.")
      .min(1, "Đánh giá từ 1 đến 5 sao.")
      .max(5, "Đánh giá từ 1 đến 5 sao.")
      .optional()
      .nullable(),
    note: z
      .string()
      .trim()
      .max(1000, "Ghi chú tối đa 1000 ký tự.")
      .optional()
      .nullable(),
    photos: z.array(uuidSchema).default([]),
  })
  .refine((v) => (v.scheduleId == null) !== (v.poId == null), {
    message: "Nghiệm thu đúng một kỳ hợp đồng hoặc một đơn mua dịch vụ.",
  });
export type ServiceAcceptInput = z.infer<typeof serviceAcceptSchema>;
