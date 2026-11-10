import { describe, expect, it } from "vitest";
import { parseDashboardOverview } from "@/features/property/schemas";

const valid = {
  ok: true,
  property: {
    id: "00000000-0000-4000-8000-000000000001",
    code: "P1",
    name: "Property C10",
    sod_profile: "with_cc",
    rooms_count: 10,
    org_id: "00000000-0000-4000-8000-000000000002",
    legal_entity: {
      code: "TC10",
      name: "Entity C10",
      costing_method: "moving_avg",
      accounting_regime: "TT99",
    },
  },
  counts: { items: 2, warehouses: 2, item_groups: 2, roles: 3 },
};

describe("parseDashboardOverview", () => {
  it("chấp nhận payload đầy đủ từ RPC", () => {
    expect(parseDashboardOverview(valid)).toEqual(valid);
  });

  it("chấp nhận pháp nhân null", () => {
    const parsed = parseDashboardOverview({
      ...valid,
      property: { ...valid.property, legal_entity: null },
    });
    expect(parsed.property.legal_entity).toBeNull();
  });

  it("chặn ok=false", () => {
    expect(() => parseDashboardOverview({ ...valid, ok: false })).toThrow();
  });

  it("chặn count âm", () => {
    expect(() =>
      parseDashboardOverview({
        ...valid,
        counts: { ...valid.counts, items: -1 },
      }),
    ).toThrow();
  });

  it("chặn thiếu counts.roles", () => {
    const countsWithoutRoles = {
      items: valid.counts.items,
      warehouses: valid.counts.warehouses,
      item_groups: valid.counts.item_groups,
    };
    expect(() =>
      parseDashboardOverview({ ...valid, counts: countsWithoutRoles }),
    ).toThrow();
  });

  it("chặn property id không phải uuid", () => {
    expect(() =>
      parseDashboardOverview({
        ...valid,
        property: { ...valid.property, id: "not-a-uuid" },
      }),
    ).toThrow();
  });

  it("bỏ key lạ ngoài hợp đồng", () => {
    const parsed = parseDashboardOverview({
      ...valid,
      recent_docs: [],
    });
    expect("recent_docs" in parsed).toBe(false);
  });
});
