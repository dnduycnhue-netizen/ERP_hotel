import { describe, expect, it } from "vitest";
import { createUserSchema } from "../../src/features/admin/schemas";

/**
 * Hoi quy cho vu owner 10/11: tai khoan duoc tao (tick du 17 vai tro)
 * nhung DB chi co 1 dong user_property_roles la sys_admin. Schema
 * createUserSchema la cua ngõ validation chung client/server — test nay
 * khoa bat bien: danh sach vai tro gui len phai giu NGUYEN so luong
 * (khong gioi han 1, khong rot vai tro o tang validation).
 */
describe("createUserSchema — tạo tài khoản đa vai trò", () => {
  const base = {
    employeeCode: "E2E001",
    fullName: "Kiểm thử đa vai trò",
    email: "e2e-multirole@example.com",
    phone: "",
    password: "Tmp-e2e-1234",
    propertyId: null as string | null,
  };

  it("U14 — 2 vai trò parse được và giữ nguyên thứ tự", () => {
    const roleIds = [
      "11111111-1111-4111-8111-111111111111",
      "22222222-2222-4222-8222-222222222222",
    ];
    const parsed = createUserSchema.safeParse({ ...base, roleIds });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.roleIds).toEqual(roleIds);
    }
  });

  it("U15 — 17 vai trò (đủ bộ như lúc tạo owner) parse được", () => {
    const roleIds = Array.from(
      { length: 17 },
      (_, i) => `00000000-0000-4000-8000-${String(i + 1).padStart(12, "0")}`,
    );
    const parsed = createUserSchema.safeParse({ ...base, roleIds });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.roleIds).toHaveLength(17);
    }
  });

  it("U16 — roleId không phải uuid thì validation lỗi", () => {
    const parsed = createUserSchema.safeParse({
      ...base,
      roleIds: ["khong-phai-uuid"],
    });
    expect(parsed.success).toBe(false);
  });

  it("U17 — Q165: không chọn vai trò nào thì validation lỗi", () => {
    const parsed = createUserSchema.safeParse({ ...base, roleIds: [] });
    expect(parsed.success).toBe(false);
  });
});
