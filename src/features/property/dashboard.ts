import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import { parseDashboardOverview, type DashboardOverview } from "./schemas";

type RpcClient = SupabaseClient<Database>;

/**
 * Doc tong quan 1 KS bang 1 RPC duy nhat (C10, Q125). Thay cho 5 SELECT
 * cu cua trang tong quan: 1 select KS + phap nhan, roi 4 count song song.
 * `property_dashboard_overview` chua co trong `database.types.ts` (chi
 * sinh lai duoc khi co DB local) nen ep kieu co chu dich tai dung mot
 * cho nay thay vi rai khap noi — theo tien le report/rpc + finance/rpc.
 *
 * LUU Y: `supabase.rpc` doc `this.rest` nen KHONG duoc tach method ra khoi
 * client — phai `.bind(supabase)` (loi ERROR755103700 ngay 09/11/2026).
 */
export async function getPropertyDashboardOverview(
  propertyId: string,
): Promise<DashboardOverview> {
  const supabase: RpcClient = await createClient();
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: unknown;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller("property_dashboard_overview", {
    p_property_id: propertyId,
  });

  if (error) {
    throw new Error(extractRpcCode(error.message) || "ERR_UNKNOWN");
  }
  return parseDashboardOverview(data);
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}
