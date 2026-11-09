"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Camera, Check, RotateCcw, TriangleAlert, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";

/** Ảnh đã chụp xong: blob JPEG đã nén + SHA-256 tính ở máy (02-ARCHITECTURE.md mục 6). */
export type CapturedPhoto = {
  blob: Blob;
  sha256: string;
  width: number;
  height: number;
  /** Giờ thiết bị lúc chụp (ISO); giờ nghiệp vụ lấy `taken_at` ở máy chủ. */
  deviceTime: string;
};

/** Cạnh dài tối đa sau nén + chất lượng JPEG (02-ARCHITECTURE.md mục 6). */
const MAX_DIMENSION_PX = 1280;
const JPEG_QUALITY = 0.7;

type CaptureStage = "idle" | "starting" | "streaming" | "preview" | "error";

function toHex(bytes: ArrayBuffer): string {
  return Array.from(new Uint8Array(bytes))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Chụp ảnh chứng từ bằng camera trong app (T-016).
 *
 * - Chỉ dùng `getUserMedia`; KHÔNG có hộp chọn file nên không chọn được ảnh
 *   cũ trong thư viện (AC T-016).
 * - Ảnh nén còn tối đa 1280px, JPEG 0.7, tính SHA-256 ở máy rồi mới trả về
 *   qua `onCaptured` để nơi gọi upload lên Storage.
 */
export function CameraCapture({
  onCaptured,
  disabled = false,
}: {
  onCaptured: (photo: CapturedPhoto) => void;
  disabled?: boolean;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const previewUrlRef = useRef<string | null>(null);
  const [stage, setStage] = useState<CaptureStage>("idle");
  const [error, setError] = useState<string | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [captured, setCaptured] = useState<CapturedPhoto | null>(null);

  const stopStream = useCallback(() => {
    streamRef.current?.getTracks().forEach((track) => track.stop());
    streamRef.current = null;
  }, []);

  const revokePreview = useCallback(() => {
    if (previewUrlRef.current) {
      URL.revokeObjectURL(previewUrlRef.current);
      previewUrlRef.current = null;
    }
    setPreviewUrl(null);
  }, []);

  useEffect(() => {
    return () => {
      stopStream();
      revokePreview();
    };
  }, [stopStream, revokePreview]);

  const startCamera = useCallback(async () => {
    setError(null);
    setStage("starting");
    if (
      typeof navigator === "undefined" ||
      !navigator.mediaDevices?.getUserMedia
    ) {
      setError(vi.components.cameraCapture.notSupported);
      setStage("error");
      return;
    }
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: "environment",
          width: { ideal: MAX_DIMENSION_PX },
          height: { ideal: MAX_DIMENSION_PX },
        },
        audio: false,
      });
      streamRef.current = stream;
      setStage("streaming");
      // Gán srcObject sau khi render video xong (state streaming).
      requestAnimationFrame(() => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
        }
      });
    } catch (err) {
      const name =
        typeof err === "object" && err !== null && "name" in err
          ? String((err as { name: unknown }).name)
          : "";
      if (name === "NotAllowedError" || name === "SecurityError") {
        setError(vi.components.cameraCapture.permissionDenied);
      } else if (name === "NotFoundError" || name === "OverconstrainedError") {
        setError(vi.components.cameraCapture.noCamera);
      } else {
        setError(vi.components.cameraCapture.captureFailed);
      }
      setStage("error");
    }
  }, []);

  const capturePhoto = useCallback(async () => {
    const video = videoRef.current;
    if (!video || video.videoWidth === 0) {
      setError(vi.components.cameraCapture.captureFailed);
      setStage("error");
      return;
    }
    if (!window.crypto?.subtle) {
      setError(vi.components.cameraCapture.notSupported);
      setStage("error");
      return;
    }
    const scale = Math.min(
      1,
      MAX_DIMENSION_PX / Math.max(video.videoWidth, video.videoHeight),
    );
    const width = Math.round(video.videoWidth * scale);
    const height = Math.round(video.videoHeight * scale);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) {
      setError(vi.components.cameraCapture.captureFailed);
      setStage("error");
      return;
    }
    ctx.drawImage(video, 0, 0, width, height);
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, "image/jpeg", JPEG_QUALITY),
    );
    if (!blob) {
      setError(vi.components.cameraCapture.captureFailed);
      setStage("error");
      return;
    }
    const hash = await window.crypto.subtle.digest(
      "SHA-256",
      await blob.arrayBuffer(),
    );
    const url = URL.createObjectURL(blob);
    revokePreview();
    previewUrlRef.current = url;
    setPreviewUrl(url);
    setCaptured({
      blob,
      sha256: toHex(hash),
      width,
      height,
      deviceTime: new Date().toISOString(),
    });
    setStage("preview");
  }, [revokePreview]);

  const retake = useCallback(() => {
    revokePreview();
    setCaptured(null);
    setStage("streaming");
  }, [revokePreview]);

  const cancel = useCallback(() => {
    stopStream();
    revokePreview();
    setCaptured(null);
    setStage("idle");
  }, [stopStream, revokePreview]);

  const confirm = useCallback(() => {
    if (!captured) {
      return;
    }
    onCaptured(captured);
    stopStream();
    revokePreview();
    setCaptured(null);
    setStage("idle");
  }, [captured, onCaptured, stopStream, revokePreview]);

  const strings = vi.components.cameraCapture;

  if (stage === "idle") {
    return (
      <Button
        type="button"
        variant="outline"
        onClick={startCamera}
        disabled={disabled}
      >
        <Camera className="size-4" aria-hidden />
        {strings.openCamera}
      </Button>
    );
  }

  if (stage === "error") {
    return (
      <div role="alert" className="flex flex-col gap-2">
        <p className="flex items-start gap-2 text-sm text-destructive">
          <TriangleAlert className="mt-0.5 size-4 shrink-0" aria-hidden />
          {error ?? strings.captureFailed}
        </p>
        <div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={startCamera}
          >
            {strings.tryAgain}
          </Button>
        </div>
      </div>
    );
  }

  if (stage === "starting") {
    return <p className="text-sm text-muted-foreground">{strings.starting}</p>;
  }

  if (stage === "preview" && previewUrl) {
    return (
      <div className="flex flex-col gap-2">
        <p className="text-sm font-medium">{strings.previewTitle}</p>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={previewUrl}
          alt={strings.previewTitle}
          className="max-h-80 w-full rounded-md border object-contain"
        />
        {captured ? (
          <p className="break-all text-xs text-muted-foreground">
            SHA-256: {captured.sha256}
          </p>
        ) : null}
        <div className="flex gap-2">
          <Button type="button" onClick={confirm}>
            <Check className="size-4" aria-hidden />
            {strings.confirm}
          </Button>
          <Button type="button" variant="outline" onClick={retake}>
            <RotateCcw className="size-4" aria-hidden />
            {strings.retake}
          </Button>
          <Button type="button" variant="ghost" onClick={cancel}>
            <X className="size-4" aria-hidden />
            {strings.cancel}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        className="max-h-80 w-full rounded-md border bg-black object-contain"
      />
      <div className="flex gap-2">
        <Button type="button" onClick={capturePhoto}>
          <Camera className="size-4" aria-hidden />
          {strings.capture}
        </Button>
        <Button type="button" variant="ghost" onClick={cancel}>
          <X className="size-4" aria-hidden />
          {strings.cancel}
        </Button>
      </div>
    </div>
  );
}
