"use client";

import { Bell, BellOff } from "lucide-react";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { subscribePush, unsubscribePush } from "@/features/alerts/actions";
import { vi } from "@/i18n/vi";
import {
  arrayBufferToBase64Url,
  getVapidPublicKey,
  isPushSupported,
  urlBase64ToUint8Array,
} from "@/lib/pwa/push";

type PushState =
  | "loading"
  | "unsupported"
  | "not-configured"
  | "denied"
  | "subscribed"
  | "unsubscribed";

/**
 * Bat/tat nhan thong bao day tren thiet bi nay (T-046), dat o man
 * lich su canh bao. Dang ky qua RPC `push_subscribe` (T-045); tat thi
 * goi `push_unsubscribe` roi huy subscription o trinh duyet.
 *
 * - Chua co khoa VAPID (NEXT_PUBLIC_VAPID_PUBLIC_KEY) thi hien ghi chu,
 *   khong cho bat (khoa do Duy cap, xem Q99).
 * - Quyen Notification bi tu choi thi hien huong dan mo lai, khong
 *   chan luong chinh.
 */
export function PushSubscriptionToggle() {
  const [state, setState] = useState<PushState>("loading");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    let cancelled = false;
    async function check() {
      if (!isPushSupported()) {
        if (!cancelled) setState("unsupported");
        return;
      }
      if (!getVapidPublicKey()) {
        if (!cancelled) setState("not-configured");
        return;
      }
      if (Notification.permission === "denied") {
        if (!cancelled) setState("denied");
        return;
      }
      const registration = await navigator.serviceWorker.getRegistration();
      if (!registration) {
        if (!cancelled) setState("unsubscribed");
        return;
      }
      const subscription = await registration.pushManager.getSubscription();
      if (!cancelled) {
        setState(subscription ? "subscribed" : "unsubscribed");
      }
    }
    check().catch(() => {
      if (!cancelled) setState("unsupported");
    });
    return () => {
      cancelled = true;
    };
  }, []);

  async function enable() {
    setError(null);
    setBusy(true);
    try {
      const key = getVapidPublicKey();
      if (!key) {
        setState("not-configured");
        return;
      }
      const permission = await Notification.requestPermission();
      if (permission === "denied") {
        setState("denied");
        return;
      }
      if (permission !== "granted") {
        return;
      }
      let registration = await navigator.serviceWorker.getRegistration();
      if (!registration) {
        registration = await navigator.serviceWorker.register("/sw.js");
      }
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: urlBase64ToUint8Array(key),
      });
      const p256dh = arrayBufferToBase64Url(subscription.getKey("p256dh"));
      const auth = arrayBufferToBase64Url(subscription.getKey("auth"));
      if (!p256dh || !auth) {
        await subscription.unsubscribe();
        setError(vi.pwa.pushError);
        return;
      }
      const result = await subscribePush(subscription.endpoint, p256dh, auth);
      if (!result.ok) {
        await subscription.unsubscribe();
        setError(result.error);
        return;
      }
      setState("subscribed");
    } catch {
      setError(vi.pwa.pushError);
    } finally {
      setBusy(false);
    }
  }

  async function disable() {
    setError(null);
    setBusy(true);
    try {
      const registration = await navigator.serviceWorker.getRegistration();
      const subscription = await registration?.pushManager.getSubscription();
      if (subscription) {
        const result = await unsubscribePush(subscription.endpoint);
        if (!result.ok) {
          setError(result.error);
          return;
        }
        await subscription.unsubscribe();
      }
      setState("unsubscribed");
    } catch {
      setError(vi.pwa.pushError);
    } finally {
      setBusy(false);
    }
  }

  return (
    <section className="rounded-xl border bg-card p-4">
      <div className="flex items-start gap-3">
        <Bell className="mt-0.5 size-5 shrink-0" aria-hidden />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold">{vi.pwa.pushTitle}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.pwa.pushHint}
          </p>
          {state === "subscribed" && (
            <p className="mt-2 text-sm">{vi.pwa.pushEnabled}</p>
          )}
          {state === "denied" && (
            <p className="mt-2 text-sm text-muted-foreground">
              {vi.pwa.pushDenied}
            </p>
          )}
          {state === "not-configured" && (
            <p className="mt-2 text-sm text-muted-foreground">
              {vi.pwa.pushNotConfigured}
            </p>
          )}
          {state === "unsupported" && (
            <p className="mt-2 text-sm text-muted-foreground">
              {vi.pwa.pushUnsupported}
            </p>
          )}
          {error && <p className="mt-2 text-sm text-destructive">{error}</p>}
          <div className="mt-3">
            {state === "subscribed" && (
              <Button
                type="button"
                variant="outline"
                onClick={disable}
                disabled={busy}
              >
                <BellOff aria-hidden /> {vi.pwa.pushDisable}
              </Button>
            )}
            {state === "unsubscribed" && (
              <Button type="button" onClick={enable} disabled={busy}>
                <Bell aria-hidden /> {vi.pwa.pushEnable}
              </Button>
            )}
          </div>
        </div>
      </div>
    </section>
  );
}
