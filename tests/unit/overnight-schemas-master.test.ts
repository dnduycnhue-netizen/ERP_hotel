import { describe, expect, it } from "vitest";

import {
  ceilingPriceSaveSchema,
  itemGroupSaveSchema,
  itemMergeSchema,
  itemSaveSchema,
  priceAgreementLineSaveSchema,
  priceAgreementSaveSchema,
  roomSaveSchema,
  supplierSaveSchema,
  tempItemCreateSchema,
  uomSaveSchema,
  warehouseSaveSchema,
} from "@/features/master/schemas";

const UUID_A = "00000000-0000-4000-8000-000000000001";
const UUID_B = "00000000-0000-4000-8000-000000000002";
const UUID_C = "00000000-0000-4000-8000-000000000003";

describe("itemSaveSchema", () => {
  const valid = {
    propertyId: UUID_A,
    code: "NVL0388",
    name: "Ba chỉ nách",
    groupId: UUID_B,
    stockUom: "kg",
    allowedChannels: ["contract"],
  };

  it("chấp nhận vật tư hợp lệ, gán mặc định isKeyItem=false, status=active", () => {
    const parsed = itemSaveSchema.safeParse(valid);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.isKeyItem).toBe(false);
      expect(parsed.data.status).toBe("active");
    }
  });

  it("từ chối mã có khoảng trắng/ký tự lạ và mã quá 50 ký tự", () => {
    expect(
      itemSaveSchema.safeParse({ ...valid, code: "NVL 0388" }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, code: "NVL/0388" }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, code: "X".repeat(51) }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, code: "NVL-0388_A" }).success,
    ).toBe(true);
  });

  it("từ chối tên trống/tên quá 200 ký tự và kênh trống", () => {
    expect(itemSaveSchema.safeParse({ ...valid, name: "" }).success).toBe(
      false,
    );
    expect(
      itemSaveSchema.safeParse({ ...valid, name: "x".repeat(201) }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, allowedChannels: [] }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, allowedChannels: ["online"] })
        .success,
    ).toBe(false);
  });

  it("hệ số quy đổi phải dương, VAT 0–100, hạng ABC chỉ A/B/C", () => {
    expect(
      itemSaveSchema.safeParse({ ...valid, stockToRecipe: 0 }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, stockToRecipe: -1 }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, vatRate: 101 }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, vatRate: 100 }).success,
    ).toBe(true);
    expect(
      itemSaveSchema.safeParse({ ...valid, abcClass: "D" }).success,
    ).toBe(false);
    expect(
      itemSaveSchema.safeParse({ ...valid, abcClass: "A" }).success,
    ).toBe(true);
  });
});

describe("uomSaveSchema", () => {
  it("mã ĐVT phải bắt đầu bằng chữ thường, chỉ chứa chữ thường/số/gạch dưới", () => {
    expect(uomSaveSchema.safeParse({ code: "kg", nameVi: "Ki-lô-gam" }).success).toBe(true);
    expect(uomSaveSchema.safeParse({ code: "KG", nameVi: "Ki-lô-gam" }).success).toBe(false);
    expect(uomSaveSchema.safeParse({ code: "1kg", nameVi: "Ki-lô-gam" }).success).toBe(false);
    expect(uomSaveSchema.safeParse({ code: "kg m", nameVi: "Ki-lô-gam" }).success).toBe(false);
    expect(uomSaveSchema.safeParse({ code: "cai", nameVi: "Cái" }).success).toBe(true);
  });

  it("từ chối tên hiển thị trống hoặc quá 50 ký tự", () => {
    expect(uomSaveSchema.safeParse({ code: "kg", nameVi: "" }).success).toBe(false);
    expect(
      uomSaveSchema.safeParse({ code: "kg", nameVi: "x".repeat(51) }).success,
    ).toBe(false);
  });
});

describe("itemGroupSaveSchema", () => {
  it("chấp nhận nhóm hợp lệ; từ chối kind ngoài danh mục và tiền tố mã sai", () => {
    const valid = {
      propertyId: UUID_A,
      codePrefix: "TP",
      name: "Thực phẩm",
      kind: "food",
    };
    expect(itemGroupSaveSchema.safeParse(valid).success).toBe(true);
    expect(
      itemGroupSaveSchema.safeParse({ ...valid, kind: "unknown" }).success,
    ).toBe(false);
    expect(
      itemGroupSaveSchema.safeParse({ ...valid, codePrefix: "TP 1" }).success,
    ).toBe(false);
    expect(
      itemGroupSaveSchema.safeParse({ ...valid, codePrefix: "X".repeat(21) })
        .success,
    ).toBe(false);
  });
});

describe("supplierSaveSchema", () => {
  it("chấp nhận NCC hợp lệ; từ chối loại sai, mã sai, số ngày thanh toán âm", () => {
    const valid = {
      propertyId: UUID_A,
      code: "NCC-T047",
      name: "Nhà cung cấp T047",
      kind: "company",
    };
    expect(supplierSaveSchema.safeParse(valid).success).toBe(true);
    expect(
      supplierSaveSchema.safeParse({ ...valid, kind: "agency" }).success,
    ).toBe(false);
    expect(
      supplierSaveSchema.safeParse({ ...valid, code: "NCC T047" }).success,
    ).toBe(false);
    expect(
      supplierSaveSchema.safeParse({ ...valid, paymentTermsDays: -1 }).success,
    ).toBe(false);
    expect(
      supplierSaveSchema.safeParse({ ...valid, paymentTermsDays: 0 }).success,
    ).toBe(true);
  });
});

describe("priceAgreementSaveSchema / priceAgreementLineSaveSchema", () => {
  it("từ chối ngày kết thúc trước ngày bắt đầu; chấp nhận bằng nhau", () => {
    const base = {
      propertyId: UUID_A,
      supplierId: UUID_B,
      validFrom: "2026-01-01",
      validTo: "2026-12-31",
    };
    expect(priceAgreementSaveSchema.safeParse(base).success).toBe(true);
    expect(
      priceAgreementSaveSchema.safeParse({
        ...base,
        validTo: "2025-12-31",
      }).success,
    ).toBe(false);
    expect(
      priceAgreementSaveSchema.safeParse({
        ...base,
        validTo: "2026-01-01",
      }).success,
    ).toBe(true);
  });

  it("dòng hợp đồng: đơn giá âm thì từ chối, 0 thì chấp nhận; warn/lock 0–100", () => {
    const base = {
      propertyId: UUID_A,
      agreementId: UUID_B,
      itemId: UUID_C,
      uom: "kg",
      unitPrice: 100000,
    };
    expect(priceAgreementLineSaveSchema.safeParse(base).success).toBe(true);
    expect(
      priceAgreementLineSaveSchema.safeParse({ ...base, unitPrice: -1 })
        .success,
    ).toBe(false);
    expect(
      priceAgreementLineSaveSchema.safeParse({ ...base, unitPrice: 0 })
        .success,
    ).toBe(true);
    expect(
      priceAgreementLineSaveSchema.safeParse({ ...base, warnPct: 101 })
        .success,
    ).toBe(false);
    expect(
      priceAgreementLineSaveSchema.safeParse({ ...base, lockPct: 100 })
        .success,
    ).toBe(true);
  });
});

describe("ceilingPriceSaveSchema", () => {
  it("từ chối giá trần âm và khoảng ngày ngược", () => {
    const base = {
      propertyId: UUID_A,
      itemId: UUID_B,
      uom: "kg",
      price: 100000,
      validFrom: "2026-01-01",
      validTo: "2026-12-31",
    };
    expect(ceilingPriceSaveSchema.safeParse(base).success).toBe(true);
    expect(
      ceilingPriceSaveSchema.safeParse({ ...base, price: -1 }).success,
    ).toBe(false);
    expect(
      ceilingPriceSaveSchema.safeParse({ ...base, price: 0 }).success,
    ).toBe(true);
    expect(
      ceilingPriceSaveSchema.safeParse({ ...base, validTo: "2025-12-31" })
        .success,
    ).toBe(false);
  });
});

describe("tempItemCreateSchema / itemMergeSchema", () => {
  it("từ chối mã tạm thiếu tên hoặc thiếu nhóm/ĐVT", () => {
    expect(
      tempItemCreateSchema.safeParse({
        propertyId: UUID_A,
        name: "",
        groupId: UUID_B,
        stockUom: "kg",
      }).success,
    ).toBe(false);
    expect(
      tempItemCreateSchema.safeParse({
        propertyId: UUID_A,
        name: "Món tạm",
        groupId: UUID_B,
        stockUom: "kg",
      }).success,
    ).toBe(true);
  });

  it("gộp mã: từ chối UUID sai", () => {
    expect(
      itemMergeSchema.safeParse({
        propertyId: UUID_A,
        fromId: UUID_B,
        intoId: UUID_C,
      }).success,
    ).toBe(true);
    expect(
      itemMergeSchema.safeParse({
        propertyId: UUID_A,
        fromId: "x",
        intoId: UUID_C,
      }).success,
    ).toBe(false);
  });
});

describe("roomSaveSchema / warehouseSaveSchema", () => {
  it("từ chối số phòng trống/quá 20 ký tự; chấp nhận phòng hợp lệ", () => {
    expect(
      roomSaveSchema.safeParse({
        propertyId: UUID_A,
        roomNo: "",
        roomTypeId: UUID_B,
      }).success,
    ).toBe(false);
    expect(
      roomSaveSchema.safeParse({
        propertyId: UUID_A,
        roomNo: "1".repeat(21),
        roomTypeId: UUID_B,
      }).success,
    ).toBe(false);
    expect(
      roomSaveSchema.safeParse({
        propertyId: UUID_A,
        roomNo: "101",
        roomTypeId: UUID_B,
      }).success,
    ).toBe(true);
  });

  it("từ chối loại kho ngoài danh mục", () => {
    const base = {
      propertyId: UUID_A,
      code: "KHO-T047",
      name: "Kho chính",
      kind: "main",
    };
    expect(warehouseSaveSchema.safeParse(base).success).toBe(true);
    expect(
      warehouseSaveSchema.safeParse({ ...base, kind: "phong" }).success,
    ).toBe(false);
    expect(
      warehouseSaveSchema.safeParse({ ...base, kind: "minibar_main" })
        .success,
    ).toBe(true);
  });
});
