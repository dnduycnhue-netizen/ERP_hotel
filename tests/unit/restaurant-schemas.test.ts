import { describe, expect, it } from "vitest";
import {
  banquetHallSaveSchema,
  banquetSaveSchema,
  buffetSessionSaveSchema,
  dishSaleRecordSchema,
  recipeSaveSchema,
} from "@/features/restaurant/schemas";

describe("recipeSaveSchema", () => {
  const base = {
    propertyId: "00000000-0000-4000-8000-000000000001",
    code: "MON01",
    name: "Cơm gà",
    kind: "dish" as const,
    lines: [],
  };

  it("chấp nhận món không có dòng định lượng", () => {
    expect(recipeSaveSchema.safeParse(base).success).toBe(true);
  });

  it("chặn kind ngoài danh mục", () => {
    expect(recipeSaveSchema.safeParse({ ...base, kind: "drink" }).success).toBe(
      false,
    );
  });

  it("chặn dòng vừa có item vừa có món con", () => {
    expect(
      recipeSaveSchema.safeParse({
        ...base,
        lines: [
          {
            itemId: "00000000-0000-4000-8000-000000000002",
            subRecipeId: "00000000-0000-4000-8000-000000000003",
            qty: 1,
            uom: "kg",
          },
        ],
      }).success,
    ).toBe(false);
  });

  it("chặn dòng không có item lẫn món con", () => {
    expect(
      recipeSaveSchema.safeParse({
        ...base,
        lines: [{ qty: 1, uom: "kg" }],
      }).success,
    ).toBe(false);
  });

  it("chặn qty <= 0 và loss_pct > 100", () => {
    expect(
      recipeSaveSchema.safeParse({
        ...base,
        lines: [
          {
            itemId: "00000000-0000-4000-8000-000000000002",
            qty: 0,
            uom: "kg",
          },
        ],
      }).success,
    ).toBe(false);
    expect(
      recipeSaveSchema.safeParse({
        ...base,
        lines: [
          {
            itemId: "00000000-0000-4000-8000-000000000002",
            qty: 1,
            uom: "kg",
            lossPct: 101,
          },
        ],
      }).success,
    ).toBe(false);
  });
});

describe("buffetSessionSaveSchema", () => {
  it("chặn buổi ngoài danh mục", () => {
    expect(
      buffetSessionSaveSchema.safeParse({
        propertyId: "00000000-0000-4000-8000-000000000001",
        businessDate: "2026-11-10",
        meal: "brunch",
        dishes: [],
      }).success,
    ).toBe(false);
  });
});

describe("dishSaleRecordSchema", () => {
  it("chặn ngày sai định dạng", () => {
    expect(
      dishSaleRecordSchema.safeParse({
        propertyId: "00000000-0000-4000-8000-000000000001",
        businessDate: "10/11/2026",
        recipeId: "00000000-0000-4000-8000-000000000002",
        qty: 1,
        unitPrice: 1000,
      }).success,
    ).toBe(false);
  });
});

describe("banquetSaveSchema", () => {
  const base = {
    propertyId: "00000000-0000-4000-8000-000000000001",
    customerName: "Anh Tuấn",
    eventDate: "2026-11-11",
    startTime: "10:00",
    endTime: "13:00",
    hall: "Sảnh A",
    guestsCount: 50,
    dishes: [],
  };

  it("chấp nhận tiệc hợp lệ", () => {
    expect(banquetSaveSchema.safeParse(base).success).toBe(true);
  });

  it("chặn giờ kết thúc không sau giờ bắt đầu", () => {
    expect(
      banquetSaveSchema.safeParse({ ...base, endTime: "10:00" }).success,
    ).toBe(false);
  });

  it("chặn số khách <= 0", () => {
    expect(
      banquetSaveSchema.safeParse({ ...base, guestsCount: 0 }).success,
    ).toBe(false);
  });

  it("chấp nhận tiệc chọn sảnh danh mục + đã cọc", () => {
    expect(
      banquetSaveSchema.safeParse({
        ...base,
        hallId: "00000000-0000-4000-8000-000000000002",
        depositAmount: 2000000,
        depositStatus: "paid",
      }).success,
    ).toBe(true);
  });

  it("chặn đã cọc nhưng tiền cọc bằng 0", () => {
    expect(
      banquetSaveSchema.safeParse({
        ...base,
        depositAmount: 0,
        depositStatus: "paid",
      }).success,
    ).toBe(false);
  });

  it("chặn trạng thái cọc ngoài danh mục", () => {
    expect(
      banquetSaveSchema.safeParse({
        ...base,
        depositAmount: 100000,
        depositStatus: "partial",
      }).success,
    ).toBe(false);
  });

  it("chặn hallId không phải UUID", () => {
    expect(
      banquetSaveSchema.safeParse({ ...base, hallId: "sanh-a" }).success,
    ).toBe(false);
  });
});

describe("banquetHallSaveSchema", () => {
  const base = {
    propertyId: "00000000-0000-4000-8000-000000000001",
    name: "Sảnh A",
  };

  it("chấp nhận sảnh chỉ có tên", () => {
    expect(banquetHallSaveSchema.safeParse(base).success).toBe(true);
  });

  it("chấp nhận sảnh có sức chứa", () => {
    expect(
      banquetHallSaveSchema.safeParse({ ...base, capacity: 120 }).success,
    ).toBe(true);
  });

  it("chặn tên sảnh rỗng", () => {
    expect(
      banquetHallSaveSchema.safeParse({ ...base, name: "   " }).success,
    ).toBe(false);
  });

  it("chặn sức chứa <= 0", () => {
    expect(
      banquetHallSaveSchema.safeParse({ ...base, capacity: 0 }).success,
    ).toBe(false);
  });
});
