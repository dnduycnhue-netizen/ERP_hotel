import { describe, expect, it } from "vitest";

import { pmsDailyUpsertSchema } from "@/features/pms-daily/schemas";
import { vi } from "@/i18n/vi";

const base = {
  propertyId: "11111111-1111-4111-8111-111111111111",
  businessDate: "2026-11-12",
  roomsAvailable: 50,
  roomsSold: 40,
  guests: 70,
  breakfastPax: 60,
  extraBeds: 2,
  checkouts: 30,
};

function firstMessage(input: unknown): string | undefined {
  const result = pmsDailyUpsertSchema.safeParse(input);
  return result.success ? undefined : result.error.issues[0]?.message;
}

describe("schema số liệu PMS ngày: câu báo lỗi lấy từ vi.ts", () => {
  it("số thập phân bị từ chối với nhãn trường", () => {
    expect(firstMessage({ ...base, guests: 1.5 })).toBe(
      vi.pmsDaily.validation.integer.replace("{label}", vi.pmsDaily.fields.guests),
    );
  });

  it("số âm bị từ chối với nhãn trường", () => {
    expect(firstMessage({ ...base, roomsSold: -1 })).toBe(
      vi.pmsDaily.validation.nonNegative.replace(
        "{label}",
        vi.pmsDaily.fields.roomsSold,
      ),
    );
  });

  it("không còn placeholder {label} trong câu hiển thị", () => {
    expect(firstMessage({ ...base, guests: 1.5 })).not.toContain("{label}");
  });
});
