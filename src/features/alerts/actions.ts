"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callAlertRpc, type AlertActionResult } from "./rpc";

export type AlertAckResult = {
  ok: boolean;
  alert_id: string;
  acked_at: string;
  already: boolean;
};

/** Xac nhan da doc 1 canh bao (RPC `alert_ack`, T-045). */
export async function ackAlert(
  propertyId: string,
  alertId: string,
): Promise<AlertActionResult<AlertAckResult>> {
  const supabase = await createClient();
  const result = await callAlertRpc<AlertAckResult>(supabase, "alert_ack", {
    p_alert_id: alertId,
  });
  if (result.ok) {
    revalidatePath(`/${propertyId}/alerts`);
  }
  return result;
}
