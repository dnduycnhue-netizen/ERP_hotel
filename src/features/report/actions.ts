"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getRpcErrorMessage } from "@/i18n/errors.vi";

export type RefreshStockCardResult =
  { ok: true } | { ok: false; error: string };

/**
 * Làm mới bảng tổng hợp thẻ kho (RPC `report_refresh_stock_card_mv`): báo cáo thẻ
 * kho đọc từ materialized view làm mới 07:35 hằng ngày, chứng từ phát sinh sau đó
 * chưa hiện (C6-N1). Quyền kiểm trong RPC (`report.view.rpt_stock_card`).
 */
export async function refreshStockCardAction(
  propertyId: string,
): Promise<RefreshStockCardResult> {
  const supabase = await createClient();
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{ error: { message: string } | null }>;
  const { error } = await caller("report_refresh_stock_card_mv", {});
  if (error) {
    const m = error.message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
    return { ok: false, error: getRpcErrorMessage(m ? m[0] : null) };
  }
  revalidatePath(`/${propertyId}/reports/stock-card`);
  return { ok: true };
}
