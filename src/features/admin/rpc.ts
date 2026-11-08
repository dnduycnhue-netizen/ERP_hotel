import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import type { Database } from "@/lib/database.types";

/**
 * Kết quả trả về của mọi Server Action quản trị (AGENTS.md mục 5):
 * không throw ra client, lỗi dịch sang tiếng Việt.
 */
export type AdminActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string };

type RpcClient = SupabaseClient<Database>;

/**
 * Gọi RPC quản trị mới (T-005). `database.types.ts` chỉ sinh lại được khi
 * có DB local (Docker) nên các hàm `admin_*` chưa có trong type sinh sẵn;
 * ép kiểu có chủ đích tại đúng một chỗ này thay vì rải khắp nơi.
 */
export async function callAdminRpc<T>(
  supabase: RpcClient,
  fn: string,
  args: Record<string, unknown>,
): Promise<AdminActionResult<T>> {
  const caller = supabase.rpc as unknown as (
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
