"use client";

import { useState } from "react";
import { Camera, Check, Star, TriangleAlert, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { CameraCapture } from "@/components/common/camera-capture";
import type { CapturedPhoto } from "@/components/common/camera-capture";
import { uploadCapturedPhoto } from "@/features/attachments/upload-client";
import { acceptServiceAction } from "@/features/service/actions";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

type UploadedPhoto = {
  id: string;
  previewUrl: string;
};

/**
 * Form nghiệm thu kỳ hợp đồng hoặc PO dịch vụ lẻ (T-042).
 * Rating 1–5 tùy chọn; ảnh chụp bằng camera, upload trước qua
 * `uploadCapturedPhoto` (docType `service_acceptance`) rồi mới gửi id
 * ảnh vào RPC `service_accept`.
 *
 * LƯU Ý: RPC `service_accept` không nhận ghi chú (xem Q81) nên form
 * không có ô ghi chú.
 */
export function AcceptForm({
  propertyId,
  scheduleId,
  poId,
  label,
  onDone,
  onCancel,
}: {
  propertyId: string;
  scheduleId?: string | null;
  poId?: string | null;
  label: string;
  onDone: () => void;
  onCancel: () => void;
}) {
  const [rating, setRating] = useState<number | null>(null);
  const [photos, setPhotos] = useState<UploadedPhoto[]>([]);
  const [uploading, setUploading] = useState(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleCaptured(photo: CapturedPhoto) {
    setUploading(true);
    setError(null);
    const previewUrl = URL.createObjectURL(photo.blob);
    const res = await uploadCapturedPhoto({
      propertyId,
      docType: "service_acceptance",
      docId: scheduleId ?? poId ?? "",
      photo,
    });
    setUploading(false);
    if (!res.ok) {
      URL.revokeObjectURL(previewUrl);
      setError(res.error);
      return;
    }
    setPhotos((prev) => [...prev, { id: res.data.id, previewUrl }]);
  }

  function removePhoto(id: string) {
    setPhotos((prev) => {
      const target = prev.find((p) => p.id === id);
      if (target) URL.revokeObjectURL(target.previewUrl);
      return prev.filter((p) => p.id !== id);
    });
  }

  async function handleSubmit() {
    setPending(true);
    setError(null);
    const res = await acceptServiceAction({
      propertyId,
      scheduleId: scheduleId ?? null,
      poId: poId ?? null,
      rating,
      photos: photos.map((p) => p.id),
    });
    setPending(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    onDone();
  }

  return (
    <div className="space-y-4 rounded-lg border bg-card p-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h3 className="font-medium">
            {scheduleId ? vi.service.acceptTitle : vi.service.acceptPoTitle}
          </h3>
          <p className="mt-1 text-sm text-muted-foreground">{label}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.service.acceptHint}
          </p>
        </div>
        <Button type="button" variant="ghost" size="sm" onClick={onCancel}>
          <X className="size-4" aria-hidden />
          {vi.common.close}
        </Button>
      </div>

      <div>
        <p className="text-sm font-medium">{vi.service.rating}</p>
        <div
          className="mt-1 flex gap-1"
          role="radiogroup"
          aria-label={vi.service.rating}
        >
          {[1, 2, 3, 4, 5].map((star) => (
            <button
              key={star}
              type="button"
              role="radio"
              aria-checked={rating === star}
              aria-label={`${star} sao`}
              onClick={() => setRating(rating === star ? null : star)}
              className="rounded p-1"
            >
              <Star
                className={cn(
                  "size-6",
                  rating !== null && star <= rating
                    ? "fill-amber-400 text-amber-400"
                    : "text-muted-foreground",
                )}
                aria-hidden
              />
            </button>
          ))}
          <span className="ml-2 self-center text-sm text-muted-foreground">
            {rating === null ? vi.service.ratingNone : `${rating}/5`}
          </span>
        </div>
        <p className="mt-1 text-xs text-muted-foreground">
          {vi.service.ratingHint}
        </p>
      </div>

      <div>
        <p className="text-sm font-medium">{vi.service.photos}</p>
        <p className="mt-1 text-xs text-muted-foreground">
          {vi.service.photosHint}
        </p>
        <div className="mt-2">
          <CameraCapture
            onCaptured={handleCaptured}
            disabled={uploading || pending}
          />
        </div>
        {uploading ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.common.loading}
          </p>
        ) : null}
        {photos.length > 0 ? (
          <div className="mt-3 flex flex-wrap gap-2">
            {photos.map((p) => (
              <div key={p.id} className="relative">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={p.previewUrl}
                  alt={vi.service.photos}
                  className="h-20 w-20 rounded-md border object-cover"
                />
                <button
                  type="button"
                  aria-label={vi.common.close}
                  onClick={() => removePhoto(p.id)}
                  className="absolute -right-1 -top-1 rounded-full bg-destructive p-0.5 text-destructive-foreground"
                >
                  <X className="size-3" aria-hidden />
                </button>
              </div>
            ))}
          </div>
        ) : null}
      </div>

      <p className="text-sm text-muted-foreground">
        {vi.service.sodAcceptWarning}
      </p>

      {error ? (
        <p
          role="alert"
          className="flex items-start gap-2 text-sm text-destructive"
        >
          <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
          {error}
        </p>
      ) : null}

      <div className="flex gap-2">
        <Button
          type="button"
          disabled={pending || uploading}
          onClick={handleSubmit}
        >
          <Check className="size-4" aria-hidden />
          {pending ? vi.service.accepting : vi.service.acceptButton}
        </Button>
        <Button type="button" variant="outline" onClick={onCancel}>
          <Camera className="size-4" aria-hidden />
          {vi.common.cancel}
        </Button>
      </div>
    </div>
  );
}
