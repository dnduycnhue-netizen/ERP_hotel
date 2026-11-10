/**
 * Tien ich ngay thang thuan (C1): lich thang khoa ngay + ngay hien tai
 * theo mui gio nghiep vu Asia/Ho_Chi_Minh. Khong dung `toISOString`
 * (UTC) vi rang sang gio VN van la ngay hom truoc o UTC.
 */

export const VIETNAM_TIME_ZONE = "Asia/Ho_Chi_Minh";

const DATE_RE = /^(\d{4})-(\d{2})-(\d{2})$/;

/** Ngay hien tai theo Asia/Ho_Chi_Minh, dang YYYY-MM-DD. */
export function todayInVietnam(now: Date = new Date()): string {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: VIETNAM_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
}

/** Thang/nam co hop le khong (month 1-12, year 1-9999). */
export function isValidYearMonth(year: number, month: number): boolean {
  return (
    Number.isInteger(year) &&
    Number.isInteger(month) &&
    year >= 1 &&
    year <= 9999 &&
    month >= 1 &&
    month <= 12
  );
}

/** So ngay trong thang (month 1-12). */
export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/** Ngay dau / cuoi thang, dang YYYY-MM-DD. */
export function monthRange(
  year: number,
  month: number,
): {
  first: string;
  last: string;
} {
  const mm = String(month).padStart(2, "0");
  return {
    first: `${year}-${mm}-01`,
    last: `${year}-${mm}-${String(daysInMonth(year, month)).padStart(2, "0")}`,
  };
}

/** Tat ca cac ngay trong thang, dang YYYY-MM-DD, tang dan. */
export function monthDays(year: number, month: number): string[] {
  const total = daysInMonth(year, month);
  const mm = String(month).padStart(2, "0");
  const days: string[] = [];
  for (let d = 1; d <= total; d += 1) {
    days.push(`${year}-${mm}-${String(d).padStart(2, "0")}`);
  }
  return days;
}

/** Dich thang theo delta (-1 thang truoc, +1 thang sau). */
export function shiftMonth(
  year: number,
  month: number,
  delta: number,
): { year: number; month: number } {
  const total = year * 12 + (month - 1) + delta;
  return {
    year: Math.floor(total / 12),
    month: (total % 12) + 1,
  };
}

/**
 * Thu trong tuan cua ngay YYYY-MM-DD: 0 = Chu nhat, 1 = Thu 2, ...
 * Tinh tren UTC de khong lech theo mui gio may chay.
 */
export function weekdayIndex(dateStr: string): number {
  const match = DATE_RE.exec(dateStr);
  if (!match) {
    return 0;
  }
  const [, y, m, d] = match;
  return new Date(Date.UTC(Number(y), Number(m) - 1, Number(d))).getUTCDay();
}

/** Ngay thang dang YYYY-MM-DD co hop le (dung lich) khong. */
export function isValidBusinessDate(value: string): boolean {
  const match = DATE_RE.exec(value);
  if (!match) {
    return false;
  }
  const [, y, m, d] = match;
  const date = new Date(Date.UTC(Number(y), Number(m) - 1, Number(d)));
  return (
    date.getUTCFullYear() === Number(y) &&
    date.getUTCMonth() === Number(m) - 1 &&
    date.getUTCDate() === Number(d)
  );
}
