import { describe, expect, it } from "vitest";
import {
  daysInMonth,
  isValidBusinessDate,
  isValidYearMonth,
  monthDays,
  monthRange,
  shiftMonth,
  todayInVietnam,
  weekdayIndex,
} from "@/features/locks/date-utils";

describe("todayInVietnam", () => {
  it("trả về ngày VN, không phải ngày UTC", () => {
    // 2026-11-10 00:30 UTC vẫn là 2026-11-10 ở VN (UTC+7).
    expect(todayInVietnam(new Date("2026-11-10T00:30:00Z"))).toBe("2026-11-10");
    // 2026-11-09 17:30 UTC đã là 2026-11-10 00:30 ở VN.
    expect(todayInVietnam(new Date("2026-11-09T17:30:00Z"))).toBe("2026-11-10");
  });
});

describe("isValidYearMonth", () => {
  it("chấp nhận tháng 1-12, năm 1-9999", () => {
    expect(isValidYearMonth(2026, 11)).toBe(true);
    expect(isValidYearMonth(2026, 1)).toBe(true);
    expect(isValidYearMonth(2026, 12)).toBe(true);
  });

  it("từ chối tháng 0/13, năm 0/10000 và số không nguyên", () => {
    expect(isValidYearMonth(2026, 0)).toBe(false);
    expect(isValidYearMonth(2026, 13)).toBe(false);
    expect(isValidYearMonth(0, 11)).toBe(false);
    expect(isValidYearMonth(10000, 11)).toBe(false);
    expect(isValidYearMonth(2026.5, 11)).toBe(false);
  });
});

describe("daysInMonth / monthRange / monthDays", () => {
  it("tháng 11 có 30 ngày, tháng 2 năm nhuận 2028 có 29 ngày", () => {
    expect(daysInMonth(2026, 11)).toBe(30);
    expect(daysInMonth(2028, 2)).toBe(29);
    expect(daysInMonth(2027, 2)).toBe(28);
  });

  it("monthRange trả về ngày đầu/cuối đúng", () => {
    expect(monthRange(2026, 11)).toEqual({
      first: "2026-11-01",
      last: "2026-11-30",
    });
    expect(monthRange(2026, 1)).toEqual({
      first: "2026-01-01",
      last: "2026-01-31",
    });
  });

  it("monthDays liệt kê đủ ngày, tăng dần, dạng YYYY-MM-DD", () => {
    const days = monthDays(2026, 11);
    expect(days).toHaveLength(30);
    expect(days[0]).toBe("2026-11-01");
    expect(days[29]).toBe("2026-11-30");
  });
});

describe("shiftMonth", () => {
  it("qua tháng và qua năm đúng", () => {
    expect(shiftMonth(2026, 11, 1)).toEqual({ year: 2026, month: 12 });
    expect(shiftMonth(2026, 12, 1)).toEqual({ year: 2027, month: 1 });
    expect(shiftMonth(2026, 1, -1)).toEqual({ year: 2025, month: 12 });
    expect(shiftMonth(2026, 11, -11)).toEqual({ year: 2025, month: 12 });
  });
});

describe("weekdayIndex", () => {
  it("2026-11-09 là Thứ 2 (1), 2026-11-08 là Chủ nhật (0)", () => {
    expect(weekdayIndex("2026-11-09")).toBe(1);
    expect(weekdayIndex("2026-11-08")).toBe(0);
    expect(weekdayIndex("2026-11-14")).toBe(6);
  });

  it("chuỗi sai định dạng trả về 0", () => {
    expect(weekdayIndex("không phải ngày")).toBe(0);
  });
});

describe("isValidBusinessDate", () => {
  it("chấp nhận ngày có thật, từ chối ngày không tồn tại", () => {
    expect(isValidBusinessDate("2026-11-30")).toBe(true);
    expect(isValidBusinessDate("2026-02-29")).toBe(false);
    expect(isValidBusinessDate("2028-02-29")).toBe(true);
    expect(isValidBusinessDate("2026-13-01")).toBe(false);
    expect(isValidBusinessDate("09/11/2026")).toBe(false);
  });
});
