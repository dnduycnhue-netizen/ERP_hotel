import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import { callPmsDailyRpc, type PmsDailyActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* PMS ngày — đọc trực tiếp `pms_daily_stats` (không có RPC           */
/* pms_daily_list; RLS SELECT-only thực thi ở tầng dữ liệu) và lịch    */
/* sử sửa qua RPC `pms_daily_history` (đọc `audit_log` mà RLS chặn).  */
/* `database.types.ts` chưa có bảng này nên ép kiểu có chủ đích tại    */
/* đúng những chỗ đọc dưới đây.                                        */
/* ------------------------------------------------------------------ */

/** 1 dòng số liệu vận hành ngày. */
export type PmsDailyStatsRow = {
  id: string;
  org_id: string;
  property_id: string;
  business_date: string;
  rooms_available: number;
  rooms_sold: number;
  guests: number;
  breakfast_pax: number;
  extra_beds: number;
  checkouts: number;
  source: "form" | "file";
  entered_by: string | null;
  created_by: string;
  created_at: string;
  updated_at: string;
};

/** 6 chỉ số của 1 dòng số liệu (dùng cho lịch sử sửa). */
export type PmsDailyStatsValues = {
  rooms_available: number;
  rooms_sold: number;
  guests: number;
  breakfast_pax: number;
  extra_beds: number;
  checkouts: number;
};

/** 1 mục lịch sử nhập/sửa (mới nhất trước). */
export type PmsDailyHistoryEntry = {
  action: "INSERT" | "UPDATE" | "DELETE";
  at: string;
  actor_id: string | null;
  actor_name: string;
  old_stats: PmsDailyStatsValues | null;
  new_stats: PmsDailyStatsValues | null;
};

/** Quyền PMS ngày của người gọi tại 1 property (qua RPC `my_permissions`). */
export type PmsDailyPerms = {
  canEnter: boolean;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}

function toError(error: { message: string }): PmsDailyActionResult<never> {
  return {
    ok: false,
    error: getRpcErrorMessage(extractRpcCode(error.message)),
  };
}

const STATS_COLUMNS =
  "id, org_id, property_id, business_date, rooms_available, rooms_sold, guests, breakfast_pax, extra_beds, checkouts, source, entered_by, created_by, created_at, updated_at";

/** Số liệu vận hành của 1 ngày, nếu đã nhập. */
export async function getPmsDailyStats(
  propertyId: string,
  businessDate: string,
): Promise<PmsDailyActionResult<PmsDailyStatsRow | null>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("pms_daily_stats")
    .select(STATS_COLUMNS)
    .eq("property_id", propertyId)
    .eq("business_date", businessDate)
    .maybeSingle();
  if (error) return toError(error);
  return {
    ok: true,
    data: (data as PmsDailyStatsRow | null) ?? null,
  };
}

/** Lịch sử nhập/sửa của 1 ngày (mới nhất trước). */
export async function getPmsDailyHistory(
  propertyId: string,
  businessDate: string,
): Promise<PmsDailyActionResult<PmsDailyHistoryEntry[]>> {
  const supabase = await createClient();
  const res = await callPmsDailyRpc<{
    ok: boolean;
    entries: PmsDailyHistoryEntry[];
  }>(supabase, "pms_daily_history", {
    p_property_id: propertyId,
    p_date: businessDate,
  });
  if (!res.ok) return res;
  return { ok: true, data: res.data.entries ?? [] };
}

/** Quyền PMS ngày của người gọi tại 1 property. */
export async function getPmsDailyPerms(
  propertyId: string,
): Promise<PmsDailyPerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  return {
    canEnter: perms.has("pms.input"),
  };
}
