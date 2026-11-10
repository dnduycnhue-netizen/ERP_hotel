import { describe, expect, it } from "vitest";
import { buildMarketListSearch } from "@/features/procurement/market-list-params";

/** Chuoi query danh sach lenh mua cho (C6): chi giu tham so co gia tri. */
describe("buildMarketListSearch", () => {
  it("tra chuoi rong khi khong co bo loc", () => {
    expect(buildMarketListSearch({})).toBe("");
    expect(buildMarketListSearch({ page: 1 })).toBe("");
    expect(buildMarketListSearch({ status: "" })).toBe("");
  });

  it("giu tu khoa tim kiem, cat khoang trang thua", () => {
    expect(buildMarketListSearch({ search: "  PO-123  " })).toBe(
      "?search=PO-123",
    );
  });

  it("giu trang thai va bo trang 1", () => {
    expect(buildMarketListSearch({ status: "approved", page: 1 })).toBe(
      "?status=approved",
    );
  });

  it("giu trang > 1 va gop du tham so", () => {
    expect(
      buildMarketListSearch({ search: "cho", status: "draft", page: 3 }),
    ).toBe("?search=cho&status=draft&page=3");
  });

  it("ma hoa ky tu dac biet trong tu khoa", () => {
    expect(buildMarketListSearch({ search: "gạo ST25" })).toBe(
      "?search=g%E1%BA%A1o+ST25",
    );
  });
});
