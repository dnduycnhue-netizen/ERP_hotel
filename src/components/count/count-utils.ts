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

/**
 * Chuỗi số thập phân nhập tay → số, hoặc null khi chưa nhập / chưa hợp lệ.
 * Riêng "0" là số hợp lệ (đếm hết hàng, R30) — không được coi là rỗng.
 */
export function parseDecimal(value: string): number | null {
  if (value === "" || value === "-" || value === "." || value === "-.") {
    return null;
  }
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

/**
 * Tổng quy ra ĐVT lưu kho của các dòng {số lượng, hệ số} (R30):
 * - null khi chưa có dòng nào nhập số (kể cả khi chỉ có dòng trống);
 * - 0 là tổng hợp lệ khi có dòng nhập 0 (hết hàng);
 * - null khi có dòng đã nhập số nhưng không rõ hệ số quy đổi.
 */
export function calcUomTotal(
  entries: Array<{ qty: number | null; factor: number | null }>,
): number | null {
  let total = 0;
  let anyValid = false;
  for (const entry of entries) {
    if (entry.qty === null) {
      continue;
    }
    if (entry.factor === null) {
      return null;
    }
    total += entry.qty * entry.factor;
    anyValid = true;
  }
  return anyValid ? total : null;
}

export type BottleCalcInput = {
  /** Số chai nguyên tem đã nhập (null = chưa nhập). */
  fullBottles: number | null;
  /** Gram chai đang mở đã nhập (null = chưa nhập). */
  openGrams: number | null;
  tareG: number;
  densityGml: number;
  /** Hệ số 1 ĐVT mua mặc định về ĐVT lưu kho (null = không có ĐVT mặc định). */
  defaultFactor: number | null;
  /** Hệ số 1 ml về ĐVT lưu kho (null = không quy đổi được). */
  mlFactor: number | null;
};

/**
 * Cân chai theo cân (R30, docs/05-BUSINESS-RULES.md §6.3):
 * ml chai mở = (gram − bì) ÷ tỉ trọng.
 * - total = null khi chưa nhập gì (cả 2 ô đều trống) hoặc nhập không hợp lệ;
 * - total = 0 hợp lệ khi đã nhập (vd 0 chai nguyên + chai mở cân đúng bằng
 *   bì → 0 ml); gram chai mở nhỏ hơn bì (ml âm) là nhập sai → null.
 */
export function calcBottleTotal(input: BottleCalcInput): {
  openMl: number | null;
  total: number | null;
} {
  const { fullBottles, openGrams, tareG, densityGml, defaultFactor, mlFactor } =
    input;
  const bottles = fullBottles ?? 0;
  const openMl =
    openGrams !== null && densityGml > 0
      ? (openGrams - tareG) / densityGml
      : null;
  if (openMl !== null && openMl < 0) {
    return { openMl, total: null };
  }
  const bottlePart =
    defaultFactor !== null && bottles > 0 ? bottles * defaultFactor : 0;
  const openPart =
    openMl !== null && openMl > 0
      ? mlFactor === null
        ? null
        : openMl * mlFactor
      : 0;
  if (openPart === null) {
    return { openMl, total: null };
  }
  if (fullBottles === null && openGrams === null) {
    return { openMl, total: null };
  }
  return { openMl, total: bottlePart + openPart };
}

/** Bỏ dấu + thường hóa để tìm kiếm tiếng Việt khớp cả khi gõ không dấu. */
export function normalizeSearch(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase();
}
