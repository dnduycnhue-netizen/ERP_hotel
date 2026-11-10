import { z } from "zod";
import { REPORT_CODES } from "./definitions";

const dateString = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng yyyy-mm-dd");
const monthString = z
  .string()
  .regex(/^\d{4}-\d{2}$/, "Tháng phải có dạng yyyy-mm");

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
    "Ngày bắt đầu phải không lớn hơn ngày kết thúc.",
  );

export type ReportParams = z.infer<typeof reportParamsSchema>;
