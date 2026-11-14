"use server";
import { vi } from "@/i18n/vi";

import { createClient } from "@/lib/supabase/server";
import { callCountRpc, type CountActionResult } from "./rpc";
import {
  listCounters,
  listIndependentCounterIds,
  type CountCounter,
  type CountRow,
  type CountSheetRow,
  type CountResultRow,
  type CountAdjustmentRow,
} from "./queries";
import {
  countAddCounterSchema,
  countAdjustPostSchema,
  countCancelSchema,
  countListCountersSchema,
  countLockSchema,
  countOpenSchema,
  countRecordLineSchema,
  countSubmitSchema,
  type CountAddCounterInput,
  type CountAdjustPostInput,
  type CountCancelInput,
  type CountListCountersInput,
  type CountLockInput,
  type CountOpenInput,
  type CountRecordLineInput,
  type CountSubmitInput,
} from "./schemas";

export type CountOpenResult = {
  id: string;
  doc_no: string;
  lines_created: number;
};

export type CountRecordLineResult = {
  id: string;
  counted_qty: number;
  round: number;
};

export type CountSubmitResult = {
  id: string;
  recount_line_ids: string[];
  red_line_ids: string[];
};

export type CountLockResult = {
  id: string;
  red_lines: string[];
};

export type CountAdjustPostResult = {
  id: string;
  moves_posted: number;
  total_value: number;
};

export type CountAddCounterResult = {
  id: string;
  counter_ids: string[];
};

export type CountCancelResult = {
  id: string;
};

function validationError(
  issues: { message: string }[],
): CountActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? vi.common.invalidData };
}

/** Mo dot kiem ke (RPC `count_open`, T-032). */
export async function openCountAction(
  input: CountOpenInput,
): Promise<CountActionResult<CountOpenResult>> {
  const parsed = countOpenSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callCountRpc<CountOpenResult>(supabase, "count_open", {
    p_warehouse_id: parsed.data.warehouseId,
    p_kind: parsed.data.kind,
    p_business_date: parsed.data.businessDate,
    p_shift: null,
    p_counter_ids: parsed.data.counterIds,
    p_client_uuid: parsed.data.clientUuid ?? null,
  });
}

/**
 * Ghi 1 dong dem (RPC `count_record_line`, T-032). Idempotent theo
 * `clientUuid`: goi lai cung UUID tra lai dong cu, khong ghi trung.
 * Dùng chung cho cả online và đồng bộ offline (sync.ts).
 */
export async function recordCountLineAction(
  input: CountRecordLineInput,
): Promise<CountActionResult<CountRecordLineResult>> {
  const parsed = countRecordLineSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callCountRpc<CountRecordLineResult>(supabase, "count_record_line", {
    p_count_id: parsed.data.countId,
    p_item_id: parsed.data.itemId,
    p_detail: parsed.data.detail ?? null,
    p_bottle_weight_g: parsed.data.bottleWeightG ?? null,
    p_client_uuid: parsed.data.clientUuid ?? null,
  });
}

/** Nop dot kiem ke: 1 PIN cho moi nguoi dem (RPC `count_submit`, T-032). */
export async function submitCountAction(
  input: CountSubmitInput,
): Promise<CountActionResult<CountSubmitResult>> {
  const parsed = countSubmitSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callCountRpc<CountSubmitResult>(supabase, "count_submit", {
    p_count_id: parsed.data.countId,
    p_pins: parsed.data.pins,
  });
}

/** Khoa dot kiem ke, kem ly do cac dong do (RPC `count_lock`, T-032). */
export async function lockCountAction(
  input: CountLockInput,
): Promise<CountActionResult<CountLockResult>> {
  const parsed = countLockSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callCountRpc<CountLockResult>(supabase, "count_lock", {
    p_count_id: parsed.data.countId,
    p_reasons: parsed.data.reasons ?? null,
  });
}

/** Ghi dieu chinh chenh lech vao so (RPC `count_adjust_post`, T-032). */
export async function adjustCountAction(
  input: CountAdjustPostInput,
): Promise<CountActionResult<CountAdjustPostResult>> {
  const parsed = countAdjustPostSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callCountRpc<CountAdjustPostResult>(supabase, "count_adjust_post", {
    p_count_id: parsed.data.countId,
  });
}

/** Them nguoi dem vao dot dang mo/dang dem (RPC `count_add_counter`, T-032). */
export async function addCountCounterAction(
  input: CountAddCounterInput,
): Promise<CountActionResult<CountAddCounterResult>> {
  const parsed = countAddCounterSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callCountRpc<CountAddCounterResult>(supabase, "count_add_counter", {
    p_count_id: parsed.data.countId,
    p_user_id: parsed.data.userId,
  });
}

/** Huy dot kiem ke (RPC `count_cancel`, T-032). */
export async function cancelCountAction(
  input: CountCancelInput,
): Promise<CountActionResult<CountCancelResult>> {
  const parsed = countCancelSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callCountRpc<CountCancelResult>(supabase, "count_cancel", {
    p_count_id: parsed.data.countId,
    p_reason: parsed.data.reason,
  });
}

/** Liet ke nguoi duoc dem tai kho (RPC `count_list_counters`, T-033). */
export async function listCountersAction(
  input: CountListCountersInput,
): Promise<CountActionResult<CountCounter[]>> {
  const parsed = countListCountersSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return listCounters(parsed.data.propertyId, parsed.data.warehouseId);
}

/** Id người đếm độc lập tại kho (SoD đếm độc lập, Q275). */
export async function listIndependentCountersAction(
  input: CountListCountersInput,
): Promise<CountActionResult<string[]>> {
  const parsed = countListCountersSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return listIndependentCounterIds(parsed.data.propertyId, parsed.data.warehouseId);
}

export type {
  CountCounter,
  CountRow,
  CountSheetRow,
  CountResultRow,
  CountAdjustmentRow,
};
