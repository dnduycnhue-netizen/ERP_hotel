import { utils, write } from "xlsx";
import { describe, expect, it } from "vitest";
import {
  matchBulkColumns,
  readBulkFile,
  validateBulkRows,
} from "@/lib/master/bulk-import";

const ROOM_TYPES = [
  { code: "DLX", id: "type-dlx" },
  { code: "STD", id: "type-std" },
];
const ITEMS = [
  { code: "NVL0388", id: "item-388" },
  { code: "ALA-06", id: "item-ala06" },
];
const UOMS = [{ code: "kg" }, { code: "cai" }];

function csv(text: string): ArrayBuffer {
  return new TextEncoder().encode(text).buffer as ArrayBuffer;
}

describe("readBulkFile", () => {
  it("reads CSV headers and rows", () => {
    const res = readBulkFile(
      csv("room_no,floor,room_type_code\n101,1,DLX\n102,1,STD\n"),
      "rooms.csv",
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.headers).toEqual(["room_no", "floor", "room_type_code"]);
      expect(res.rows).toHaveLength(2);
      expect(res.headerRowNo).toBe(1);
    }
  });

  it("reports empty files", () => {
    expect(readBulkFile(csv("room_no\n"), "rooms.csv")).toMatchObject({
      ok: false,
      error: "empty",
    });
  });

  it("rejects unknown extensions", () => {
    expect(readBulkFile(csv("a,b\n1,2\n"), "rooms.pdf")).toMatchObject({
      ok: false,
      error: "invalid_file",
    });
  });

  it("reads the first sheet of an XLSX file", () => {
    const wb = utils.book_new();
    utils.book_append_sheet(
      wb,
      utils.aoa_to_sheet([
        ["room_no", "floor", "room_type_code"],
        ["201", "2", "DLX"],
      ]),
      "Rooms",
    );
    const buf = write(wb, { type: "array" }) as ArrayBuffer;
    const res = readBulkFile(buf, "rooms.xlsx");
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.headers).toEqual(["room_no", "floor", "room_type_code"]);
      expect(res.rows[0]?.[0]).toBe("201");
    }
  });
});

describe("matchBulkColumns", () => {
  it("matches Vietnamese headers", () => {
    expect(
      matchBulkColumns("rooms", ["Số phòng", "Tầng", "Mã loại phòng"]),
    ).toMatchObject({
      room_no: "Số phòng",
      floor: "Tầng",
      room_type_code: "Mã loại phòng",
    });
  });
});

describe("validateBulkRows — rooms", () => {
  const headers = ["room_no", "floor", "room_type_code"];
  it("resolves the room type and accepts valid rows", () => {
    const res = validateBulkRows(
      "rooms",
      headers,
      [["101", "1", "DLX"]],
      1,
      { roomTypes: ROOM_TYPES, existingRoomNos: [] },
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.rows).toHaveLength(1);
      expect(res.rows[0]?.errors).toEqual([]);
      expect(res.rows[0]?.resolved.roomTypeId).toBe("type-dlx");
      expect(res.rows[0]?.rowNo).toBe(2);
    }
  });

  it("flags unknown room type, duplicates and missing values", () => {
    const res = validateBulkRows(
      "rooms",
      headers,
      [
        ["101", "1", "XXX"],
        ["101", "1", "DLX"],
        ["102", "1", "DLX"],
        ["", "1", "DLX"],
      ],
      1,
      { roomTypes: ROOM_TYPES, existingRoomNos: ["102"] },
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.rows[0]?.errors).toContainEqual({
        field: "room_type_code",
        code: "unknown_code",
      });
      expect(res.rows[1]?.errors).toContainEqual({
        field: "room_no",
        code: "duplicate",
      });
      expect(res.rows[2]?.errors).toContainEqual({
        field: "room_no",
        code: "duplicate",
      });
      expect(res.rows[3]?.errors).toContainEqual({
        field: "room_no",
        code: "required",
      });
    }
  });

  it("reports missing required columns", () => {
    const res = validateBulkRows("rooms", ["room_no"], [["101"]], 1, {
      roomTypes: ROOM_TYPES,
    });
    expect(res).toMatchObject({ ok: false, error: "missing_columns" });
  });
});

describe("validateBulkRows — room_types", () => {
  it("rejects duplicate codes and bad guest counts", () => {
    const res = validateBulkRows(
      "room_types",
      ["code", "name", "max_guests"],
      [
        ["DLX", "Deluxe", "2"],
        ["DLX", "Deluxe 2", "3"],
        ["VIP", "VIP", "abc"],
      ],
      1,
      { existingRoomTypeCodes: [] },
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.rows[0]?.errors).toEqual([]);
      expect(res.rows[0]?.resolved.maxGuests).toBe(2);
      expect(res.rows[1]?.errors).toContainEqual({
        field: "code",
        code: "duplicate",
      });
      expect(res.rows[2]?.errors).toContainEqual({
        field: "max_guests",
        code: "bad_number",
      });
    }
  });
});

describe("validateBulkRows — ceiling_prices", () => {
  const headers = [
    "item_code",
    "uom",
    "price",
    "valid_from",
    "valid_to",
    "scope",
  ];
  const lookups = { items: ITEMS, uoms: UOMS };
  it("accepts a valid row and maps scope words", () => {
    const res = validateBulkRows(
      "ceiling_prices",
      headers,
      [["NVL0388", "kg", "100.000", "01/01/2026", "31/12/2026", "chuỗi"]],
      1,
      lookups,
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.rows[0]?.errors).toEqual([]);
      expect(res.rows[0]?.resolved).toMatchObject({
        itemId: "item-388",
        uom: "kg",
        price: 100000,
        validFrom: "2026-01-01",
        validTo: "2026-12-31",
        scope: "chain",
      });
    }
  });

  it("flags unknown item, unknown UoM, bad price and bad scope", () => {
    const res = validateBulkRows(
      "ceiling_prices",
      headers,
      [
        ["XXX", "kg", "10", "2026-01-01", "2026-12-31", ""],
        ["NVL0388", "hop", "10", "2026-01-01", "2026-12-31", ""],
        ["NVL0388", "kg", "-5", "2026-01-01", "2026-12-31", ""],
        ["NVL0388", "kg", "10", "2026-01-01", "2026-12-31", "xxx"],
        ["NVL0388", "kg", "10", "2026-12-31", "2026-01-01", ""],
      ],
      1,
      lookups,
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.rows[0]?.errors).toContainEqual({
        field: "item_code",
        code: "unknown_code",
      });
      expect(res.rows[1]?.errors).toContainEqual({
        field: "uom",
        code: "unknown_uom",
      });
      expect(res.rows[2]?.errors).toContainEqual({
        field: "price",
        code: "bad_number",
      });
      expect(res.rows[3]?.errors).toContainEqual({
        field: "scope",
        code: "bad_scope",
      });
      expect(res.rows[4]?.errors).toContainEqual({
        field: "valid_to",
        code: "bad_date",
      });
    }
  });

  it("requires valid_to like the single-row form", () => {
    const res = validateBulkRows(
      "ceiling_prices",
      headers,
      [["NVL0388", "kg", "10", "2026-01-01", "", ""]],
      1,
      lookups,
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.rows[0]?.errors).toContainEqual({
        field: "valid_to",
        code: "required",
      });
    }
  });
});

describe("validateBulkRows — minibar_prices", () => {
  it("requires a positive price and allows open-ended validity", () => {
    const res = validateBulkRows(
      "minibar_prices",
      ["item_code", "price", "valid_from", "valid_to"],
      [
        ["ALA-06", "0", "2026-01-01", ""],
        ["ALA-06", "15000", "01/01/2026", ""],
      ],
      1,
      { items: ITEMS },
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.rows[0]?.errors).toContainEqual({
        field: "price",
        code: "bad_number",
      });
      expect(res.rows[1]?.errors).toEqual([]);
      expect(res.rows[1]?.resolved.validFrom).toBe("2026-01-01");
    }
  });
});
