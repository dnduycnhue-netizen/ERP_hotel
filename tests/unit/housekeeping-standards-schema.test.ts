import { describe, expect, it } from "vitest";
import { minibarRequestCheckSchema } from "@/features/minibar/schemas";
import {
  roomSetupStandardDeleteSchema,
  roomSetupStandardSaveSchema,
} from "@/features/housekeeping/schemas";

const PROPERTY_ID = "00000000-0000-4000-8000-000000000001";
const ROOM_TYPE_ID = "00000000-0000-4000-8000-000000000002";
const ITEM_ID = "00000000-0000-4000-8000-000000000003";
const STANDARD_ID = "00000000-0000-4000-8000-000000000004";

describe("roomSetupStandardSaveSchema", () => {
  const base = {
    propertyId: PROPERTY_ID,
    roomTypeId: ROOM_TYPE_ID,
    cleanType: "checkout" as const,
    itemId: ITEM_ID,
    qty: 2,
    perGuest: false,
  };

  it("chấp nhận dòng chuẩn hợp lệ", () => {
    expect(roomSetupStandardSaveSchema.safeParse(base).success).toBe(true);
  });

  it("mặc định perGuest = false khi không truyền", () => {
    const { perGuest, ...withoutFlag } = base;
    void perGuest;
    const parsed = roomSetupStandardSaveSchema.safeParse(withoutFlag);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.perGuest).toBe(false);
    }
  });

  it("chấp nhận qty = 0 (định mức 0 = không cấp món đó)", () => {
    expect(
      roomSetupStandardSaveSchema.safeParse({ ...base, qty: 0 }).success,
    ).toBe(true);
  });

  it("chặn qty âm", () => {
    expect(
      roomSetupStandardSaveSchema.safeParse({ ...base, qty: -1 }).success,
    ).toBe(false);
  });

  it("chặn cleanType ngoài 4 loại dọn của M07", () => {
    expect(
      roomSetupStandardSaveSchema.safeParse({ ...base, cleanType: "deep" })
        .success,
    ).toBe(false);
  });

  it("chặn uuid không hợp lệ", () => {
    expect(
      roomSetupStandardSaveSchema.safeParse({
        ...base,
        itemId: "khong-phai-uuid",
      }).success,
    ).toBe(false);
  });
});

describe("roomSetupStandardDeleteSchema", () => {
  it("chấp nhận id hợp lệ", () => {
    expect(
      roomSetupStandardDeleteSchema.safeParse({
        propertyId: PROPERTY_ID,
        standardId: STANDARD_ID,
      }).success,
    ).toBe(true);
  });

  it("chặn standardId không phải uuid", () => {
    expect(
      roomSetupStandardDeleteSchema.safeParse({
        propertyId: PROPERTY_ID,
        standardId: "khong-phai-uuid",
      }).success,
    ).toBe(false);
  });
});

describe("minibarRequestCheckSchema (trigger — C7)", () => {
  const base = {
    propertyId: PROPERTY_ID,
    roomId: "00000000-0000-4000-8000-000000000005",
  };

  it("mặc định trigger = checkout khi không truyền (tương thích ngược)", () => {
    const parsed = minibarRequestCheckSchema.safeParse(base);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.trigger).toBe("checkout");
    }
  });

  it("chấp nhận trigger audit và daily (kiểm đột xuất / kiểm định kỳ)", () => {
    expect(
      minibarRequestCheckSchema.safeParse({ ...base, trigger: "audit" })
        .success,
    ).toBe(true);
    expect(
      minibarRequestCheckSchema.safeParse({ ...base, trigger: "daily" })
        .success,
    ).toBe(true);
  });

  it("chặn trigger ngoài 3 loại của bảng minibar_checks", () => {
    expect(
      minibarRequestCheckSchema.safeParse({ ...base, trigger: "weekly" })
        .success,
    ).toBe(false);
  });
});
