import { describe, expect, it } from "vitest";
import {
  AMENITY_DAY_2019_05_09,
  BUFFET_ITEMS,
  FOODCOST_DISH,
  MINIBAR_DAY_2018_10_01,
  MINIBAR_DAY_2018_10_03,
} from "../e2e/fixtures/real-data";

/**
 * Bat bien so lieu that tu file Excel cua Duy (xem fixtures/real-data.ts):
 * ton = dau ky + nhap - xuat; dinh luong = tong cac dong.
 * Test nay bao ve file fixture khoi go sai so khi sua sau nay.
 */
describe("dữ liệu thật từ file Excel (fixture)", () => {
  it("U9 — minibar 01/10/2018: đầu kỳ − xuất = tồn", () => {
    const { larue, tiger } = MINIBAR_DAY_2018_10_01;
    expect(larue.opening - larue.sold).toBe(larue.closing);
    expect(tiger.opening - tiger.sold).toBe(tiger.closing);
  });

  it("U10 — minibar 03/10/2018: đầu kỳ + nhập − xuất = tồn", () => {
    const { larue } = MINIBAR_DAY_2018_10_03;
    expect(larue.opening + larue.received - larue.sold).toBe(larue.closing);
  });

  it("U11 — amenities 09/05/2019: tồn cuối = tồn đầu − dùng; xuất = dùng + trên xe", () => {
    const day = AMENITY_DAY_2019_05_09;
    for (const line of [day.toiletPaper, day.tea, day.coffee]) {
      expect(line.opening - line.used).toBe(line.closing);
      expect(line.used + line.onTrolley).toBe(line.issued);
    }
    expect(day.roomsOccupied).toBe(31);
  });

  it("U12 — foodcost: tổng định lượng món bằng tổng các dòng", () => {
    const sum = FOODCOST_DISH.lines.reduce((s, l) => s + l.qty, 0);
    expect(sum).toBe(FOODCOST_DISH.totalGrams);
    expect(FOODCOST_DISH.lines).toHaveLength(4);
  });

  it("U13 — vật tư buffet: hệ số quy đổi kg → gr là 1000", () => {
    const meat = BUFFET_ITEMS.find((i) => i.code === "NVL0388");
    expect(meat).toBeDefined();
    expect(meat?.uom).toBe("kg");
    expect(meat?.factor).toBe(1000);
    expect(meat?.factorUom).toBe("gr");
    const cake = BUFFET_ITEMS.find((i) => i.code === "NVL0561");
    expect(cake?.factor).toBe(1);
  });
});
