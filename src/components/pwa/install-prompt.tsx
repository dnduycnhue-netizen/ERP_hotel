"use client";

import { Download, Share, Smartphone, X } from "lucide-react";
import { useCallback, useState, useSyncExternalStore } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import {
  dismissedRecently,
  getInstallPromptServerSnapshot,
  getInstallPromptSnapshot,
  getIsIosServerSnapshot,
  getIsIosSnapshot,
  isStandalone,
  markInstallDismissed,
  subscribeInstallPrompt,
  subscribeNoop,
} from "@/lib/pwa/install";

/**
 * The "Them vao man hinh chinh" (T-046), dung o layout `/m/[p]`.
 *
 * - Android/Chrome: chi hien khi trinh duyet cho phep (su kien
 *   beforeinstallprompt) — khong ep, khong hien khi da cai roi.
 * - iOS Safari khong co su kien nay nen hien huong dan thu cong
 *   (Chia se → Them vao MH chinh).
 * - An "De sau" ghi dau 7 ngay (localStorage), khong lam phien lai.
 * - Doc su kien qua `useSyncExternalStore` (khong setState trong
 *   effect) de khong lech hydration giua server va client.
 */
export function InstallPrompt() {
  const deferred = useSyncExternalStore(
    subscribeInstallPrompt,
    getInstallPromptSnapshot,
    getInstallPromptServerSnapshot,
  );
  const showIos = useSyncExternalStore(
    subscribeNoop,
    getIsIosSnapshot,
    getIsIosServerSnapshot,
  );
  const [dismissed, setDismissed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);

  const dismiss = useCallback(() => {
    markInstallDismissed();
    setDismissed(true);
  }, []);

  async function install() {
    if (!deferred) {
      return;
    }
    setBusy(true);
    try {
      await deferred.prompt();
      const choice = await deferred.userChoice;
      if (choice.outcome === "accepted") {
        setDone(true);
      } else {
        dismiss();
      }
    } finally {
      setBusy(false);
    }
  }

  if (dismissed || isStandalone() || dismissedRecently()) {
    return null;
  }

  if (done) {
    return (
      <section className="mb-4 rounded-xl border bg-card p-4 text-sm">
        {vi.pwa.installDone}
      </section>
    );
  }

  if (deferred) {
    return (
      <section className="mb-4 rounded-xl border bg-card p-4">
        <div className="flex items-start gap-3">
          <Smartphone className="mt-0.5 size-5 shrink-0" aria-hidden />
          <div className="min-w-0 flex-1">
            <p className="text-sm font-semibold">{vi.pwa.installTitle}</p>
            <p className="mt-1 text-sm text-muted-foreground">
              {vi.pwa.installHint}
            </p>
            <div className="mt-3 flex flex-wrap gap-2">
              <Button type="button" onClick={install} disabled={busy}>
                <Download aria-hidden /> {vi.pwa.installButton}
              </Button>
              <Button type="button" variant="outline" onClick={dismiss}>
                {vi.pwa.installLater}
              </Button>
            </div>
          </div>
          <Button
            type="button"
            variant="ghost"
            size="icon"
            onClick={dismiss}
            aria-label={vi.common.close}
          >
            <X aria-hidden />
          </Button>
        </div>
      </section>
    );
  }

  if (showIos) {
    return (
      <section className="mb-4 rounded-xl border bg-card p-4">
        <div className="flex items-start gap-3">
          <Share className="mt-0.5 size-5 shrink-0" aria-hidden />
          <div className="min-w-0 flex-1">
            <p className="text-sm font-semibold">{vi.pwa.iosTitle}</p>
            <ol className="mt-2 list-decimal space-y-1 pl-5 text-sm text-muted-foreground">
              <li>{vi.pwa.iosStep1}</li>
              <li>{vi.pwa.iosStep2}</li>
              <li>{vi.pwa.iosStep3}</li>
            </ol>
            <div className="mt-3">
              <Button type="button" variant="outline" onClick={dismiss}>
                {vi.pwa.installLater}
              </Button>
            </div>
          </div>
          <Button
            type="button"
            variant="ghost"
            size="icon"
            onClick={dismiss}
            aria-label={vi.common.close}
          >
            <X aria-hidden />
          </Button>
        </div>
      </section>
    );
  }

  return null;
}
