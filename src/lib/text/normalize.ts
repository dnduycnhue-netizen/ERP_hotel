/** Bỏ dấu tiếng Việt (kể cả đ/Đ), chữ thường — dùng cho tìm kiếm không dấu. */
export function normalizeSearch(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase();
}

/** Tách cụm tìm kiếm thành các từ đã chuẩn hóa (bỏ ký tự có nghĩa trong bộ lọc PostgREST). */
export function searchWords(value: string): string[] {
  return normalizeSearch(value)
    .replace(/[%,()*\\]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 0);
}
