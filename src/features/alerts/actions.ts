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

export type PushSubscriptionResult = {
  ok: boolean;
  endpoint: string;
};

/** Dang ky web push cho thiet bi hien tai (RPC `push_subscribe`, T-045). */
export async function subscribePush(
  endpoint: string,
  p256dh: string,
  auth: string,
): Promise<AlertActionResult<PushSubscriptionResult>> {
  const supabase = await createClient();
  return callAlertRpc<PushSubscriptionResult>(supabase, "push_subscribe", {
    p_endpoint: endpoint,
    p_p256dh: p256dh,
    p_auth: auth,
  });
}

/** Huy dang ky web push (RPC `push_unsubscribe`, T-045). */
export async function unsubscribePush(
  endpoint: string,
): Promise<AlertActionResult<PushSubscriptionResult>> {
  const supabase = await createClient();
  return callAlertRpc<PushSubscriptionResult>(supabase, "push_unsubscribe", {
    p_endpoint: endpoint,
  });
}
