/**
 * Helper dang ky web push (T-046). Chay phia client — chi doc bien
 * NEXT_PUBLIC_VAPID_PUBLIC_KEY (khoa cong khai, da co trong
 * .env.example tu T-045; khoa bi mat chi o Supabase secrets).
 */

export function getVapidPublicKey(): string | null {
  const key = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
  return key && key.trim() !== "" ? key : null;
}

export function isPushSupported(): boolean {
  return (
    typeof window !== "undefined" &&
    "serviceWorker" in navigator &&
    "PushManager" in window &&
    "Notification" in window
  );
}

/** base64url (VAPID public key) -> Uint8Array cho pushManager.subscribe. */
export function urlBase64ToUint8Array(base64: string): Uint8Array<ArrayBuffer> {
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const normalized = (base64 + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = window.atob(normalized);
  const output = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    output[i] = raw.charCodeAt(i);
  }
  return output;
}

/** Khoa p256dh/auth cua subscription (ArrayBuffer) -> base64url. */
export function arrayBufferToBase64Url(
  buffer: ArrayBuffer | null,
): string | null {
  if (!buffer) {
    return null;
  }
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return window
    .btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}
