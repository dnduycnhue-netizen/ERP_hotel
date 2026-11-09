"use client";

import { CloudOff, RefreshCw, TriangleAlert, Wifi } from "lucide-react";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import {
  discardFailedJobs,
  pumpQueue,
  retryFailedJobs,
} from "@/lib/offline/sync";
import { useOfflineSync } from "@/lib/offline/use-offline-sync";
import { cn } from "@/lib/utils";

function interpolate(
  template: string,
  values: Record<string, string | number>,
): string {
  return Object.entries(values).reduce(
    (text, [key, value]) => text.replace(`{${key}}`, String(value)),
    template,
  );
}

/**
 * Banner trạng thái mạng + đồng bộ offline (T-025), gắn ở layout `/m/[p]`
 * nên hiện trên mọi màn hình hiện trường. Ẩn hẳn khi có mạng và không còn
 * thao tác chờ/lỗi — không chiếm chỗ khi mọi thứ đã đồng bộ.
 */
export function OfflineBanner() {
  const status = useOfflineSync();
  const [busy, setBusy] = useState(false);

  if (status.online && status.pendingCount === 0 && status.failedCount === 0) {
    return null;
  }

  async function handleRetry() {
    setBusy(true);
    try {
      await retryFailedJobs();
    } finally {
      setBusy(false);
    }
  }

  async function handleSyncNow() {
    setBusy(true);
    try {
      await pumpQueue();
    } finally {
      setBusy(false);
    }
  }

  async function handleDiscard() {
    setBusy(true);
    try {
      await discardFailedJobs();
    } finally {
      setBusy(false);
    }
  }

  if (!status.online) {
    return (
      <div
        role="status"
        className="flex items-start gap-2 rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm text-amber-800"
      >
        <CloudOff className="mt-0.5 size-4 shrink-0" aria-hidden />
        <div className="min-w-0">
          <p className="font-medium">{vi.offline.bannerOfflineTitle}</p>
          <p className="mt-0.5">{vi.offline.bannerOfflineHint}</p>
          {status.pendingCount > 0 ? (
            <p className="mt-0.5 font-medium">
              {interpolate(vi.offline.pendingCount, {
                count: status.pendingCount,
              })}
            </p>
          ) : null}
        </div>
      </div>
    );
  }

  if (status.failedCount > 0) {
    return (
      <div
        role="alert"
        className="flex flex-col gap-2 rounded-lg border border-red-200 bg-red-50 p-3 text-sm text-red-800"
      >
        <p className="flex items-start gap-2">
          <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
          <span className="font-medium">
            {interpolate(vi.offline.failedCount, {
              count: status.failedCount,
              error: status.lastError ?? "",
            })}
          </span>
        </p>
        <div className="flex gap-2">
          <Button
            size="sm"
            variant="outline"
            disabled={busy}
            onClick={() => void handleRetry()}
          >
            <RefreshCw
              className={cn("size-4", busy && "animate-spin")}
              aria-hidden
            />
            {vi.offline.retry}
          </Button>
          <Button
            size="sm"
            variant="ghost"
            disabled={busy}
            onClick={() => void handleDiscard()}
          >
            {vi.offline.discardFailed}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div
      role="status"
      className="flex items-center gap-2 rounded-lg border border-sky-200 bg-sky-50 p-3 text-sm text-sky-800"
    >
      <Wifi className="size-4 shrink-0" aria-hidden />
      <p className="min-w-0 flex-1">
        {status.syncing
          ? interpolate(vi.offline.syncing, { count: status.pendingCount })
          : interpolate(vi.offline.pendingCount, {
              count: status.pendingCount,
            })}
      </p>
      {!status.syncing ? (
        <Button
          size="sm"
          variant="outline"
          disabled={busy}
          onClick={() => void handleSyncNow()}
        >
          {vi.offline.syncNow}
        </Button>
      ) : null}
    </div>
  );
}
