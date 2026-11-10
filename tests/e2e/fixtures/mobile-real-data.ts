/**
 * Fixture mobile (W5) — du lieu that, khong bia.
 *
 * Nguon chinh:
 * - `docs/sample-data/seed-sample-data.sql` (rut tu 4 file Excel cua Duy):
 *   §3d minibar 7 mon + §4 bang gia lich su, §3e amenities 12 mon,
 *   §3a–§3c NVL buffet (NVL0388, NVL0561).
 * - `supabase/tests/restaurant_test.sql` §2 (M06): mon MON01 + foodcost.
 * - `tests/e2e/write/seed-test-property.sql` (T-047): property TEST47
 *   + 2 vat tu NVL0388/NVL0561 (xem `TEST_SEED` trong real-data.ts).
 *
 * Moi gia tri duoi day deu co the doi chieu ve 1 trong cac nguon tren;
 * Vitest `tests/unit/mobile-fixtures.test.ts` khoa cac bat bien nay
 * (so mon, ma, gia, foodcost) de fixture khong bi go sai so.
 */

export const MOBILE_FIXTURE_SOURCES = {
  seedSql: "docs/sample-data/seed-sample-data.sql",
  buffetXlsx: "Lst_2020_DL_Buffet.xlsx (sheet NVL)",
  minibarXlsx: "Nha__p_Xua__t_Minibar.xlsx (sheet 10.2018–11.2019)",
  amenitiesXlsx:
    "tha_ng_5_theo_do_i_so___lu_o__ng_Amenities_trong_nga_y.xlsx (thang 5/2019)",
  restaurantTest: "supabase/tests/restaurant_test.sql §2 (M06)",
  testPropertySeed: "tests/e2e/write/seed-test-property.sql (T-047)",
} as const;

/**
 * 7 mon minibar — seed §3d (ma + ten + ĐVT) + §4 (gia ban lich su =
 * gia tri thuong gap nhat cua doanh thu thang / so luong ban thang,
 * 14 thang 10/2018–11/2019).
 *
 * QUAN TRONG — gia o day CHI LA LICH SU, khong phai gia hien hanh:
 * seed §4 ghi valid_from 2018-10-01, valid_to 2019-11-30; kiem chung
 * seed 10/11 21:29: minibar_price_list co 7 dong nhung deu het han
 * 2019 nen 0 gia hien hanh. Gia ban hien hanh phai nhap qua
 * minibar_price_set (Q47). Khong dung `price` duoi day lam gia ban
 * 2026 o bat ky test nao — test chi dung no de doi chieu lich su.
 * ĐVT lon/chai suy ra tu loai hang (file Excel khong ghi ĐVT).
 */
export const MINIBAR_ITEMS = [
  { code: "MB-LARUE", name: "Larue", uom: "lon", price: 25000 },
  { code: "MB-TIGER", name: "Tiger", uom: "lon", price: 35000 },
  { code: "MB-COCA", name: "Coca-Cola", uom: "lon", price: 25000 },
  { code: "MB-DIETCOKE", name: "Diet Coke", uom: "lon", price: 25000 },
  { code: "MB-LAVIE", name: "Lavie", uom: "chai", price: 15000 },
  { code: "MB-SPRITE", name: "Sprite", uom: "lon", price: 25000 },
  { code: "MB-VANG", name: "Rượu vang", uom: "chai", price: 245000 },
] as const;

/** Ten 7 mon minibar (de doi chieu option trong form kiem mobile). */
export const MINIBAR_ITEM_NAMES = MINIBAR_ITEMS.map((i) => i.name);

/**
 * 12 mon amenities thang 5/2019 — seed §3e. 11 mon nhom AMN + nuoc
 * dasani nhom CPM (complimentary, KHONG phai minibar — theo T-035).
 * pcs → ĐVT 'cai'.
 *
 * Luu y seed 10/11 21:29: room_setup_standards va trolley_par_levels
 * deu 0 dong (khoi §5 dung cot min_qty khong ton tai, khoi §6 thieu
 * trolley_warehouse_id NOT NULL nen 2 khoi khong chay duoc) — khong
 * co fixture nao o file nay gia dinh co du lieu o 2 bang do.
 */
export const AMENITY_ITEMS = [
  { code: "AMN-GIAY-VS", name: "Giấy vệ sinh", uom: "cuon", group: "AMN" },
  { code: "AMN-TRA-COZY", name: "Trà cozy", uom: "goi", group: "AMN" },
  { code: "AMN-DUONG", name: "Đường thẻ", uom: "cai", group: "AMN" },
  { code: "AMN-CAPHE", name: "Cà phê", uom: "goi", group: "AMN" },
  { code: "AMN-XAPHONG", name: "Xà phòng cục", uom: "cai", group: "AMN" },
  { code: "AMN-BANCHAI", name: "Bàn chải", uom: "cai", group: "AMN" },
  { code: "AMN-DAO", name: "Dao cạo râu", uom: "cai", group: "AMN" },
  { code: "AMN-TUIVS", name: "Túi vệ sinh", uom: "cai", group: "AMN" },
  { code: "AMN-LUOC", name: "Lược", uom: "cai", group: "AMN" },
  { code: "AMN-BONG", name: "Bông quáy tai", uom: "cai", group: "AMN" },
  { code: "AMN-CHUPTOC", name: "Chụp tóc", uom: "cai", group: "AMN" },
  { code: "CPM-DASANI", name: "Nước dasani", uom: "chai", group: "CPM" },
] as const;

/** Ten 12 mon amenities (de doi chieu muc par / chuan setup phong). */
export const AMENITY_ITEM_NAMES = AMENITY_ITEMS.map((i) => i.name);

/**
 * Mon mau M06 — `restaurant_test.sql` §2 (pgTAP, khong phai du lieu
 * van hanh that): MON01 "Cơm gà xối mỡ", gia ban 45.000 đ, 2 dong
 * dinh luong: gao 100 gr (→ 0,1 kg × 12.000 = 1.200 đ) + thit
 * 0,2 kg (× 50.000 = 10.000 đ) → foodcost 11.200 đ.
 */
export const MON01_DISH = {
  code: "MON01",
  name: "Cơm gà xối mỡ",
  kind: "dish",
  salePrice: 45000,
  lines: [
    { item: "gạo", qty: 100, uom: "gr", unitPrice: 12000, cost: 1200 },
    { item: "thịt", qty: 0.2, uom: "kg", unitPrice: 50000, cost: 10000 },
  ],
  /** Tong foodcost: 1.200 + 10.000 = 11.200 đ. */
  foodcost: 11200,
} as const;

/** Property test TEST47 (T-047) — id co dinh trong seed-test-property.sql. */
export const TEST47_PROPERTY_ID = "b0000000-0000-4000-8000-000000000002";

/**
 * Route mobile nha hang (W4) — GIA DINH, chua co tren base nay
 * (W4 dang lam song song; repo chi co route desktop
 * `src/app/(app)/[property]/restaurant/{banquets,buffet,dishes,kitchen,sales}`).
 * Neu W4 doi ten route, sua 1 cho o day + ghi Q198.
 */
export const RESTAURANT_MOBILE_ROUTES = {
  kitchen: "/restaurant/kitchen",
  dishes: "/restaurant/dishes",
  banquets: "/restaurant/banquets",
  buffet: "/restaurant/buffet",
} as const;
