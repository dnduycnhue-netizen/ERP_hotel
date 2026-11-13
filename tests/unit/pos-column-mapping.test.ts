import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  excelSerialToIso,
  guessPosMapping,
  mapRowsToLines,
  normalizePosDate,
  normalizePosNumber,
  type PosColumnMapping,
} from "@/lib/pos/column-mapping";
import { splitCsv } from "@/lib/pos/parse-csv";

describe("guessPosMapping", () => {
  it("canonical headers map to themselves", () => {
    const headers = [
      "bill_no",
      "business_date",
      "shift",
      "time",
      "outlet",
      "item_code",
      "item_name",
      "qty",
      "unit_price",
      "amount",
      "payment",
    ];
    const m = guessPosMapping(headers);
    for (const h of headers) {
      expect(m[h as keyof PosColumnMapping]).toBe(h);
    }
  });

  it("guesses Vietnamese headers", () => {
    const m = guessPosMapping([
      "Mã bill",
      "Ngày",
      "Ca",
      "Giờ",
      "Quầy",
      "Mã món",
      "Tên món",
      "Số lượng",
      "Đơn giá",
      "Thành tiền",
      "Thanh toán",
    ]);
    expect(m).toMatchObject({
      bill_no: "Mã bill",
      business_date: "Ngày",
      shift: "Ca",
      time: "Giờ",
      outlet: "Quầy",
      item_code: "Mã món",
      item_name: "Tên món",
      qty: "Số lượng",
      unit_price: "Đơn giá",
      amount: "Thành tiền",
      payment: "Thanh toán",
    });
  });

  it("unknown headers stay unmapped and a column is used once", () => {
    const m = guessPosMapping(["Foo", "Bar", "Mã món", "Tên món"]);
    expect(m.bill_no).toBeNull();
    expect(m.item_code).toBe("Mã món");
    expect(m.item_name).toBe("Tên món");
    // "Tên món" must not also be claimed by another target.
    expect(Object.values(m).filter((v) => v === "Tên món")).toHaveLength(1);
  });
});

describe("normalizePosDate", () => {
  it("keeps ISO dates", () => {
    expect(normalizePosDate("2026-11-10")).toBe("2026-11-10");
  });

  it("converts DD/MM/YYYY", () => {
    expect(normalizePosDate("10/11/2026")).toBe("2026-11-10");
    expect(normalizePosDate("1/2/2026")).toBe("2026-02-01");
    expect(normalizePosDate("10-11-2026")).toBe("2026-11-10");
    expect(normalizePosDate("10.11.2026")).toBe("2026-11-10");
    expect(normalizePosDate("10/11/26")).toBe("2026-11-10");
  });

  it("rejects impossible dates", () => {
    expect(normalizePosDate("31/02/2026")).toBeNull();
    expect(normalizePosDate("2026-13-01")).toBeNull();
    expect(normalizePosDate("hello")).toBeNull();
    expect(normalizePosDate("")).toBeNull();
  });

  it("converts Excel serials", () => {
    expect(excelSerialToIso(44927)).toBe("2023-01-01");
    expect(normalizePosDate(44927)).toBe("2023-01-01");
    expect(normalizePosDate(10)).toBeNull();
  });
});

describe("normalizePosNumber", () => {
  it("handles Vietnamese and English formats", () => {
    expect(normalizePosNumber("1.234,56")).toBe("1234.56");
    expect(normalizePosNumber("1,234.56")).toBe("1234.56");
    expect(normalizePosNumber("12.345,67")).toBe("12345.67");
    expect(normalizePosNumber("1,5")).toBe("1.5");
    expect(normalizePosNumber("1.234")).toBe("1234");
    expect(normalizePosNumber("1,234")).toBe("1234");
    expect(normalizePosNumber("85000")).toBe("85000");
    expect(normalizePosNumber(" 2 ")).toBe("2");
  });

  it("rejects non-numbers", () => {
    expect(normalizePosNumber("abc")).toBeNull();
    expect(normalizePosNumber("")).toBeNull();
    expect(normalizePosNumber("1,2,3")).toBeNull();
    expect(normalizePosNumber(null)).toBeNull();
  });
});

describe("mapRowsToLines", () => {
  it("reads the synthetic sample with an identity mapping", () => {
    const text = readFileSync(
      "docs/samples/pos-export-sample-SYNTHETIC.csv",
      "utf8",
    );
    const rows = splitCsv(text);
    const headers = rows[0] ?? [];
    const mapping = guessPosMapping(headers);
    const res = mapRowsToLines(headers, rows.slice(1), mapping);
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.lines).toHaveLength(114);
      expect(res.lines[0]?.item_code).toBe("ALA-06");
      expect(res.lines[0]?.business_date).toBe("2026-11-10");
    }
  });

  it("maps Vietnamese headers and normalizes dates/numbers", () => {
    const headers = [
      "Mã bill",
      "Ngày",
      "Ca",
      "Mã món",
      "Tên món",
      "Số lượng",
      "Đơn giá",
      "Thành tiền",
    ];
    const mapping = guessPosMapping(headers);
    const res = mapRowsToLines(
      headers,
      [
        [
          "B1",
          "10/11/2026",
          "morning",
          "ALA-06",
          "Cà tím",
          "2",
          "85.000",
          "170.000",
        ],
      ],
      mapping,
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.lines[0]).toMatchObject({
        bill_no: "B1",
        business_date: "2026-11-10",
        shift: "morning",
        item_code: "ALA-06",
        qty: "2",
        unit_price: "85000",
        amount: "170000",
      });
    }
  });

  it("accepts Excel serial dates", () => {
    const headers = [
      "bill_no",
      "business_date",
      "shift",
      "item_code",
      "qty",
      "unit_price",
      "amount",
    ];
    const res = mapRowsToLines(
      headers,
      [["B1", 44927, "morning", "A", "1", "10", "10"]],
      guessPosMapping(headers),
    );
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.lines[0]?.business_date).toBe("2023-01-01");
    }
  });

  it("reports missing required columns", () => {
    const res = mapRowsToLines(
      ["bill_no", "shift"],
      [["B1", "morning"]],
      guessPosMapping(["bill_no", "shift"]),
    );
    expect(res).toMatchObject({ ok: false, error: "missing_columns" });
  });

  it("reports the bad row number", () => {
    const headers = [
      "bill_no",
      "business_date",
      "shift",
      "item_code",
      "qty",
      "unit_price",
      "amount",
    ];
    const res = mapRowsToLines(
      headers,
      [
        ["B1", "2026-11-10", "morning", "A", "1", "10", "10"],
        ["B2", "2026-11-10", "morning", "A", "0", "10", "10"],
      ],
      guessPosMapping(headers),
    );
    expect(res).toMatchObject({ ok: false, error: "bad_row", detail: "3" });
  });
});
