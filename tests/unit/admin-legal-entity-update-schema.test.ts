import { describe, expect, it } from "vitest";
import { updateLegalEntityNameSchema } from "../../src/features/admin/schemas";

/**
 * Q209 — đổi tên pháp nhân: schema Zod dùng chung client/server
 * (updateLegalEntityNameSchema). RPC kiểm tra lại phía server
 * (ERR_INVALID_VALUE) nên schema ở đây chỉ chặn sớm ở form.
 */
describe("updateLegalEntityNameSchema — đổi tên pháp nhân", () => {
  const base = {
    orgId: "00000000-0000-4000-8000-000000000001",
    legalEntityId: "00000000-0000-4000-8000-000000000101",
    name: "Tên pháp nhân thật",
  };

  it("đủ trường hợp lệ thì parse được", () => {
    const parsed = updateLegalEntityNameSchema.safeParse(base);
    expect(parsed.success).toBe(true);
  });

  it("tên có khoảng trắng hai đầu được trim", () => {
    const parsed = updateLegalEntityNameSchema.safeParse({
      ...base,
      name: "  Tên pháp nhân thật  ",
    });
    expect(parsed.success).toBe(true);
    if (parsed.success) {
      expect(parsed.data.name).toBe("Tên pháp nhân thật");
    }
  });

  it("tên rỗng thì lỗi", () => {
    expect(
      updateLegalEntityNameSchema.safeParse({ ...base, name: "" }).success,
    ).toBe(false);
  });

  it("tên chỉ có khoảng trắng thì lỗi", () => {
    expect(
      updateLegalEntityNameSchema.safeParse({ ...base, name: "   " }).success,
    ).toBe(false);
  });

  it("tên dài hơn 200 ký tự thì lỗi, đúng 200 ký tự thì được", () => {
    expect(
      updateLegalEntityNameSchema.safeParse({ ...base, name: "X".repeat(201) })
        .success,
    ).toBe(false);
    expect(
      updateLegalEntityNameSchema.safeParse({ ...base, name: "X".repeat(200) })
        .success,
    ).toBe(true);
  });

  it("orgId/legalEntityId không phải uuid thì lỗi", () => {
    expect(
      updateLegalEntityNameSchema.safeParse({
        ...base,
        orgId: "khong-phai-uuid",
      }).success,
    ).toBe(false);
    expect(
      updateLegalEntityNameSchema.safeParse({
        ...base,
        legalEntityId: "khong-phai-uuid",
      }).success,
    ).toBe(false);
  });
});
