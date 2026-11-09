import "server-only";

import { createClient } from "@/lib/supabase/server";
import { callAttachmentsRpc, type AttachmentActionResult } from "./rpc";

export type AttachmentBucket = "evidence" | "attachments";

/** Một dòng bảng `attachments` (kèm theo RPC `attachment_list`). */
export type AttachmentRow = {
  id: string;
  bucket: AttachmentBucket;
  path: string;
  sha256: string;
  doc_type: string;
  doc_id: string;
  line_id: string | null;
  taken_at: string;
  device_time: string | null;
  uploaded_by: string;
  reused_from_id: string | null;
  created_at: string;
};

/** Dòng đính kèm kèm signed URL ngắn hạn để hiển thị. */
export type AttachmentWithUrl = AttachmentRow & {
  url: string;
};

/**
 * Liệt kê ảnh của một chứng từ qua RPC `attachment_list` (T-016).
 * Quyền `attachment.view` kiểm tra trong hàm; thiếu quyền trả lỗi
 * (không trả danh sách rỗng) để UI phân biệt được "không có ảnh" và
 * "không được xem".
 */
export async function listAttachments(
  propertyId: string,
  docType: string,
  docId: string,
): Promise<AttachmentActionResult<AttachmentRow[]>> {
  const supabase = await createClient();
  const res = await callAttachmentsRpc<AttachmentRow[]>(
    supabase,
    "attachment_list",
    {
      p_property_id: propertyId,
      p_doc_type: docType,
      p_doc_id: docId,
    },
  );
  if (!res.ok) {
    return res;
  }
  return { ok: true, data: res.data ?? [] };
}
