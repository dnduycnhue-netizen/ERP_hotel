import { describe, expect, it } from "vitest";
import { diffAuditRow } from "@/lib/admin/audit-diff";

describe("diffAuditRow", () => {
  it("INSERT lists every new column", () => {
    expect(diffAuditRow(null, { a: 1, b: "x" })).toEqual([
      { field: "a", before: null, after: "1" },
      { field: "b", before: null, after: "x" },
    ]);
  });

  it("UPDATE lists only changed columns and ignores updated_at", () => {
    expect(
      diffAuditRow(
        { a: 1, b: "x", updated_at: "t1" },
        { a: 2, b: "x", updated_at: "t2" },
      ),
    ).toEqual([{ field: "a", before: "1", after: "2" }]);
  });

  it("DELETE lists every old column", () => {
    expect(diffAuditRow({ a: 1 }, null)).toEqual([
      { field: "a", before: "1", after: null },
    ]);
  });

  it("truncates very long values", () => {
    const [change] = diffAuditRow(null, { big: "y".repeat(500) });
    expect(change?.after?.length).toBe(201);
  });

  it("returns empty for non-object input", () => {
    expect(diffAuditRow("x", [1])).toEqual([]);
  });
});
