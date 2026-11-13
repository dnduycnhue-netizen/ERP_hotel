import { describe, expect, it } from "vitest";
import {
  ALL_MODULES_ON,
  filterPermissionsByModules,
  parsePropertyModules,
} from "@/lib/modules";

const PERMS = [
  "po.create",
  "count.open",
  "minibar.check",
  "hk.trolley.operate",
  "pms.input",
  "report.view.rpt_minibar",
  "report.view.rpt_stock_card",
  "restaurant.sale.record",
  "pos.import",
  "report.view.rpt_fnb_revenue",
];

describe("filterPermissionsByModules", () => {
  it("keeps everything when both modules are on", () => {
    expect(filterPermissionsByModules(PERMS, ALL_MODULES_ON)).toEqual(PERMS);
  });

  it("drops restaurant permissions only when restaurant is off", () => {
    const out = filterPermissionsByModules(PERMS, {
      hk_frontdesk: true,
      restaurant: false,
    });
    expect(out).not.toContain("restaurant.sale.record");
    expect(out).not.toContain("pos.import");
    expect(out).not.toContain("report.view.rpt_fnb_revenue");
    expect(out).toContain("minibar.check");
  });

  it("drops housekeeping/front desk permissions only when hk_frontdesk is off", () => {
    const out = filterPermissionsByModules(PERMS, {
      hk_frontdesk: false,
      restaurant: true,
    });
    for (const code of [
      "minibar.check",
      "hk.trolley.operate",
      "pms.input",
      "report.view.rpt_minibar",
    ]) {
      expect(out).not.toContain(code);
    }
    expect(out).toContain("restaurant.sale.record");
  });

  it("never drops core permissions", () => {
    const out = filterPermissionsByModules(PERMS, {
      hk_frontdesk: false,
      restaurant: false,
    });
    expect(out).toEqual([
      "po.create",
      "count.open",
      "report.view.rpt_stock_card",
    ]);
  });
});

describe("parsePropertyModules", () => {
  it("reads the RPC payload", () => {
    expect(
      parsePropertyModules({ hk_frontdesk: false, restaurant: true }),
    ).toEqual({ hk_frontdesk: false, restaurant: true });
  });

  it("defaults to on for missing or malformed data", () => {
    expect(parsePropertyModules(null)).toEqual(ALL_MODULES_ON);
    expect(parsePropertyModules("x")).toEqual(ALL_MODULES_ON);
    expect(parsePropertyModules({})).toEqual(ALL_MODULES_ON);
  });
});
