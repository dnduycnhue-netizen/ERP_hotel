// T-045: Gui thong bao that (docs/08-REPORTS-ALERTS.md §3, docs/02-ARCHITECTURE.md §8).
//
// Worker Postgres (pg_cron + pg_net) goi ham nay voi shared secret
// (header `x-notification-secret` = secret `NOTIFICATION_SHARED_SECRET`
// trong Supabase secrets; ban sao cua secret nam trong Vault, worker doc
// qua `notification_sender_config.vault_secret_id`). KHONG dung JWT nguoi
// dung o day — pg_net khong co JWT (xem config.toml: verify_jwt = false).
//
// Kenh:
// - email: Resend (https://api.resend.com/emails). Can secret
//   `RESEND_API_KEY` + `NOTIFICATION_FROM_EMAIL` (vd
//   "ERP Hotel <thongbao@erp-hotel.vn>"). Chua co -> 503 email_not_configured.
// - webpush: Web Push chuan (VAPID) qua npm:web-push. Can secret
//   `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT`
//   (vd "mailto:thongbao@erp-hotel.vn"). Subscription (endpoint + keys)
//   do worker gui kem trong body. Chua co -> 503 webpush_not_configured.
// - zalo: STUB — chua gui that. Can Zalo OA credentials + template ZNS
//   duoc duyet (xem Q98); hien tra 501 zalo_not_configured de worker
//   danh dau delivery 'failed' chu khong bao 'sent' sai.
//
// Body (JSON): { channel: 'email'|'webpush'|'zalo', to: string,
//   subject: string, text: string,
//   subscription?: { endpoint: string, keys: { p256dh: string, auth: string } } }
// Tra: { ok: true, provider, id? } hoac { ok: false, error }.
// Khong log secret / noi dung tin day du — chi log kenh + ket qua.

import webpush from "npm:web-push@3.6.7";

type SendRequest = {
  channel?: unknown;
  to?: unknown;
  subject?: unknown;
  text?: unknown;
  subscription?: unknown;
};

function jsonResponse(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isSubscription(value: unknown): value is {
  endpoint: string;
  keys: { p256dh: string; auth: string };
} {
  if (!isRecord(value)) return false;
  if (typeof value.endpoint !== "string" || value.endpoint === "") {
    return false;
  }
  if (!isRecord(value.keys)) return false;
  return (
    typeof value.keys.p256dh === "string" &&
    value.keys.p256dh !== "" &&
    typeof value.keys.auth === "string" &&
    value.keys.auth !== ""
  );
}

async function sendEmail(
  to: string,
  subject: string,
  text: string,
): Promise<{ ok: boolean; id?: string; error?: string }> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  const from = Deno.env.get("NOTIFICATION_FROM_EMAIL");
  if (!apiKey || !from) {
    return { ok: false, error: "email_not_configured" };
  }
  const res = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ from, to: [to], subject, text }),
  });
  if (!res.ok) {
    const detail = (await res.text()).slice(0, 500);
    console.error("Resend error:", res.status, detail);
    return { ok: false, error: `email_send_failed:${res.status}` };
  }
  const data = (await res.json()) as { id?: string };
  return { ok: true, id: data.id };
}

function sendWebPush(
  subscription: { endpoint: string; keys: { p256dh: string; auth: string } },
  subject: string,
  text: string,
): Promise<{ ok: boolean; error?: string }> {
  const publicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  const privateKey = Deno.env.get("VAPID_PRIVATE_KEY");
  const vapidSubject = Deno.env.get("VAPID_SUBJECT");
  if (!publicKey || !privateKey || !vapidSubject) {
    return Promise.resolve({ ok: false, error: "webpush_not_configured" });
  }
  webpush.setVapidDetails(vapidSubject, publicKey, privateKey);
  const payload = JSON.stringify({ title: subject, body: text });
  return webpush
    .sendNotification(subscription, payload, { TTL: 24 * 60 * 60 })
    .then(() => ({ ok: true as const }))
    .catch((err: unknown) => {
      const message = err instanceof Error ? err.message : "webpush_failed";
      // 410/404 = subscription het han / khong con ton tai.
      console.error("WebPush error:", message.slice(0, 500));
      return {
        ok: false as const,
        error: `webpush_send_failed:${message.slice(0, 200)}`,
      };
    });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const sharedSecret = Deno.env.get("NOTIFICATION_SHARED_SECRET");
  if (!sharedSecret) {
    console.error("NOTIFICATION_SHARED_SECRET is not set.");
    return jsonResponse(503, { error: "send_notification_unavailable" });
  }
  if (request.headers.get("x-notification-secret") !== sharedSecret) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  let body: SendRequest;
  try {
    body = (await request.json()) as SendRequest;
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const channel = body.channel;
  const to = typeof body.to === "string" ? body.to : "";
  const subject = typeof body.subject === "string" ? body.subject : "";
  const text = typeof body.text === "string" ? body.text : "";
  if (
    (channel !== "email" && channel !== "webpush" && channel !== "zalo") ||
    to === "" ||
    subject === "" ||
    text === ""
  ) {
    return jsonResponse(400, { error: "invalid_send_request" });
  }

  if (channel === "email") {
    const result = await sendEmail(to, subject, text);
    if (!result.ok) {
      const status = result.error === "email_not_configured" ? 503 : 502;
      return jsonResponse(status, { ok: false, error: result.error });
    }
    return jsonResponse(200, { ok: true, provider: "resend", id: result.id });
  }

  if (channel === "webpush") {
    if (!isSubscription(body.subscription)) {
      return jsonResponse(400, { error: "invalid_subscription" });
    }
    const result = await sendWebPush(body.subscription, subject, text);
    if (!result.ok) {
      const status = result.error === "webpush_not_configured" ? 503 : 502;
      return jsonResponse(status, { ok: false, error: result.error });
    }
    return jsonResponse(200, { ok: true, provider: "webpush" });
  }

  // Zalo: stub — chua gui that (can Zalo OA + template ZNS, xem Q98).
  return jsonResponse(501, { ok: false, error: "zalo_not_configured" });
});
