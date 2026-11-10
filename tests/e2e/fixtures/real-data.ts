/**
 * Du lieu mau lay tu 4 file Excel that cua Duy (~/workspace/user/files/)
 * — CHI DOC, khong sua file goc. Gia tri duoi day dung lam ky vong
 * trong test (Vitest + tang ghi Playwright).
 *
 * Nguon:
 * - Lst_2020_DL_Buffet.xlsx (sheet NVL): ma + ten vat tu that.
 * - Lst_Alacarte_foodcost.xlsx (sheet Foodcost): dinh luong mon an.
 * - Nhap_Xuat_Minibar.xlsx (sheet 10.2018): nhap/xuat/ton minibar ngay.
 * - thang_5_theo_doi_so_luong_Amenities_trong_ngay.xlsx (sheet 9.5.2019):
 *   ton dau / xuat / dung / ton cuoi amenities theo ngay.
 */

export const REAL_DATA_SOURCES = [
  "Lst_2020_DL_Buffet.xlsx",
  "Lst_Alacarte_foodcost.xlsx",
  "Nhap_Xuat_Minibar.xlsx",
  "thang_5_theo_doi_so_luong_Amenities_trong_ngay.xlsx",
] as const;

export type FixtureItem = {
  code: string;
  name: string;
  group: string;
  uom: string;
  factor: number;
  factorUom: string;
};

/** Vat tu that tu sheet NVL (ca 2 file Buffet + Alacarte deu co). */
export const BUFFET_ITEMS: FixtureItem[] = [
  {
    code: "NVL0388",
    name: "ba chỉ nách",
    group: "Thịt",
    uom: "kg",
    factor: 1000,
    factorUom: "gr",
  },
  {
    code: "NVL0152",
    name: "BA CHỈ XÔNG KHÓI",
    group: "Thịt Nguội",
    uom: "kg",
    factor: 1000,
    factorUom: "gr",
  },
  {
    code: "NVL0561",
    name: "Bánh bèo",
    group: "Bánh",
    uom: "Cái",
    factor: 1,
    factorUom: "cái",
  },
  {
    code: "NVL0559",
    name: "Bánh da lợn",
    group: "Bánh",
    uom: "Cái",
    factor: 1,
    factorUom: "cái",
  },
  {
    code: "NVL0387",
    name: "bánh mì baguette",
    group: "Bánh",
    uom: "CÁI",
    factor: 1,
    factorUom: "cái",
  },
];

/** Dinh luong that — mon "Rau muống trộn tôm thịt" (sheet Foodcost). */
export const FOODCOST_DISH = {
  name: "Rau muống trộn tôm thịt",
  lines: [
    { item: "Rau muống hột", qty: 100, uom: "gr" },
    { item: "củ cà rốt", qty: 30, uom: "gr" },
    { item: "Hành Tây", qty: 20, uom: "gr" },
    { item: "Hành tím lớn", qty: 20, uom: "gr" },
  ],
  /** Tong dinh luong: 100 + 30 + 20 + 20 = 170 gr. */
  totalGrams: 170,
} as const;

/** Minibar ngay 2018-10-01: dau ky - xuat = ton (sheet 10.2018). */
export const MINIBAR_DAY_2018_10_01 = {
  date: "2018-10-01",
  larue: { opening: 18, sold: 4, closing: 14 },
  tiger: { opening: 12, sold: 1, closing: 11 },
  coca: { opening: 11 },
} as const;

/** Minibar ngay 2018-10-03: co nhap bu (sheet 10.2018). */
export const MINIBAR_DAY_2018_10_03 = {
  date: "2018-10-03",
  larue: { opening: 10, received: 48, sold: 7, closing: 51 },
} as const;

/** Amenities ngay 9.5.2019, cong suat 31 phong (sheet 9.5.2019). */
export const AMENITY_DAY_2019_05_09 = {
  date: "9.5.2019",
  roomsOccupied: 31,
  toiletPaper: {
    item: "Giấy vệ sinh",
    uom: "cuộn",
    opening: 157,
    issued: 37,
    used: 28,
    onTrolley: 9,
    closing: 129,
  },
  tea: {
    item: "Trà cozy",
    uom: "gói",
    opening: 69,
    issued: 57,
    used: 10,
    onTrolley: 47,
    closing: 59,
  },
  coffee: {
    item: "Cà phê",
    uom: "gói",
    opening: 78,
    issued: 57,
    used: 12,
    onTrolley: 45,
    closing: 66,
  },
} as const;

/**
 * Vat tu dung cho tang ghi (seed-test-property.sql tao san tren
 * property test). Nhom "other" + is_key_item=false nen nhan hang
 * KHONG bat buoc chup anh (ham _receiving_photo_required chi bat
 * khi is_key_item hoac nhom kind='food') — tranh phu thuoc camera
 * khi chay tu dong.
 */
export const TEST_SEED_ITEMS = [
  {
    code: "NVL0388",
    name: "ba chỉ nách",
    uom: "kg",
    ceilingPrice: 100000,
    seedQty: 10,
  },
  {
    code: "NVL0561",
    name: "Bánh bèo",
    uom: "cai",
    ceilingPrice: 5000,
    seedQty: 20,
  },
] as const;

export const TEST_SEED = {
  supplierCode: "NCC-T047",
  supplierName: "NCC T047",
  /** UUID co dinh trong seed-test-property.sql (de dung query param). */
  supplierId: "b0000000-0000-4000-8000-000000000031",
  warehouseCode: "KHO-T047",
  warehouseName: "Kho chính T047",
  outletCode: "NH-T047",
  outletName: "Nhà hàng T047",
  propertyCode: "TEST47",
  propertyName: "Khách sạn test T047",
} as const;
