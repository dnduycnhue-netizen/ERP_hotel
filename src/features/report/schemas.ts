import { z } from "zod";
import { REPORT_CODES } from "./definitions";
import { vi } from "@/i18n/vi";

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.reports.dateFormatLower);
const monthString = z.string().regex(/^\d{4}-\d{2}$/, vi.reports.monthFormat);

export const reportCodeSchema = z.enum(REPORT_CODES);

/** Tham số lọc từ query string — mọi trường đều tùy chọn. */
export const reportParamsSchema = z
  .object({
    from: dateString.optional(),
    to: dateString.optional(),
    month: monthString.optional(),
    as_of: dateString.optional(),
    date: dateString.optional(),
    warehouse_id: z.string().uuid().optional(),
    supplier_id: z.string().uuid().optional(),
  })
  .refine(
    (v) => !(v.from && v.to && v.from > v.to),
    vi.reports.startDateNotAfterEndDate,
  );

export type ReportParams = z.infer<typeof reportParamsSchema>;
