import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import type { Database } from "@/lib/database.types";

/**
 * Kết quả trả về của mọi Server Action buồng phòng (AGENTS.md mục 5):
 * không throw ra client, lỗi dịch sang tiếng Việt. `code` giữ mã lỗi
 * gốc (vd ERR_INVALID_VALUE) để UI nhận biết trường hợp đặc biệt.
 */
export type HousekeepingActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string; code: string | null };

type RpcClient = SupabaseClient<Database>;

/**
 * Gọi RPC buồng phòng. `database.types.ts` chỉ sinh lại được khi có DB
 * local (Docker) nên các hàm `room_setup_standard_*` chưa có trong type
 * sinh sẵn; ép kiểu có chủ đích tại đúng một chỗ này thay vì rải khắp
 * nơi (mẫu `features/trolley/rpc.ts`).
 *
 * LƯU Ý: `supabase.rpc` đọc `this.rest` nên KHÔNG được tách method ra
 * khỏi client — phải `.bind`.
 */
export async function callHousekeepingRpc<T>(
  supabase: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<HousekeepingActionResult<T>> {
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: T | null;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller(fn, args);
  if (error) {
    const code = extractRpcCode(error.message);
    return { ok: false, error: getRpcErrorMessage(code), code };
  }
  return { ok: true, data: data as T };
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}
