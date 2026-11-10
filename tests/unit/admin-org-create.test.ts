import { describe, expect, it } from "vitest";
import {
  QUICK_ASSIGN_ROLE_CODES,
  filterQuickAssignRoles,
} from "../../src/features/admin/org";
import { createOrgSchema } from "../../src/features/admin/schemas";

/**
 * C5 — tạo tổ chức / pháp nhân / khách sạn: schema Zod dùng chung
 * client/server (createOrgSchema) và bộ lọc vai trò của wizard gán nhanh
 * (06 §6.4: gợi ý bộ vai trò mẫu theo hồ sơ có/không Cost Controller).
 */
describe("createOrgSchema — tạo tổ chức trong 1 lần", () => {
  const base = {
    orgName: "Tập đoàn Kiểm thử",
    legalCode: "TESTLE",
    legalName: "Công ty Kiểm thử",
    taxCode: "",
    accountingRegime: "TT99",
    costingMethod: "moving_avg",
    propertyCode: "TESTHT",
    propertyName: "Khách sạn Kiểm thử",
    address: "",
    sodProfile: "with_cc",
    roomsCount: 120,
  };

  it("đủ trường hợp lệ thì parse được", () => {
    const parsed = createOrgSchema.safeParse(base);
    expect(parsed.success).toBe(true);
  });

  it("mã chữ thường được chuẩn hóa thành chữ hoa", () => {
    const parsed = createOrgSchema.safeParse({
      ...base,
      legalCode: "testle",
      propertyCode: "testht",
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.legalCode).toBe("TESTLE");
      expect(parsed.data.propertyCode).toBe("TESTHT");
    }
  });

  it("thiếu tên tổ chức thì lỗi", () => {
    expect(createOrgSchema.safeParse({ ...base, orgName: "  " }).success).toBe(
      false,
    );
  });

  it("mã pháp nhân sai định dạng thì lỗi", () => {
    expect(createOrgSchema.safeParse({ ...base, legalCode: "x" }).success).toBe(
      false,
    );
    expect(
      createOrgSchema.safeParse({ ...base, legalCode: "CÓ DẤU" }).success,
    ).toBe(false);
  });

  it("costing_method ngoài moving_avg/fifo thì lỗi", () => {
    expect(
      createOrgSchema.safeParse({ ...base, costingMethod: "lifo" }).success,
    ).toBe(false);
  });

  it("sod_profile ngoài with_cc/without_cc thì lỗi", () => {
    expect(
      createOrgSchema.safeParse({ ...base, sodProfile: "with_gm" }).success,
    ).toBe(false);
  });

  it("số phòng âm thì lỗi, bỏ trống thì mặc định 0", () => {
    expect(createOrgSchema.safeParse({ ...base, roomsCount: -1 }).success).toBe(
      false,
    );
    const { roomsCount, ...withoutRooms } = base;
    void roomsCount;
    const parsed = createOrgSchema.safeParse(withoutRooms);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.roomsCount).toBe(0);
    }
  });

  it("bỏ trống các trường tùy chọn thì mặc định TT99/moving_avg/with_cc", () => {
    const { accountingRegime, costingMethod, sodProfile, ...minimal } = base;
    void accountingRegime;
    void costingMethod;
    void sodProfile;
    const parsed = createOrgSchema.safeParse(minimal);
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.accountingRegime).toBe("TT99");
      expect(parsed.data.costingMethod).toBe("moving_avg");
      expect(parsed.data.sodProfile).toBe("with_cc");
    }
  });
});

describe("filterQuickAssignRoles — wizard gán nhanh theo hồ sơ SoD", () => {
  const roles = [...QUICK_ASSIGN_ROLE_CODES, "sys_admin", "owner"].map(
    (code, index) => ({
      id: `00000000-0000-4000-8000-${String(index + 1).padStart(12, "0")}`,
      code,
      name_vi: code,
      description: null,
    }),
  );

  it("with_cc: đủ 15 vai trò mẫu theo đúng thứ tự", () => {
    const filtered = filterQuickAssignRoles("with_cc", roles);
    expect(filtered.map((role) => role.code)).toEqual([
      ...QUICK_ASSIGN_ROLE_CODES,
    ]);
  });

  it("without_cc: ẩn cost_controller, còn 14 vai trò", () => {
    const filtered = filterQuickAssignRoles("without_cc", roles);
    expect(filtered).toHaveLength(14);
    expect(filtered.some((role) => role.code === "cost_controller")).toBe(
      false,
    );
  });

  it("không bao giờ lộ sys_admin/owner trong wizard", () => {
    for (const profile of ["with_cc", "without_cc"] as const) {
      const filtered = filterQuickAssignRoles(profile, roles);
      expect(
        filtered.some(
          (role) => role.code === "sys_admin" || role.code === "owner",
        ),
      ).toBe(false);
    }
  });

  it("vai trò thiếu trong DB thì bỏ qua, thứ tự còn lại giữ nguyên", () => {
    const partial = roles.filter((role) => role.code !== "gm");
    const filtered = filterQuickAssignRoles("with_cc", partial);
    expect(filtered).toHaveLength(14);
    expect(filtered[0].code).toBe("chief_accountant");
  });
});
