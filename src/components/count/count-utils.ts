import { vi } from "@/i18n/vi";

/** Thay `{key}` trong mẫu vi.ts bằng giá trị thật. */
export function interpolate(
  template: string,
  values: Record<string, string | number>,
): string {
  return Object.entries(values).reduce(
    (text, [key, value]) => text.replace(`{${key}}`, String(value)),
    template,
  );
}

/** "2026-11-09" → "09/11/2026" (tách chuỗi, không qua Date để tránh lệch múi giờ). */
export function formatYmd(value: string | null): string {
  if (!value) {
    return vi.common.noData;
  }
  const [year, month, day] = value.split("-");
  if (!year || !month || !day) {
    return value;
  }
  return `${day}/${month}/${year}`;
}

/** Số lượng theo định dạng vi-VN, tối đa 4 số thập phân. */
export function formatQty(value: number): string {
  return new Intl.NumberFormat("vi-VN", {
    maximumFractionDigits: 4,
  }).format(value);
}

/** Bỏ dấu + thường hóa để tìm kiếm tiếng Việt khớp cả khi gõ không dấu. */
export function normalizeSearch(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}
