import type { ReceiptListRow } from "@/features/receiving/queries";

/**
 * Trạng thái 1 dòng chi trong form quyết toán tạm ứng (C12/Q74).
 * `grId` = phiếu nhận đã chốt gắn kèm dòng (null = không gắn);
 * `photoId` = id dòng `attachments` của ảnh biên lai đã tải lên
 * (null = chưa chụp); `photoPreviewUrl` chỉ để xem trước ở máy.
 */
export type SettleFormLine = {
  amount: string;
  grId: string | null;
  photoId: string | null;
  photoPreviewUrl: string | null;
  uploading: boolean;
};

export function emptySettleFormLine(): SettleFormLine {
  return {
    amount: "",
    grId: null,
    photoId: null,
    photoPreviewUrl: null,
    uploading: false,
  };
}

export type SettleLinePayload = {
  amount: number;
  grId: string | null;
  receiptPhotoId: string | null;
};

/**
 * Payload gửi RPC `advance_settle`: bỏ trạng thái hiển thị ở máy,
 * số tiền parse sang number, phiếu nhận/ảnh trống thành null.
 * RPC tự kiểm tra: gr_id phải là phiếu `posted` cùng org/property.
 */
export function buildSettleLines(lines: SettleFormLine[]): SettleLinePayload[] {
  return lines.map((line) => ({
    amount: Number(line.amount),
    grId: line.grId,
    receiptPhotoId: line.photoId,
  }));
}

/**
 * Form gửi được khi: có ít nhất 1 dòng, mọi dòng có số tiền > 0,
 * không dòng nào đang tải ảnh, và không đang gửi.
 * Gắn phiếu nhận / chụp ảnh đều tùy chọn (Q74: chưa bắt buộc).
 */
export function canSubmitSettleLines(
  lines: SettleFormLine[],
  pending: boolean,
): boolean {
  if (pending || lines.length === 0) {
    return false;
  }
  return lines.every(
    (line) =>
      !line.uploading && line.amount.trim() !== "" && Number(line.amount) > 0,
  );
}

/**
 * Xếp phiếu nhận đã chốt cho hộp chọn: phiếu của PO tạm ứng lên trước
 * (đối chiếu đúng PO), trong mỗi nhóm thì phiếu mới nhận trước.
 * Không đổi thứ tự gốc khi không có PO (giữ thứ tự API trả về).
 */
export function sortReceiptsForAdvance(
  receipts: ReceiptListRow[],
  poId: string | null,
): ReceiptListRow[] {
  if (!poId) {
    return [...receipts];
  }
  const byTime = (a: ReceiptListRow, b: ReceiptListRow) =>
    b.received_at.localeCompare(a.received_at);
  const ofPo = receipts.filter((r) => r.po_id === poId).sort(byTime);
  const others = receipts.filter((r) => r.po_id !== poId).sort(byTime);
  return [...ofPo, ...others];
}

function formatReceiptDate(receivedAt: string): string {
  const date = new Date(receivedAt);
  if (Number.isNaN(date.getTime())) {
    return receivedAt;
  }
  return date.toLocaleDateString("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/**
 * Nhãn 1 phiếu nhận trong hộp chọn:
 * "GR-000123 · PO PO-00045 · Nhà cung cấp A · 10/11/2026".
 * Bỏ phần PO khi phiếu không gắn PO nào.
 */
export function formatReceiptOption(receipt: ReceiptListRow): string {
  const parts = [receipt.doc_no];
  if (receipt.po_doc_no) {
    parts.push(`PO ${receipt.po_doc_no}`);
  }
  parts.push(receipt.supplier_name);
  parts.push(formatReceiptDate(receipt.received_at));
  return parts.join(" · ");
}
