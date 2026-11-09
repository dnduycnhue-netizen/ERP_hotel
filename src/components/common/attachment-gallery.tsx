"use client";

import { useCallback, useEffect, useState } from "react";
import { ImageIcon, RefreshCw, TriangleAlert, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { vi } from "@/i18n/vi";
import { listAttachmentsAction } from "@/features/attachments/actions";
import type { AttachmentWithUrl } from "@/features/attachments/queries";
import type { AttachmentActionResult } from "@/features/attachments/rpc";
import { cn } from "@/lib/utils";

type GalleryStatus = "loading" | "ready" | "empty" | "error";

function formatTakenAt(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return date.toLocaleString("vi-VN", { timeZone: "Asia/Ho_Chi_Minh" });
}

/**
 * Thư viện ảnh chứng từ của một chứng từ (T-016).
 *
 * - Ảnh tải qua `listAttachmentsAction`: mỗi ảnh là signed URL hết hạn sau
 *   5 phút, không lộ đường dẫn Storage ra ngoài.
 * - Ảnh bị phát hiện dùng lại (trùng SHA-256) hiện huy hiệu cảnh báo.
 * - Đủ 4 trạng thái theo AGENTS.md mục 5: đang tải, rỗng, lỗi, có dữ liệu.
 */
export function AttachmentGallery({
  propertyId,
  docType,
  docId,
  className,
}: {
  propertyId: string;
  docType: string;
  docId: string;
  className?: string;
}) {
  const strings = vi.components.attachmentGallery;
  const [status, setStatus] = useState<GalleryStatus>("loading");
  const [items, setItems] = useState<AttachmentWithUrl[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [selected, setSelected] = useState<AttachmentWithUrl | null>(null);

  const applyResult = useCallback(
    (res: AttachmentActionResult<AttachmentWithUrl[]>) => {
      if (!res.ok) {
        setError(res.error);
        setStatus("error");
        return;
      }
      setItems(res.data);
      setStatus(res.data.length === 0 ? "empty" : "ready");
    },
    [],
  );

  const load = useCallback(() => {
    setError(null);
    setStatus("loading");
    listAttachmentsAction({ propertyId, docType, docId })
      .then(applyResult)
      .catch(() => {
        setError(strings.loadError);
        setStatus("error");
      });
  }, [propertyId, docType, docId, applyResult, strings.loadError]);

  // Tai lan dau: setState chi chay trong .then() (callback bat dong bo),
  // khong goi setState dong bo trong effect (react-hooks/set-state-in-effect).
  useEffect(() => {
    listAttachmentsAction({ propertyId, docType, docId })
      .then(applyResult)
      .catch(() => {
        setError(strings.loadError);
        setStatus("error");
      });
  }, [propertyId, docType, docId, applyResult, strings.loadError]);

  if (status === "loading") {
    return (
      <p className="py-8 text-center text-sm text-muted-foreground">
        {vi.components.table.loadingTitle}
      </p>
    );
  }

  if (status === "error") {
    return (
      <ErrorState
        title={strings.loadError}
        description={error ?? undefined}
        onRetry={load}
      />
    );
  }

  if (status === "empty") {
    return (
      <EmptyState
        icon={ImageIcon}
        title={strings.emptyTitle}
        description={strings.emptyDescription}
      />
    );
  }

  return (
    <div className={cn("flex flex-col gap-2", className)}>
      <div className="flex items-center justify-between">
        <p className="text-sm font-medium">
          {strings.title} ({items.length})
        </p>
        <Button type="button" variant="ghost" size="sm" onClick={load}>
          <RefreshCw className="size-4" aria-hidden />
          {strings.refresh}
        </Button>
      </div>
      <div className="grid grid-cols-3 gap-2 sm:grid-cols-4">
        {items.map((item) => (
          <button
            key={item.id}
            type="button"
            onClick={() => setSelected(item)}
            className="relative overflow-hidden rounded-md border focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-ring"
            aria-label={`${strings.photoAlt} ${formatTakenAt(item.taken_at)}`}
          >
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={item.url}
              alt={`${strings.photoAlt} ${formatTakenAt(item.taken_at)}`}
              className="aspect-square w-full object-cover"
            />
            {item.reused_from_id ? (
              <span
                className="absolute left-1 top-1 flex items-center gap-1 rounded bg-destructive px-1.5 py-0.5 text-[11px] font-medium text-destructive-foreground"
                title={strings.reusedHint}
              >
                <TriangleAlert className="size-3" aria-hidden />
                {strings.reusedBadge}
              </span>
            ) : null}
          </button>
        ))}
      </div>

      {selected ? (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
          role="dialog"
          aria-modal="true"
          aria-label={strings.photoAlt}
          onClick={() => setSelected(null)}
        >
          <div
            className="flex max-h-full w-full max-w-2xl flex-col gap-2 overflow-auto rounded-lg bg-background p-4"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="flex items-start justify-between gap-2">
              <div className="text-sm">
                <p className="font-medium">
                  {strings.takenAt}: {formatTakenAt(selected.taken_at)}
                </p>
                <p className="break-all text-xs text-muted-foreground">
                  SHA-256: {selected.sha256}
                </p>
                {selected.reused_from_id ? (
                  <p className="mt-1 flex items-center gap-1 text-xs font-medium text-destructive">
                    <TriangleAlert className="size-3" aria-hidden />
                    {strings.reusedHint}
                  </p>
                ) : null}
              </div>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={() => setSelected(null)}
              >
                <X className="size-4" aria-hidden />
                {strings.close}
              </Button>
            </div>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={selected.url}
              alt={`${strings.photoAlt} ${formatTakenAt(selected.taken_at)}`}
              className="max-h-[70vh] w-full rounded-md border object-contain"
            />
          </div>
        </div>
      ) : null}
    </div>
  );
}
