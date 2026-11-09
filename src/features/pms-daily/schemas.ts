import { z } from "zod";

const uuidSchema = z.string().uuid("Mã định danh không hợp lệ.");
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, "Ngày phải có dạng YYYY-MM-DD.");

const statSchema = (label: string) =>
  z
    .number()
    .int(`${label} phải là số nguyên.`)
    .nonnegative(`${label} không được âm.`);

/** Lễ tân nhập số liệu vận hành ngày (RPC `pms_daily_upsert`). */
export const pmsDailyUpsertSchema = z
  .object({
    propertyId: uuidSchema,
    businessDate: dateSchema,
    roomsAvailable: statSchema("Số phòng có thể bán"),
    roomsSold: statSchema("Số phòng đã bán"),
    guests: statSchema("Số khách"),
    breakfastPax: statSchema("Số suất ăn sáng"),
    extraBeds: statSchema("Số giường phụ"),
    checkouts: statSchema("Số lượt trả phòng"),
  })
  .refine((d) => d.roomsSold <= d.roomsAvailable, {
    message: "Số phòng đã bán không được lớn hơn số phòng có thể bán.",
    path: ["roomsSold"],
  });
export type PmsDailyUpsertInput = z.infer<typeof pmsDailyUpsertSchema>;
