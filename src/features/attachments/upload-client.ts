"use client";

import { createClient } from "@/lib/supabase/client";
import {
  prepareUploadAction,
  registerAttachmentAction,
  type RegisterAttachmentResult,
} from "./actions";
import type { CapturedPhoto } from "@/components/common/camera-capture";

export type UploadCapturedPhotoResult =
  { ok: true; data: RegisterAttachmentResult } | { ok: false; error: string };

/**
 * Luồng tải ảnh chụp đầy đủ (T-016), dùng chung cho mọi màn hình cần ảnh
 * chứng từ (nhận hàng T-024, kiểm kê T-033, hủy hàng...):
 *   1. Server action chuẩn bị đường dẫn (kiểm tra quyền `attachment.upload`).
 *   2. Client upload trực tiếp blob JPEG lên Storage bucket `evidence`
 *      (policy INSERT giới hạn theo pháp nhân người dùng có quyền).
 *   3. Server action đăng ký dòng `attachments` + phát hiện trùng SHA-256.
 *
 * Không có bước nào dùng hộp chọn file: ảnh chỉ đến từ `CameraCapture`.
 */
export async function uploadCapturedPhoto(args: {
  propertyId: string;
  docType: string;
  docId: string;
  lineId?: string | null;
  photo: CapturedPhoto;
}): Promise<UploadCapturedPhotoResult> {
  const prepared = await prepareUploadAction({
    propertyId: args.propertyId,
    docType: args.docType,
  });
  if (!prepared.ok) {
    return prepared;
  }

  const supabase = createClient();
  const { error: uploadError } = await supabase.storage
    .from(prepared.data.bucket)
    .upload(prepared.data.path, args.photo.blob, {
      contentType: "image/jpeg",
      upsert: false,
    });
  if (uploadError) {
    return {
      ok: false,
      error: "Không tải được ảnh lên. Hãy kiểm tra mạng rồi thử lại.",
    };
  }

  return registerAttachmentAction({
    propertyId: args.propertyId,
    bucket: prepared.data.bucket,
    path: prepared.data.path,
    sha256: args.photo.sha256,
    docType: args.docType,
    docId: args.docId,
    lineId: args.lineId ?? null,
    deviceTime: args.photo.deviceTime,
    deviceInfo: {
      width: args.photo.width,
      height: args.photo.height,
      source: "camera",
    },
  });
}
