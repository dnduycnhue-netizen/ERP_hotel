import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import type { AlertActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* Lich su canh bao (T-045) — doc truc tiep `alerts` va                */
/* `notification_deliveries` (RLS SELECT-only thuc thi o tang du lieu). */
/* `database.types.ts` chua co cac bang nay nen ep kieu co chu dich    */
/* tai dung nhung cho doc duoi day (mau finance/queries.ts).           */
/*                                                                     */
/* LUU Y QUYEN DOC (policy SELECT cua migration 160000 / 380000):      */
/* - alerts: chi nguoi co `alert.receive.<code>` tuong ung tai KS.     */
/* - notification_deliveries: nguoi nhan thay dong cua minh; nguoi co  */
/*   bat ky quyen alert.receive.* nao tai KS thay dong cua KS do.      */
/* ------------------------------------------------------------------ */

export type AlertSeverity = "info" | "warn" | "red";

export type AlertRow = {
  id: string;
  property_id: string | null;
  code: string;
  severity: AlertSeverity;
  title: string;
  doc_type: string | null;
  doc_id: string | null;
  created_at: string;
  sent_at: string | null;
  sent_channels: string[];
  ack_by: string | null;
  ack_at: string | null;
};

export type DeliveryStatus =
  "queued" | "sending" | "sent" | "failed" | "skipped_quiet";

export type DeliveryRow = {
  id: string;
  property_id: string | null;
  alert_id: string | null;
  kind: "alert" | "digest";
  digest_date: string | null;
  channel: "email" | "webpush" | "zalo";
  recipient_user_id: string | null;
  recipient_address: string;
  title: string;
  status: DeliveryStatus;
  attempts: number;
  error_message: string | null;
  created_at: string;
  sent_at: string | null;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

const ALERT_COLUMNS =
  "id, property_id, code, severity, title, doc_type, doc_id, created_at, sent_at, sent_channels, ack_by, ack_at";

const DELIVERY_COLUMNS =
  "id, property_id, alert_id, kind, digest_date, channel, recipient_user_id, recipient_address, title, status, attempts, error_message, created_at, sent_at";

function toError(error: { message: string }): AlertActionResult<never> {
  return { ok: false, error: getRpcErrorMessage(error.message) };
}

/** Nguoi goi co bat ky quyen alert.receive.* nao tai KS khong. */
export async function canViewAlerts(propertyId: string): Promise<boolean> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  return (data ?? []).some((p: string) => p.startsWith("alert.receive."));
}

/**
 * Số cảnh báo chưa xử lý (ack_at null) mà người hiện tại thấy được tại
 * khách sạn — dùng cho chuông ở topbar (Q208). RLS của bảng alerts chỉ
 * cho thấy dòng có quyền alert.receive.<code> tương ứng nên đếm trực
 * tiếp qua client là đúng; head-only nên chỉ trả số đếm, không tải dòng.
 * Lỗi truy vấn trả 0 (không badge) thay vì làm sập vỏ app.
 */
export async function countUnreadAlerts(
  propertyId: string,
): Promise<number> {
  const supabase = await createClient();
  const { count, error } = await untyped(supabase)
    .from("alerts")
    .select("id", { count: "exact", head: true })
    .eq("property_id", propertyId)
    .is("ack_at", null);
  if (error) return 0;
  return count ?? 0;
}

export async function listAlerts(
  propertyId: string,
): Promise<AlertActionResult<AlertRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("alerts")
    .select(ALERT_COLUMNS)
    .eq("property_id", propertyId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) return toError(error);
  return { ok: true, data: (data ?? []) as unknown as AlertRow[] };
}

export async function listDeliveries(
  propertyId: string,
): Promise<AlertActionResult<DeliveryRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("notification_deliveries")
    .select(DELIVERY_COLUMNS)
    .eq("property_id", propertyId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (error) return toError(error);
  return { ok: true, data: (data ?? []) as unknown as DeliveryRow[] };
}
