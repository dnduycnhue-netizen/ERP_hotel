"use server";
import { vi } from "@/i18n/vi";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callLocksRpc, type LockActionResult } from "./rpc";
import {
  dayLockSchema,
  dayUnlockSchema,
  periodCloseSchema,
  periodReopenSchema,
  type DayLockInput,
  type DayUnlockInput,
  type PeriodCloseInput,
  type PeriodReopenInput,
} from "./schemas";

export type DayLockResult = {
  id: string;
};

export type DayUnlockResult = {
  id: string;
};

export type PeriodCloseResult = {
  id: string;
};

export type PeriodReopenResult = {
  id: string;
};

function validationError(
  issues: { message: string }[],
): LockActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? vi.common.invalidData };
}

/** Khoa 1 ngay nghiep vu cua 1 kho (RPC `day_lock`, 120000). */
export async function lockDayAction(
  input: DayLockInput,
): Promise<LockActionResult<DayLockResult>> {
  const parsed = dayLockSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const result = await callLocksRpc<DayLockResult>(supabase, "day_lock", {
    p_warehouse_id: parsed.data.warehouseId,
    p_date: parsed.data.businessDate,
    p_shift: parsed.data.shift ?? null,
  });
  if (result.ok) {
    revalidatePath(`/${parsed.data.propertyId}/inventory/locks`);
  }
  return result;
}

/** Mo khoa 1 ngay nghiep vu, bat buoc ly do (RPC `day_unlock`, 120000). */
export async function unlockDayAction(
  input: DayUnlockInput,
): Promise<LockActionResult<DayUnlockResult>> {
  const parsed = dayUnlockSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const result = await callLocksRpc<DayUnlockResult>(supabase, "day_unlock", {
    p_lock_id: parsed.data.lockId,
    p_reason: parsed.data.reason,
  });
  if (result.ok) {
    revalidatePath(`/${parsed.data.propertyId}/inventory/locks`);
  }
  return result;
}

/** Khoa ky ke toan (RPC `period_close`, 120000 + 280000). */
export async function closePeriodAction(
  input: PeriodCloseInput,
): Promise<LockActionResult<PeriodCloseResult>> {
  const parsed = periodCloseSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const result = await callLocksRpc<PeriodCloseResult>(
    supabase,
    "period_close",
    {
      p_entity_id: parsed.data.entityId,
      p_year: parsed.data.year,
      p_month: parsed.data.month,
    },
  );
  if (result.ok) {
    revalidatePath(`/${parsed.data.propertyId}/inventory/locks`);
  }
  return result;
}

/** Mo lai ky ke toan, bat buoc ly do (RPC `period_reopen`, 120000). */
export async function reopenPeriodAction(
  input: PeriodReopenInput,
): Promise<LockActionResult<PeriodReopenResult>> {
  const parsed = periodReopenSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const result = await callLocksRpc<PeriodReopenResult>(
    supabase,
    "period_reopen",
    {
      p_period_id: parsed.data.periodId,
      p_reason: parsed.data.reason,
    },
  );
  if (result.ok) {
    revalidatePath(`/${parsed.data.propertyId}/inventory/locks`);
  }
  return result;
}
