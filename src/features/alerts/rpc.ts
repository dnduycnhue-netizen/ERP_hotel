import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import type { Database } from "@/lib/database.types";

/**
 * Ket qua tra ve cua moi Server Action canh bao (AGENTS.md muc 5):
 * khong throw ra client, loi dich sang tieng Viet.
 */
export type AlertActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string; code?: string | null };

type RpcClient = SupabaseClient<Database>;

/**
 * Goi RPC canh bao (T-045). `database.types.ts` chi sinh lai duoc khi co
 * DB local (Docker) nen `alert_ack` chua co trong type sinh san; ep kieu
 * co chu dich tai dung mot cho nay thay vi rai khap noi.
 *
 * LUU Y: `supabase.rpc` doc `this.rest` nen KHONG duoc tach method ra khoi
 * client (`const caller = supabase.rpc` lam mat `this` va no
 * `TypeError: Cannot read properties of undefined (reading 'rest')` o
 * production — loi ERROR755103700 ngay 09/11/2026). Phai `.bind`.
 */
export async function callAlertRpc<T>(
  supabase: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<AlertActionResult<T>> {
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: T | null;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller(fn, args);
  if (error) {
    return { ok: false, error: getRpcErrorMessage(error.message) };
  }
  return { ok: true, data: data as T };
}
