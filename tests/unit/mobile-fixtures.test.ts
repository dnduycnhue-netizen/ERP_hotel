import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import {
  AMENITY_ITEMS,
  MINIBAR_ITEMS,
  MON01_DISH,
  TEST47_PROPERTY_ID,
} from "../e2e/fixtures/mobile-real-data";
import { BUFFET_ITEMS, TEST_SEED_ITEMS } from "../e2e/fixtures/real-data";

/**
 * Fixture mobile (W5) — khoa cac bat bien du lieu that.
 *
 * Nguon: `docs/sample-data/seed-sample-data.sql` (§3d/§4 minibar,
 * §3e amenities, §3a–§3c NVL buffet) + `supabase/tests/restaurant_test.sql`
 * §2 (MON01) + `tests/e2e/write/seed-test-property.sql` (TEST47).
 * Test doc truc tiep file seed SQL de fixture khong lech khoi nguon.
 */

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
);
const seedSql = readFileSync(
  path.join(repoRoot, "docs/sample-data/seed-sample-data.sql"),
  "utf8",
);
const offlineDbSrc = readFileSync(
  path.join(repoRoot, "src/lib/offline/db.ts"),
  "utf8",
);

describe("fixture mobile — minibar 7 món (seed §3d + §4)", () => {
  it("U17 — đủ 7 món minibar, mã + tên + ĐVT khớp seed SQL", () => {
    expect(MINIBAR_ITEMS).toHaveLength(7);
    for (const item of MINIBAR_ITEMS) {
      expect(seedSql).toContain(`('${item.code}', '${item.name}'`);
      expect(seedSql).toContain(`('${item.code}', ${item.price})`);
    }
    expect(MINIBAR_ITEMS.map((i) => i.code)).toEqual([
      "MB-LARUE",
      "MB-TIGER",
      "MB-COCA",
      "MB-DIETCOKE",
      "MB-LAVIE",
      "MB-SPRITE",
      "MB-VANG",
    ]);
  });

  it("U18 — giá lịch sử: Lavie rẻ nhất, Rượu vang đắt nhất", () => {
    const prices = MINIBAR_ITEMS.map((i) => i.price);
    expect(Math.min(...prices)).toBe(15000); // Lavie
    expect(Math.max(...prices)).toBe(245000); // Rượu vang
    expect(MINIBAR_ITEMS.find((i) => i.code === "MB-LARUE")?.price).toBe(25000);
    expect(MINIBAR_ITEMS.find((i) => i.code === "MB-TIGER")?.price).toBe(35000);
  });

  it("U25 — giá minibar CHỈ là lịch sử: hết hạn 30/11/2019, 0 giá hiện hành", () => {
    // Seed §4: valid_from 2018-10-01, valid_to 2019-11-30 (kiem chung
    // seed 10/11 21:29: 7 dong deu het han). Khong co gia nao ap duoc
    // cho phieu kiem 2026 — gia hien hanh phai nhap qua minibar_price_set.
    expect(seedSql).toContain("date '2018-10-01', date '2019-11-30'");
    expect(seedSql).not.toMatch(/valid_to\s*=\s*date '202[6-9]/);
    // Fixture khong duoc gia vo co gia hien hanh: moi gia deu gan voi
    // cua so lich su tren, khong co truong nao ten "currentPrice".
    for (const item of MINIBAR_ITEMS) {
      expect(Object.keys(item)).not.toContain("currentPrice");
    }
  });
});

describe("fixture mobile — amenities 12 món (seed §3e)", () => {
  it("U19 — đủ 12 món, 11 AMN + 1 CPM (Nước dasani)", () => {
    expect(AMENITY_ITEMS).toHaveLength(12);
    expect(AMENITY_ITEMS.filter((i) => i.group === "AMN")).toHaveLength(11);
    expect(AMENITY_ITEMS.filter((i) => i.group === "CPM")).toHaveLength(1);
    for (const item of AMENITY_ITEMS) {
      expect(seedSql).toContain(`('${item.code}', '${item.name}'`);
    }
    const dasani = AMENITY_ITEMS.find((i) => i.code === "CPM-DASANI");
    expect(dasani?.name).toBe("Nước dasani");
    expect(dasani?.uom).toBe("chai");
  });

  it("U20 — Giấy vệ sinh / Trà cozy / Cà phê khớp số liệu ngày 09/05/2019", () => {
    // Ten mon phai khop fixture amenities ngay 9.5.2019 trong real-data.ts
    // (AMENITY_DAY_2019_05_09) — ten trong seed §3e giong het ten trong Excel.
    for (const name of ["Giấy vệ sinh", "Trà cozy", "Cà phê"]) {
      expect(AMENITY_ITEMS.some((i) => i.name === name)).toBe(true);
    }
  });
});

describe("fixture mobile — món MON01 + định dạng tiền/số (M06)", () => {
  it("U21 — foodcost MON01 = 1.200 (gạo) + 10.000 (thịt) = 11.200 đ", () => {
    expect(MON01_DISH.code).toBe("MON01");
    expect(MON01_DISH.name).toBe("Cơm gà xối mỡ");
    const sum = MON01_DISH.lines.reduce((s, l) => s + l.cost, 0);
    expect(sum).toBe(MON01_DISH.foodcost);
    expect(MON01_DISH.foodcost).toBe(11200);
    // Ty le foodcost / gia ban: 11200 / 45000 ≈ 24,9% (< 30%).
    expect(MON01_DISH.foodcost / MON01_DISH.salePrice).toBeLessThan(0.3);
  });

  it("U22 — formatMoney/formatNumber (vi-VN) cho giá thật", () => {
    expect(formatMoney(11200)).toBe("11.200 đ");
    expect(formatMoney(25000)).toBe("25.000 đ");
    expect(formatMoney(245000)).toBe("245.000 đ");
    expect(formatMoney(100000)).toBe("100.000 đ"); // gia tran NVL0388
    expect(formatMoney(null)).toBe("—");
    expect(formatMoney("abc")).toBe("—");
    expect(formatNumber(10)).toBe("10");
    expect(formatNumber("1000")).toBe("1.000");
    expect(formatNumber(0.2)).toBe("0,2"); // 0,2 kg thit / MON01
  });
});

describe("fixture mobile — property TEST47 + vật tư seed (T-047)", () => {
  it("U23 — TEST47 id cố định + 2 vật tư NVL0388/NVL0561 khớp Excel", () => {
    // Da kiem chung Dashboard 10/11 21:34 (dieu phoi vien chinh): ca 2 mon
    // hien dung la mon nhom TP cua SONHOIAN (external_codes buffet
    // stt 1 va 3), tong org 668, khong trung ma o org khac; nhom test
    // T047 con ton tai nhung trong. Trang thai hien tai la dung cho du
    // lieu that — test duoc phep dua vao ca ma lan nhom TP.
    expect(TEST47_PROPERTY_ID).toBe("b0000000-0000-4000-8000-000000000002");
    // Nhom TP + stt buffet trong seed §3a (doi chieu truc tiep file SQL).
    expect(seedSql).toContain("('NVL0388', 'ba chỉ nách', 'TP'");
    expect(seedSql).toContain("('NVL0561', 'Bánh bèo', 'TP'");
    // external_codes buffet: NVL0388 stt 1, NVL0561 stt 3 (kiem chung 21:34).
    const lineOf = (code: string) =>
      seedSql.split("\n").find((l) => l.includes(`('${code}'`)) ?? "";
    expect(lineOf("NVL0388")).toContain('"stt":1');
    expect(lineOf("NVL0561")).toContain('"stt":3');
    for (const item of TEST_SEED_ITEMS) {
      const buffet = BUFFET_ITEMS.find((b) => b.code === item.code);
      expect(buffet).toBeDefined();
      expect(buffet?.name).toBe(item.name);
      // ĐVT trong Excel ("Cái") vs ma ĐVT trong seed SQL ("cai"):
      // so sau khi bo dau + ha chu.
      const norm = (s: string) =>
        s
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g, "")
          .replace(/đ/g, "d")
          .replace(/Đ/g, "D")
          .toLowerCase();
      expect(norm(buffet?.uom ?? "")).toBe(norm(item.uom));
      // Ma + ten cung phai co trong seed SQL §3a–§3c.
      expect(seedSql).toContain(`('${item.code}', '${item.name}'`);
    }
    expect(TEST_SEED_ITEMS).toHaveLength(2);
  });
});

describe("fixture mobile — trạng thái hàng đợi offline (Q152)", () => {
  it("U24 — Dexie queue có đủ 6 kind, CHƯA có kind minibar (Q152 đang mở)", () => {
    // Khoa trang thai hien tai: minibar chi nop online (mobile-check-form
    // goi thang submitCheckAction) vi queue chua co kind minibar.
    // Khi Q152 chot them kind `minibar_submit`, sua test nay + them kind
    // vao danh sach ky vong — khong sua lang.
    for (const kind of [
      "record",
      "override",
      "post",
      "count_record",
      "trolley_open",
      "trolley_close",
    ]) {
      expect(offlineDbSrc).toContain(`"${kind}"`);
    }
    expect(offlineDbSrc).not.toContain("minibar_submit");
  });
});
