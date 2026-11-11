"use server";
import { vi } from "@/i18n/vi";

import { createClient } from "@/lib/supabase/server";
import { callAttachmentsRpc, type AttachmentActionResult } from "./rpc";
import {
  attachmentListSchema,
  attachmentPrepareUploadSchema,
  attachmentRegisterSchema,
  type AttachmentListInput,
  type AttachmentPrepareUploadInput,
  type AttachmentRegisterInput,
} from "./schemas";
import { listAttachments, type AttachmentWithUrl } from "./queries";

export type PrepareUploadResult = {
  bucket: "evidence" | "attachments";
  legal_entity_id: string;
  path: string;
};

export type RegisterAttachmentResult = {
  id: string;
  reused: boolean;
  reused_attachment_id: string | null;
};

/** Thời hạn signed URL (giây) — "thời hạn ngắn" theo 02-ARCHITECTURE.md mục 6. */
const SIGNED_URL_EXPIRES_IN_SECONDS = 300;

function validationError(
  issues: { message: string }[],
): AttachmentActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? vi.common.invalidData };
}

/**
 * Chuẩn bị đường dẫn upload: kiểm tra quyền `attachment.upload` và trả về
 * bucket + đường dẫn `{legal_entity_id}/{doc_type}/{yyyy}/{mm}/{uuid}.jpg`
 * để client upload trực tiếp lên Storage.
 */
export async function prepareUploadAction(
  input: AttachmentPrepareUploadInput,
): Promise<AttachmentActionResult<PrepareUploadResult>> {
  const parsed = attachmentPrepareUploadSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callAttachmentsRpc<PrepareUploadResult>(
    supabase,
    "attachment_prepare_upload",
    {
      p_property_id: parsed.data.propertyId,
      p_doc_type: parsed.data.docType,
    },
  );
}

/**
 * Đăng ký ảnh sau khi upload xong: ghi dòng `attachments`, phát hiện trùng
 * SHA-256 toàn chuỗi (trả `reused: true` + alert PHOTO_REUSED đã tạo ở tầng
 * DB). Đăng ký lại cùng ảnh cho cùng chứng từ là lũy thừa (trả id cũ).
 */
export async function registerAttachmentAction(
  input: AttachmentRegisterInput,
): Promise<AttachmentActionResult<RegisterAttachmentResult>> {
  const parsed = attachmentRegisterSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callAttachmentsRpc<RegisterAttachmentResult>(
    supabase,
    "attachment_register",
    {
      p_property_id: parsed.data.propertyId,
      p_bucket: parsed.data.bucket,
      p_path: parsed.data.path,
      p_sha256: parsed.data.sha256,
      p_doc_type: parsed.data.docType,
      p_doc_id: parsed.data.docId,
      p_line_id: parsed.data.lineId ?? null,
      p_device_time: parsed.data.deviceTime ?? null,
      p_device_info: parsed.data.deviceInfo ?? {},
    },
  );
}

/**
 * Liệt kê ảnh của một chứng từ kèm signed URL từng ảnh (hết hạn sau 5 phút).
 * Ảnh nào tạo signed URL lỗi thì bỏ qua (không chặn cả danh sách) vì object
 * có thể đã bị dọn ở tầng Storage trong khi dòng `attachments` còn.
 */
export async function listAttachmentsAction(
  input: AttachmentListInput,
): Promise<AttachmentActionResult<AttachmentWithUrl[]>> {
  const parsed = attachmentListSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const rowsRes = await listAttachments(
    parsed.data.propertyId,
    parsed.data.docType,
    parsed.data.docId,
  );
  if (!rowsRes.ok) {
    return rowsRes;
  }
  const supabase = await createClient();
  const withUrls: AttachmentWithUrl[] = [];
  for (const row of rowsRes.data) {
    const { data, error } = await supabase.storage
      .from(row.bucket)
      .createSignedUrl(row.path, SIGNED_URL_EXPIRES_IN_SECONDS);
    if (error || !data?.signedUrl) {
      continue;
    }
    withUrls.push({ ...row, url: data.signedUrl });
  }
  return { ok: true, data: withUrls };
}
