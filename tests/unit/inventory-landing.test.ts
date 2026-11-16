import { describe, expect, it } from "vitest";
import { inventoryLandingPath } from "@/components/shell/nav-items";

const P = "p1";
const path = (...perms: string[]) => inventoryLandingPath(P, new Set(perms));

describe("inventoryLandingPath (R5-N5)", () => {
  it("co quyen linh kho -> phieu linh", () => {
    expect(path("requisition.create", "stock.view_qty")).toBe("/p1/inventory/requisitions");
  });
  it("owner (chi xem ton, huy lon, view_variance) -> dieu chuyen, khong phai phieu linh", () => {
    expect(path("stock.view_qty", "waste.approve.large", "count.view_variance")).toBe(
      "/p1/inventory/transfers",
    );
  });
  it("chi co quyen kiem ke -> kiem ke", () => {
    expect(path("count.perform")).toBe("/p1/inventory/counts");
  });
  it("chi xem gia tri ton -> ton kho", () => {
    expect(path("stock.view_value")).toBe("/p1/inventory/stock");
  });
});
