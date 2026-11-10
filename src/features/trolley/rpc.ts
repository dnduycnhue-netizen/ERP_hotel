import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import type { Database } from "@/lib/database.types";

/**
 * Kết quả trả về của mọi Server Action xe đẩy (AGENTS.md mục 5):
 * không throw ra client, lỗi dịch sang tiếng Việt. `code` giữ mã lỗi
 * gốc (vd ERR_INVALID_STATUS) để engine đồng bộ offline nhận biết
 * trường hợp đã ghi sổ nhưng mất phản hồi (xem sync.ts).
 */
export type TrolleyActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string; code: string | null };

type RpcClient = SupabaseClient<Database>;

/**
 * Gọi RPC xe đẩy. `database.types.ts` chỉ sinh lại được khi có DB local
 * (Docker) nên các hàm `trolley_*` chưa có trong type sinh sẵn; ép kiểu
 * có chủ đích tại đúng một chỗ này thay vì rải khắp nơi.
 *
 * LƯU Ý: `supabase.rpc` đọc `this.rest` nên KHÔNG được tách method ra khỏi
 * client (`const caller = supabase.rpc` làm mất `this` và nổ
 * `TypeError: Cannot read properties of undefined (reading 'rest')` ở
 * production — lỗi ERROR755103700 ngày 09/11/2026). Phải `.bind`.
 */
export async function callTrolleyRpc<T>(
  supabase: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<TrolleyActionResult<T>> {
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
