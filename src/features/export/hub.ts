import type { ExportKind } from "./definitions";

/**
 * Helper thuần cho màn hub xuất file tài chính (C4).
 *
 * Contract đã chốt (C3 — KHÔNG đổi URL/param):
 * - PDF PO: GET /api/export/po/[id] ([id] = uuid purchase_orders).
 * - File chuyển khoản: GET /api/export/bank-transfer?ids=<uuid>,...
 * - Excel kế toán (T-043): GET /api/export/[kind]?entity=&from=&to=.
 *
 * File này không import gì phía server nên dùng được cả ở client
 * component lẫn Vitest.
 */

/** Tối đa số đề nghị trong 1 file chuyển khoản (route C3 chặn > 200). */
export const MAX_BANK_TRANSFER_IDS = 200;

/** Các trạng thái PO được tải PDF (C3 gợi ý: PO nháp thì không cho tải). */
export const PO_DOWNLOADABLE_STATUSES = [
  "approved",
  "sent",
  "partially_received",
  "received",
  "closed",
] as const;

export function isPoDownloadable(status: string): boolean {
  return (PO_DOWNLOADABLE_STATUSES as readonly string[]).includes(status);
}

/** GET /api/export/po/[id] (C3). */
export function buildPoPdfUrl(poId: string): string {
  return `/api/export/po/${poId}`;
}

/**
 * GET /api/export/bank-transfer?ids=... (C3). Trùng id được loại bỏ,
 * giữ thứ tự xuất hiện. Trả null khi không có id nào.
 */
export function buildBankTransferUrl(ids: string[]): string | null {
  const unique = [...new Set(ids.filter((id) => id.trim() !== ""))];
  if (unique.length === 0) return null;
  return `/api/export/bank-transfer?ids=${encodeURIComponent(unique.join(","))}`;
}

/** GET /api/export/[kind]?entity=&from=&to= (T-043). */
export function buildAccountingExportUrl(
  kind: ExportKind,
  entityId: string,
  from: string,
  to: string,
): string {
  const params = new URLSearchParams({ entity: entityId, from, to });
  return `/api/export/${kind}?${params.toString()}`;
}

/** Hôm nay theo giờ Việt Nam (yyyy-mm-dd). */
export function todayVn(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/** Ngày đầu tháng của ngày yyyy-mm-dd cho trước. */
export function monthStartOf(date: string): string {
  return `${date.slice(0, 7)}-01`;
}

/** yyyy-mm-dd -> dd/mm/yyyy (giữ nguyên chuỗi lạ). */
export function formatDateVn(value: string | null | undefined): string | null {
  if (!value) return null;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : value;
}

/** timestamptz ISO -> dd/mm/yyyy HH:mm (giờ Việt Nam). */
export function formatDateTimeVn(
  value: string | null | undefined,
): string | null {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  const parts = new Intl.DateTimeFormat("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).formatToParts(d);
  const get = (type: Intl.DateTimeFormatPartTypes) =>
    parts.find((p) => p.type === type)?.value ?? "";
  return `${get("day")}/${get("month")}/${get("year")} ${get("hour")}:${get("minute")}`;
}

export type DownloadResult =
  { ok: true; filename: string | null } | { ok: false; error: string };

/**
 * Tải file xuất qua fetch rồi mở bằng blob URL (thay vì <a href> trần)
 * để lỗi 400/403/500 của route hiện được thông báo tiếng Việt thay vì
 * trình duyệt tải về 1 file JSON lỗi. Chỉ chạy ở client.
 */
export async function downloadExportFile(
  url: string,
  fallbackError: string,
): Promise<DownloadResult> {
  let res: Response;
  try {
    res = await fetch(url);
  } catch {
    return { ok: false, error: fallbackError };
  }
  if (!res.ok) {
    let message = fallbackError;
    try {
      const body = (await res.json()) as { error?: unknown };
      if (typeof body.error === "string" && body.error.trim() !== "") {
        message = body.error;
      }
    } catch {
      // Giữ thông báo mặc định khi body không phải JSON.
    }
    return { ok: false, error: message };
  }
  const blob = await res.blob();
  const disposition = res.headers.get("Content-Disposition") ?? "";
  const filenameMatch = /filename="([^"]+)"/.exec(disposition);
  const filename = filenameMatch?.[1] ?? null;
  const objectUrl = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = objectUrl;
  if (filename) a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(objectUrl);
  return { ok: true, filename };
}
