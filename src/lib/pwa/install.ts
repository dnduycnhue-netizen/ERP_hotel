/**
 * Bat su kien `beforeinstallprompt` (T-046).
 *
 * Su kien nay chi phat 1 lan moi lan tai trang, co the phat truoc khi
 * component InstallPrompt mount — nen ServiceWorkerRegister (mount o
 * root layout, som nhat) giu ho su kien vao `window` va phat them su
 * kien phu de component biet ma doc.
 */

export type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
};

declare global {
  interface Window {
    __erpInstallPrompt?: BeforeInstallPromptEvent;
  }
}

export function isStandalone(): boolean {
  if (typeof window === "undefined") {
    return false;
  }
  if (window.matchMedia("(display-mode: standalone)").matches) {
    return true;
  }
  return (
    "standalone" in navigator &&
    (navigator as { standalone?: boolean }).standalone === true
  );
}

export function isIos(): boolean {
  if (typeof window === "undefined") {
    return false;
  }
  return /iphone|ipad|ipod/i.test(window.navigator.userAgent);
}

const DISMISS_KEY = "erp-pwa-install-dismissed-at";
const DISMISS_DAYS = 7;

export function dismissedRecently(): boolean {
  try {
    const raw = window.localStorage.getItem(DISMISS_KEY);
    if (!raw) {
      return false;
    }
    const at = Number(raw);
    return (
      Number.isFinite(at) &&
      Date.now() - at < DISMISS_DAYS * 24 * 60 * 60 * 1000
    );
  } catch {
    return false;
  }
}

export function markInstallDismissed(): void {
  try {
    window.localStorage.setItem(DISMISS_KEY, String(Date.now()));
  } catch {
    // Khong luu duoc thi an tam thoi trong phien nay.
  }
}

/** Subscribe cho `useSyncExternalStore` — su kien cai dat chi phat 1 lan. */
export function subscribeInstallPrompt(onChange: () => void): () => void {
  window.addEventListener("erp-install-prompt-ready", onChange);
  return () => window.removeEventListener("erp-install-prompt-ready", onChange);
}

export function getInstallPromptSnapshot(): BeforeInstallPromptEvent | null {
  return window.__erpInstallPrompt ?? null;
}

export function getInstallPromptServerSnapshot(): null {
  return null;
}

/** iOS khong doi trong phien — snapshot on dinh, khong can subscribe. */
export function subscribeNoop(): () => void {
  return () => {};
}

export function getIsIosSnapshot(): boolean {
  return isIos();
}

export function getIsIosServerSnapshot(): boolean {
  return false;
}
