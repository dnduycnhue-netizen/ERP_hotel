import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import type { Database } from "@/lib/database.types";

/**
 * Kết quả trả về của mọi Server Action khóa ngày/kỳ (C1):
 * không throw ra client, lỗi dịch sang tiếng Việt.
 */
export type LockActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string };

type RpcClient = SupabaseClient<Database>;

/**
 * Gọi RPC khóa ngày/kỳ. `period_close_check` (C1) chưa có trong
 * `database.types.ts` (chỉ sinh lại được khi có DB local) nên gọi qua
 * tên hàm + `.bind` như `callCountRpc` ở T-032/T-033.
 *
 * LƯU Ý: `supabase.rpc` đọc `this.rest` nên KHÔNG được tách method ra
 * khỏi client (`const caller = supabase.rpc` làm mất `this` và nổ
 * `TypeError: Cannot read properties of undefined (reading 'rest')` ở
 * production — lỗi ERROR755103700 ngày 09/11/2026). Phải `.bind`.
 */
export async function callLocksRpc<T>(
  supabase: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<LockActionResult<T>> {
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: T | null;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller(fn, args);
  if (error) {
    return {
      ok: false,
      error: getRpcErrorMessage(extractRpcCode(error.message)),
    };
  }
  return { ok: true, data: data as T };
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}
