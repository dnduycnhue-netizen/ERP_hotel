import { describe, expect, it } from "vitest";
import {
  photoReviewListSchema,
  photoReviewSchema,
} from "@/features/receiving/schemas";

const GR_ID = "00000000-0000-4000-8000-000000000001";
const PROPERTY_ID = "00000000-0000-4000-8000-000000000002";

describe("photoReviewListSchema", () => {
  it("chấp nhận lọc trống (mặc định limit 20, offset 0)", () => {
    const parsed = photoReviewListSchema.safeParse({
      propertyId: PROPERTY_ID,
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.limit).toBe(20);
      expect(parsed.data.offset).toBe(0);
      expect(parsed.data.reviewStatus).toBeUndefined();
    }
  });

  it("chấp nhận lọc theo từng trạng thái hậu kiểm", () => {
    for (const reviewStatus of ["pending", "approved", "rejected"] as const) {
      expect(
        photoReviewListSchema.safeParse({
          propertyId: PROPERTY_ID,
          reviewStatus,
        }).success,
      ).toBe(true);
    }
  });

  it("chặn trạng thái hậu kiểm ngoài danh mục", () => {
    expect(
      photoReviewListSchema.safeParse({
        propertyId: PROPERTY_ID,
        reviewStatus: "done",
      }).success,
    ).toBe(false);
  });

  it("chặn propertyId không phải uuid", () => {
    expect(
      photoReviewListSchema.safeParse({ propertyId: "not-a-uuid" }).success,
    ).toBe(false);
  });
});

describe("photoReviewSchema", () => {
  it("chấp nhận duyệt ảnh không cần lý do", () => {
    expect(
      photoReviewSchema.safeParse({ grId: GR_ID, decision: "approved" })
        .success,
    ).toBe(true);
  });

  it("chấp nhận từ chối ảnh khi có lý do", () => {
    expect(
      photoReviewSchema.safeParse({
        grId: GR_ID,
        decision: "rejected",
        reason: "Ảnh mờ, không đọc được hạn dùng.",
      }).success,
    ).toBe(true);
  });

  it("chặn từ chối ảnh không có lý do", () => {
    expect(
      photoReviewSchema.safeParse({ grId: GR_ID, decision: "rejected" })
        .success,
    ).toBe(false);
  });

  it("chặn từ chối ảnh với lý do chỉ có khoảng trắng", () => {
    expect(
      photoReviewSchema.safeParse({
        grId: GR_ID,
        decision: "rejected",
        reason: "   ",
      }).success,
    ).toBe(false);
  });

  it("chặn quyết định ngoài duyệt/từ chối", () => {
    expect(
      photoReviewSchema.safeParse({ grId: GR_ID, decision: "maybe" }).success,
    ).toBe(false);
  });
});
