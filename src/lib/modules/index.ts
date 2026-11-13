/**
 * Module tùy chọn bật/tắt theo từng khách sạn (Q254).
 * - `hk_frontdesk`: Buồng phòng & Lễ tân (minibar, xe đẩy, chuẩn setup
 *   phòng, số liệu PMS ngày).
 * - `restaurant`: Nhà hàng (món, buffet, tiệc, bán hàng, nạp file POS).
 * Lõi (mua hàng, nhận hàng, kho, tài chính, báo cáo chung) luôn bật.
 *
 * Chặn thật nằm ở DB (trigger `_module_guard` → `ERR_MODULE_DISABLED`);
 * phần này chỉ ẩn giao diện bằng cách bỏ mã quyền của module đang tắt.
 */
export const MODULE_IDS = ["hk_frontdesk", "restaurant"] as const;
export type ModuleId = (typeof MODULE_IDS)[number];
export type PropertyModules = Record<ModuleId, boolean>;

export const ALL_MODULES_ON: PropertyModules = {
  hk_frontdesk: true,
  restaurant: true,
};

const MODULE_PERMISSION_MATCHERS: Record<ModuleId, (code: string) => boolean> =
  {
    hk_frontdesk: (code) =>
      code.startsWith("minibar.") ||
      code.startsWith("hk.") ||
      code === "pms.input" ||
      code === "report.view.rpt_minibar" ||
      code === "report.view.rpt_amenity_cpor",
    restaurant: (code) =>
      code.startsWith("restaurant.") ||
      code === "pos.import" ||
      code === "report.view.rpt_fnb_revenue",
  };

/** Bỏ các mã quyền thuộc module đang tắt (menu/nút tự ẩn theo quyền). */
export function filterPermissionsByModules(
  permissions: readonly string[],
  modules: PropertyModules,
): string[] {
  return permissions.filter((code) =>
    MODULE_IDS.every(
      (id) => modules[id] || !MODULE_PERMISSION_MATCHERS[id](code),
    ),
  );
}

export function parsePropertyModules(value: unknown): PropertyModules {
  if (typeof value !== "object" || value === null) {
    return ALL_MODULES_ON;
  }
  const record = value as Record<string, unknown>;
  return {
    hk_frontdesk: record.hk_frontdesk !== false,
    restaurant: record.restaurant !== false,
  };
}
