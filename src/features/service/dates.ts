/**
 * Tiện ích ngày nghiệp vụ (giờ Việt Nam) dùng được cả client lẫn server.
 * Không import `server-only` — tách riêng khỏi `queries.ts` (server-only)
 * để component client (danh sách/chi tiết hợp đồng) dùng được.
 */

/** Ngày hôm nay theo giờ Việt Nam (YYYY-MM-DD). */
export function todayVn(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/** Số ngày còn lại tới hạn (âm = đã quá hạn), tính theo giờ Việt Nam. */
export function daysLeft(endDate: string): number {
  const todayMs = new Date(`${todayVn()}T00:00:00+07:00`).getTime();
  const endMs = new Date(`${endDate}T00:00:00+07:00`).getTime();
  return Math.round((endMs - todayMs) / 86400000);
}
