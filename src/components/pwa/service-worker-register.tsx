"use client";

import { useEffect } from "react";
import type { BeforeInstallPromptEvent } from "@/lib/pwa/install";

/**
 * Dang ky service worker + giu ho su kien cai dat (T-046).
 *
 * - Chi dang ky o production: o dev service worker de giu cache cu khi
 *   sua code. Dang ky that bai (trinh duyet cu, khong phai HTTPS) thi
 *   app van chay binh thuong, chi mat tinh nang offline/push.
 * - `beforeinstallprompt` chi phat 1 lan moi lan tai trang nen giu vao
 *   `window` cho component InstallPrompt (mount sau) doc.
 */
export function ServiceWorkerRegister() {
  useEffect(() => {
    const promptHandler = (event: Event) => {
      event.preventDefault();
      window.__erpInstallPrompt = event as BeforeInstallPromptEvent;
      window.dispatchEvent(new Event("erp-install-prompt-ready"));
    };
    window.addEventListener("beforeinstallprompt", promptHandler);
    if (process.env.NODE_ENV === "production" && "serviceWorker" in navigator) {
      navigator.serviceWorker.register("/sw.js").catch(() => {
        // Khong chan app — offline chi la tinh nang cong them.
      });
    }
    return () =>
      window.removeEventListener("beforeinstallprompt", promptHandler);
  }, []);
  return null;
}
