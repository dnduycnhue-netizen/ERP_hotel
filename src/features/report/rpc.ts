import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import type { ReportCode } from "./definitions";

type RpcClient = SupabaseClient<Database>;

/**
 * Gọi RPC báo cáo (T-044). `report_get` chưa có trong `database.types.ts`
 * (chỉ sinh lại được khi có DB local) nên ép kiểu có chủ đích tại đúng
 * một chỗ này thay vì rải khắp nơi — theo tiền lệ finance/callFinanceRpc.
 *
 * LƯU Ý: `supabase.rpc` đọc `this.rest` nên KHÔNG được tách method ra khỏi
 * client — phải `.bind(supabase)` (lỗi ERROR755103700 ngày 09/11/2026).
 */
export async function callReportRpc(
  propertyId: string,
  code: ReportCode,
  params: Record<string, unknown>,
): Promise<Record<string, unknown> | null> {
  const supabase: RpcClient = await createClient();
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: Record<string, unknown> | null;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller("report_get", {
    p_property_id: propertyId,
    p_code: code,
    p_params: params,
  });

  if (error) {
    throw new Error(extractRpcCode(error.message) || "ERR_UNKNOWN");
  }
  return data ?? null;
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}
