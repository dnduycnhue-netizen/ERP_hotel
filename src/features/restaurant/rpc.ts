import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import type { Database } from "@/lib/database.types";

/**
 * Kết quả trả về của mọi Server Action nhà hàng (AGENTS.md mục 5):
 * không throw ra client, lỗi dịch sang tiếng Việt.
 */
export type RestaurantActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string };

type RpcClient = SupabaseClient<Database>;

/**
 * Gọi RPC nhà hàng (M06). `database.types.ts` chỉ sinh lại được khi có
 * DB local (Docker) nên các hàm `recipe_*` / `banquet_*` / ... chưa có
 * trong type sinh sẵn; ép kiểu có chủ đích tại đúng một chỗ này thay vì
 * rải khắp nơi.
 *
 * LƯU Ý: `supabase.rpc` đọc `this.rest` nên KHÔNG được tách method ra khỏi
 * client — phải `.bind` (lỗi ERROR755103700 ngày 09/11/2026).
 */
export async function callRestaurantRpc<T>(
  supabase: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<RestaurantActionResult<T>> {
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
