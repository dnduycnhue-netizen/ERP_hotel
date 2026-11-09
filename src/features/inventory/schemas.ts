import { z } from "zod";

/** Input chung cho 4 RPC `*_list` của T-030 (requisition/transfer/purpose_issue/waste). */
export const docListSchema = z.object({
  propertyId: z.string().uuid(),
  status: z.string().nullable().optional(),
  search: z.string().nullable().optional(),
  limit: z.number().int().min(1).max(100).default(20),
  offset: z.number().int().min(0).default(0),
});

export type DocListInput = z.infer<typeof docListSchema>;

/** Lọc tồn kho: theo kho + tìm mã/tên vật tư. */
export const stockListSchema = z.object({
  propertyId: z.string().uuid(),
  warehouseId: z.string().uuid().nullable().optional(),
  search: z.string().nullable().optional(),
  limit: z.number().int().min(1).max(100).default(20),
  offset: z.number().int().min(0).default(0),
});

export type StockListInput = z.infer<typeof stockListSchema>;

/** Thẻ kho của 1 mặt hàng tại 1 kho; lọc theo khoảng ngày nghiệp vụ (tùy chọn). */
export const stockCardSchema = z.object({
  propertyId: z.string().uuid(),
  warehouseId: z.string().uuid(),
  itemId: z.string().uuid(),
  from: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullable()
    .optional(),
  to: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/)
    .nullable()
    .optional(),
});

export type StockCardInput = z.infer<typeof stockCardSchema>;
