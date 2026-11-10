/**
 * Gán nhanh khi tạo khách sạn (docs/06-UI-UX.md §6.4): sau khi tạo khách
 * sạn, trình hướng dẫn gợi ý bộ vai trò mẫu theo hồ sơ (có / không Cost
 * Controller) và cho gán người vào từng vai trò trên một màn hình.
 *
 * Bộ vai trò mẫu = 15 vai trò hệ thống của migration go-live (không gồm
 * sys_admin / owner vì hai vai trò đó gán toàn chuỗi, RPC admin_org_create
 * đã gán cho người tạo). Hồ sơ without_cc thì ẩn Cost Controller.
 */

export const QUICK_ASSIGN_ROLE_CODES = [
  "gm",
  "chief_accountant",
  "accountant",
  "cost_controller",
  "purchaser",
  "storekeeper",
  "receiver",
  "outlet_head",
  "chef",
  "bartender",
  "hk_supervisor",
  "hk_attendant",
  "front_desk",
  "engineer",
  "internal_audit",
] as const;

export type SodProfile = "with_cc" | "without_cc";

export type QuickAssignRole = {
  id: string;
  code: string;
  name_vi: string;
  description: string | null;
};

/** Lọc + xếp đúng thứ tự bộ vai trò mẫu theo hồ sơ SoD của khách sạn. */
export function filterQuickAssignRoles<T extends QuickAssignRole>(
  sodProfile: SodProfile,
  roles: T[],
): T[] {
  const wanted = QUICK_ASSIGN_ROLE_CODES.filter(
    (code) => sodProfile === "with_cc" || code !== "cost_controller",
  );
  const order = new Map<string, number>(
    wanted.map((code, index) => [code, index]),
  );
  return roles
    .filter((role) => order.has(role.code))
    .sort((a, b) => (order.get(a.code) ?? 0) - (order.get(b.code) ?? 0));
}
