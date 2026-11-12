import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parsePosCsv } from "@/lib/pos/parse-csv";

describe("parsePosCsv", () => {
  it("đọc được file mẫu giả lập", () => {
    const text = readFileSync(
      "docs/samples/pos-export-sample-SYNTHETIC.csv",
      "utf8",
    );
    const res = parsePosCsv(text);
    expect(res.ok).toBe(true);
    if (res.ok) {
      expect(res.lines).toHaveLength(114);
      expect(res.lines[0]?.item_code).toMatch(/^ALA-/);
    }
  });

  it("báo thiếu cột bắt buộc", () => {
    const res = parsePosCsv("bill_no,shift\nB1,morning\n");
    expect(res).toMatchObject({ ok: false, error: "missing_columns" });
  });

  it("báo dòng sai (số lượng 0)", () => {
    const res = parsePosCsv(
      "bill_no,business_date,shift,item_code,qty,unit_price,amount\nB1,2026-11-10,morning,A,0,1,1\n",
    );
    expect(res).toMatchObject({ ok: false, error: "bad_row", detail: "2" });
  });

  it("xử lý dấu ngoặc kép và BOM", () => {
    const res = parsePosCsv(
      '﻿bill_no,business_date,shift,item_code,item_name,qty,unit_price,amount\nB1,2026-11-10,morning,A,"Món, có phẩy",1,10,10\n',
    );
    expect(res.ok && res.lines[0]?.item_name).toBe("Món, có phẩy");
  });
});
