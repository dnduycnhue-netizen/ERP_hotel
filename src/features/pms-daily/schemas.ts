import { z } from "zod";
import { vi } from "@/i18n/vi";

const uuidSchema = z.string().uuid(vi.common.invalidId);
const dateSchema = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, vi.common.dateFormatInvalid);

const statSchema = (label: string) =>
  z
    .number()
    .int(vi.pmsDaily.validation.integer.replace("{label}", label))
    .nonnegative(vi.pmsDaily.validation.nonNegative.replace("{label}", label));

/** Lễ tân nhập số liệu vận hành ngày (RPC `pms_daily_upsert`). */
export const pmsDailyUpsertSchema = z
  .object({
    propertyId: uuidSchema,
    businessDate: dateSchema,
    roomsAvailable: statSchema(vi.pmsDaily.fields.roomsAvailable),
    roomsSold: statSchema(vi.pmsDaily.fields.roomsSold),
    guests: statSchema(vi.pmsDaily.fields.guests),
    breakfastPax: statSchema(vi.pmsDaily.labels.breakfasts),
    extraBeds: statSchema(vi.pmsDaily.labels.extraBeds),
    checkouts: statSchema(vi.pmsDaily.labels.checkouts),
  })
  .refine((d) => d.roomsSold <= d.roomsAvailable, {
    message: vi.pmsDaily.soldNotExceedSellable,
    path: ["roomsSold"],
  });
export type PmsDailyUpsertInput = z.infer<typeof pmsDailyUpsertSchema>;
