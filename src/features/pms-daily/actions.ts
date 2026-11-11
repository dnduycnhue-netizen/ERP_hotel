"use server";
import { vi } from "@/i18n/vi";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callPmsDailyRpc, type PmsDailyActionResult } from "./rpc";
import { pmsDailyUpsertSchema, type PmsDailyUpsertInput } from "./schemas";

export type PmsDailyUpsertResult = {
  ok: boolean;
  id: string;
  property_id: string;
  business_date: string;
  is_new: boolean;
  stats: {
    rooms_available: number;
    rooms_sold: number;
    guests: number;
    breakfast_pax: number;
    extra_beds: number;
    checkouts: number;
  };
  source: string;
};

function validationError(
  issues: { message: string }[],
): PmsDailyActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? vi.common.invalidData };
}

function pmsDailyPath(propertyId: string, businessDate: string): string {
  return `/${propertyId}/frontdesk/pms-daily?date=${businessDate}`;
}

/** Lễ tân nhập/cập nhật số liệu vận hành ngày (RPC `pms_daily_upsert`). */
export async function upsertPmsDailyAction(
  input: PmsDailyUpsertInput,
): Promise<PmsDailyActionResult<PmsDailyUpsertResult>> {
  const parsed = pmsDailyUpsertSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callPmsDailyRpc<PmsDailyUpsertResult>(
    supabase,
    "pms_daily_upsert",
    {
      p_property_id: parsed.data.propertyId,
      p_date: parsed.data.businessDate,
      p_stats: {
        rooms_available: parsed.data.roomsAvailable,
        rooms_sold: parsed.data.roomsSold,
        guests: parsed.data.guests,
        breakfast_pax: parsed.data.breakfastPax,
        extra_beds: parsed.data.extraBeds,
        checkouts: parsed.data.checkouts,
      },
    },
  );
  if (res.ok) {
    revalidatePath(
      pmsDailyPath(parsed.data.propertyId, parsed.data.businessDate),
    );
  }
  return res;
}
