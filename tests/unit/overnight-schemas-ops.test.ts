import { describe, expect, it } from "vitest";

import { changePasswordSchema } from "@/features/account/schemas";
import { attachmentRegisterSchema } from "@/features/attachments/schemas";
import {
  docListSchema,
  stockCardSchema,
  stockListSchema,
} from "@/features/inventory/schemas";
import {
  dayLockSchema,
  dayUnlockSchema,
  periodCloseCheckSchema,
  periodCloseSchema,
  periodReopenSchema,
} from "@/features/locks/schemas";
import {
  minibarConfirmChargeSchema,
  minibarRequestCheckSchema,
  minibarSubmitCheckSchema,
  minibarSubmitLineSchema,
} from "@/features/minibar/schemas";
import {
  poSetEstimatedTotalSchema,
  prDecideSchema,
  prSubmitSchema,
} from "@/features/procurement/schemas";
import {
  reportCodeSchema,
  reportParamsSchema,
} from "@/features/report/schemas";
import { contractSaveSchema } from "@/features/service/schemas";
import {
  trolleyCountItemSchema,
  trolleyRoomsDoneItemSchema,
  trolleyShiftSchema,
} from "@/features/trolley/schemas";

const UUID_A = "00000000-0000-4000-8000-000000000001";
const UUID_B = "00000000-0000-4000-8000-000000000002";
const UUID_C = "00000000-0000-4000-8000-000000000003";

describe("docListSchema / stockListSchema", () => {
  it("mặc định limit=20, offset=0; giới hạn 1–100", () => {
    const parsed = docListSchema.safeParse({ propertyId: UUID_A });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.limit).toBe(20);
      expect(parsed.data.offset).toBe(0);
    }
    expect(docListSchema.safeParse({ propertyId: UUID_A, limit: 0 }).success).toBe(false);
    expect(docListSchema.safeParse({ propertyId: UUID_A, limit: 101 }).success).toBe(false);
    expect(docListSchema.safeParse({ propertyId: UUID_A, limit: 100 }).success).toBe(true);
    expect(docListSchema.safeParse({ propertyId: UUID_A, limit: 1.5 }).success).toBe(false);
    expect(docListSchema.safeParse({ propertyId: UUID_A, offset: -1 }).success).toBe(false);
  });

  it("stockListSchema chấp nhận lọc theo kho, từ chối limit ngoài khoảng", () => {
    expect(
      stockListSchema.safeParse({ propertyId: UUID_A, warehouseId: UUID_B })
        .success,
    ).toBe(true);
    expect(
      stockListSchema.safeParse({ propertyId: UUID_A, warehouseId: null })
        .success,
    ).toBe(true);
    expect(
      stockListSchema.safeParse({ propertyId: UUID_A, limit: 0 }).success,
    ).toBe(false);
  });
});

describe("stockCardSchema", () => {
  it("chấp nhận thẻ kho không lọc ngày; từ chối ngày sai định dạng", () => {
    expect(
      stockCardSchema.safeParse({
        propertyId: UUID_A,
        warehouseId: UUID_B,
        itemId: UUID_C,
      }).success,
    ).toBe(true);
    expect(
      stockCardSchema.safeParse({
        propertyId: UUID_A,
        warehouseId: UUID_B,
        itemId: UUID_C,
        from: "01/11/2026",
      }).success,
    ).toBe(false);
    expect(
      stockCardSchema.safeParse({
        propertyId: UUID_A,
        warehouseId: UUID_B,
        itemId: UUID_C,
        from: "2026-11-01",
        to: "2026-11-30",
      }).success,
    ).toBe(true);
  });
});

describe("locks schemas", () => {
  it("dayLockSchema: ngày nghiệp vụ phải đúng yyyy-mm-dd; ca tối đa 50 ký tự", () => {
    expect(
      dayLockSchema.safeParse({
        propertyId: UUID_A,
        warehouseId: UUID_B,
        businessDate: "2026-11-13",
      }).success,
    ).toBe(true);
    expect(
      dayLockSchema.safeParse({
        propertyId: UUID_A,
        warehouseId: UUID_B,
        businessDate: "13/11/2026",
      }).success,
    ).toBe(false);
    expect(
      dayLockSchema.safeParse({
        propertyId: UUID_A,
        warehouseId: UUID_B,
        businessDate: "2026-11-13",
        shift: "x".repeat(51),
      }).success,
    ).toBe(false);
  });

  it("dayUnlockSchema / periodReopenSchema: bắt buộc lý do, tối đa 500 ký tự", () => {
    expect(
      dayUnlockSchema.safeParse({
        propertyId: UUID_A,
        lockId: UUID_A,
        reason: "",
      }).success,
    ).toBe(false);
    expect(
      dayUnlockSchema.safeParse({
        propertyId: UUID_A,
        lockId: UUID_A,
        reason: "Khóa nhầm ngày",
      }).success,
    ).toBe(true);
    expect(
      dayUnlockSchema.safeParse({
        propertyId: UUID_A,
        lockId: UUID_A,
        reason: "x".repeat(501),
      }).success,
    ).toBe(false);
    expect(
      periodReopenSchema.safeParse({
        propertyId: UUID_A,
        periodId: UUID_B,
        reason: "Sai số liệu",
      }).success,
    ).toBe(true);
  });

  it("periodCloseCheckSchema / periodCloseSchema: tháng 1–12, năm 1–9999, nguyên", () => {
    expect(
      periodCloseCheckSchema.safeParse({ entityId: UUID_A, year: 2026, month: 11 })
        .success,
    ).toBe(true);
    expect(
      periodCloseCheckSchema.safeParse({ entityId: UUID_A, year: 2026, month: 0 })
        .success,
    ).toBe(false);
    expect(
      periodCloseCheckSchema.safeParse({ entityId: UUID_A, year: 2026, month: 13 })
        .success,
    ).toBe(false);
    expect(
      periodCloseCheckSchema.safeParse({ entityId: UUID_A, year: 0, month: 11 })
        .success,
    ).toBe(false);
    expect(
      periodCloseCheckSchema.safeParse({ entityId: UUID_A, year: 10000, month: 11 })
        .success,
    ).toBe(false);
    expect(
      periodCloseCheckSchema.safeParse({ entityId: UUID_A, year: 2026.5, month: 11 })
        .success,
    ).toBe(false);
    expect(
      periodCloseSchema.safeParse({
        propertyId: UUID_A,
        entityId: UUID_B,
        year: 2026,
        month: 12,
      }).success,
    ).toBe(true);
  });
});

describe("minibar schemas", () => {
  it("minibarSubmitLineSchema: số lượng thiếu phải dương", () => {
    expect(
      minibarSubmitLineSchema.safeParse({ itemId: UUID_A, missingQty: 1 })
        .success,
    ).toBe(true);
    expect(
      minibarSubmitLineSchema.safeParse({ itemId: UUID_A, missingQty: 0 })
        .success,
    ).toBe(false);
    expect(
      minibarSubmitLineSchema.safeParse({ itemId: UUID_A, missingQty: -1 })
        .success,
    ).toBe(false);
  });

  it("minibarSubmitCheckSchema: cho phép 0 dòng (phòng không dùng món nào, B-39)", () => {
    expect(
      minibarSubmitCheckSchema.safeParse({
        propertyId: UUID_A,
        checkId: UUID_B,
        lines: [],
        clientUuid: UUID_C,
      }).success,
    ).toBe(true);
    expect(
      minibarSubmitCheckSchema.safeParse({
        propertyId: UUID_A,
        checkId: UUID_B,
        lines: [{ itemId: UUID_C, missingQty: 2 }],
        clientUuid: UUID_C,
      }).success,
    ).toBe(true);
  });

  it("minibarConfirmChargeSchema: bắt buộc số folio, từ chối khoảng trắng", () => {
    expect(
      minibarConfirmChargeSchema.safeParse({
        propertyId: UUID_A,
        checkId: UUID_B,
        folioNo: "F-101",
      }).success,
    ).toBe(true);
    expect(
      minibarConfirmChargeSchema.safeParse({
        propertyId: UUID_A,
        checkId: UUID_B,
        folioNo: "   ",
      }).success,
    ).toBe(false);
  });

  it("minibarRequestCheckSchema: mặc định trigger checkout, từ chối trigger lạ", () => {
    const parsed = minibarRequestCheckSchema.safeParse({
      propertyId: UUID_A,
      roomId: UUID_B,
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.trigger).toBe("checkout");
    }
    expect(
      minibarRequestCheckSchema.safeParse({
        propertyId: UUID_A,
        roomId: UUID_B,
        trigger: "weekly",
      }).success,
    ).toBe(false);
  });
});

describe("trolley schemas", () => {
  it("trolleyShiftSchema chỉ chấp nhận day/morning/evening", () => {
    expect(trolleyShiftSchema.safeParse("day").success).toBe(true);
    expect(trolleyShiftSchema.safeParse("morning").success).toBe(true);
    expect(trolleyShiftSchema.safeParse("evening").success).toBe(true);
    expect(trolleyShiftSchema.safeParse("night").success).toBe(false);
  });

  it("trolleyCountItemSchema: số lượng 0 hợp lệ, âm thì không", () => {
    expect(
      trolleyCountItemSchema.safeParse({ itemId: UUID_A, qty: 0 }).success,
    ).toBe(true);
    expect(
      trolleyCountItemSchema.safeParse({ itemId: UUID_A, qty: -0.5 }).success,
    ).toBe(false);
  });

  it("trolleyRoomsDoneItemSchema: loại dọn phải trong danh mục, số khách không âm", () => {
    expect(
      trolleyRoomsDoneItemSchema.safeParse({
        roomId: UUID_A,
        cleanType: "checkout",
        guests: 2,
      }).success,
    ).toBe(true);
    expect(
      trolleyRoomsDoneItemSchema.safeParse({
        roomId: UUID_A,
        cleanType: "deep",
      }).success,
    ).toBe(false);
    expect(
      trolleyRoomsDoneItemSchema.safeParse({
        roomId: UUID_A,
        cleanType: "stayover",
        guests: -1,
      }).success,
    ).toBe(false);
  });
});

describe("service contractSaveSchema", () => {
  it("từ chối tên trống, tiền mỗi kỳ âm, ngày nhắc tái ký âm; chấp nhận hợp lệ", () => {
    const valid = {
      propertyId: UUID_A,
      title: "Vệ sinh máy lạnh",
      supplierId: UUID_B,
      expenseCategoryId: UUID_C,
      costCenterId: UUID_A,
      startDate: "2026-01-01",
      billingCycle: "monthly",
      amountPerCycle: 1500000,
    };
    expect(contractSaveSchema.safeParse(valid).success).toBe(true);
    expect(
      contractSaveSchema.safeParse({ ...valid, title: "" }).success,
    ).toBe(false);
    expect(
      contractSaveSchema.safeParse({ ...valid, amountPerCycle: -1 }).success,
    ).toBe(false);
    expect(
      contractSaveSchema.safeParse({ ...valid, renewNoticeDays: -1 }).success,
    ).toBe(false);
    expect(
      contractSaveSchema.safeParse({ ...valid, billingCycle: "weekly" })
        .success,
    ).toBe(false);
    const parsed = contractSaveSchema.safeParse(valid);
    if (parsed.success) {
      expect(parsed.data.renewNoticeDays).toBe(30);
      expect(parsed.data.status).toBe("active");
    }
  });
});

describe("report schemas", () => {
  it("reportCodeSchema chấp nhận mã có thật, từ chối mã lạ", () => {
    expect(reportCodeSchema.safeParse("RPT_DAILY_BRIEF").success).toBe(true);
    expect(reportCodeSchema.safeParse("RPT_STOCK_CARD").success).toBe(true);
    expect(reportCodeSchema.safeParse("RPT_KHONG_TON_TAI").success).toBe(false);
  });

  it("reportParamsSchema: từ ngày không được sau đến ngày; định dạng ngày/tháng", () => {
    expect(
      reportParamsSchema.safeParse({ from: "2026-11-01", to: "2026-11-30" })
        .success,
    ).toBe(true);
    expect(
      reportParamsSchema.safeParse({ from: "2026-11-30", to: "2026-11-01" })
        .success,
    ).toBe(false);
    expect(
      reportParamsSchema.safeParse({ from: "2026-11-01", to: "2026-11-01" })
        .success,
    ).toBe(true);
    expect(
      reportParamsSchema.safeParse({ from: "01/11/2026" }).success,
    ).toBe(false);
    expect(
      reportParamsSchema.safeParse({ month: "11/2026" }).success,
    ).toBe(false);
    expect(reportParamsSchema.safeParse({ month: "2026-11" }).success).toBe(
      true,
    );
    expect(reportParamsSchema.safeParse({}).success).toBe(true);
  });
});

describe("changePasswordSchema", () => {
  const base = {
    currentPassword: "MatKhauCu123",
    newPassword: "MatKhauMoi456",
    confirmPassword: "MatKhauMoi456",
  };

  it("chấp nhận đổi mật khẩu hợp lệ (mới ≥12 ký tự, khác cũ, khớp xác nhận)", () => {
    expect(changePasswordSchema.safeParse(base).success).toBe(true);
  });

  it("từ chối mật khẩu mới dưới 12 ký tự và quá 128 ký tự", () => {
    expect(
      changePasswordSchema.safeParse({
        ...base,
        newPassword: "Ngan1234567",
        confirmPassword: "Ngan1234567",
      }).success,
    ).toBe(false);
    expect(
      changePasswordSchema.safeParse({
        ...base,
        newPassword: "x".repeat(129),
        confirmPassword: "x".repeat(129),
      }).success,
    ).toBe(false);
  });

  it("từ chối khi xác nhận không khớp và khi mật khẩu mới trùng mật khẩu cũ", () => {
    expect(
      changePasswordSchema.safeParse({
        ...base,
        confirmPassword: "MatKhauKhac789",
      }).success,
    ).toBe(false);
    expect(
      changePasswordSchema.safeParse({
        ...base,
        newPassword: "MatKhauCu123",
        confirmPassword: "MatKhauCu123",
      }).success,
    ).toBe(false);
  });
});

describe("attachmentRegisterSchema", () => {
  it("từ chối bucket ngoài evidence/attachments và đường dẫn trống/quá 500 ký tự", () => {
    const valid = {
      propertyId: UUID_A,
      bucket: "evidence",
      path: "gr/2026-11-13/anh.jpg",
      sha256: "a".repeat(64),
      docType: "grn",
      docId: UUID_B,
    };
    expect(attachmentRegisterSchema.safeParse(valid).success).toBe(true);
    expect(
      attachmentRegisterSchema.safeParse({ ...valid, bucket: "public" })
        .success,
    ).toBe(false);
    expect(
      attachmentRegisterSchema.safeParse({ ...valid, path: "" }).success,
    ).toBe(false);
    expect(
      attachmentRegisterSchema.safeParse({ ...valid, path: "x".repeat(501) })
        .success,
    ).toBe(false);
  });
});

describe("procurement schemas", () => {
  it("poSetEstimatedTotalSchema: ước tính phải dương", () => {
    expect(
      poSetEstimatedTotalSchema.safeParse({
        propertyId: UUID_A,
        poId: UUID_B,
        amount: 500001,
      }).success,
    ).toBe(true);
    expect(
      poSetEstimatedTotalSchema.safeParse({
        propertyId: UUID_A,
        poId: UUID_B,
        amount: 0,
      }).success,
    ).toBe(false);
    expect(
      poSetEstimatedTotalSchema.safeParse({
        propertyId: UUID_A,
        poId: UUID_B,
        amount: -100,
      }).success,
    ).toBe(false);
  });

  it("prSubmitSchema / prDecideSchema: UUID hợp lệ, quyết định chỉ approved/rejected", () => {
    expect(
      prSubmitSchema.safeParse({ propertyId: UUID_A, prId: UUID_B }).success,
    ).toBe(true);
    expect(
      prDecideSchema.safeParse({
        propertyId: UUID_A,
        prId: UUID_B,
        decision: "approved",
      }).success,
    ).toBe(true);
    expect(
      prDecideSchema.safeParse({
        propertyId: UUID_A,
        prId: UUID_B,
        decision: "pending",
      }).success,
    ).toBe(false);
  });
});
