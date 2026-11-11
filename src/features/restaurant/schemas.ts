import { z } from "zod";
import { vi } from "@/i18n/vi";

/** M06 — schema Zod dùng chung client/server cho form nhà hàng. */

export const recipeKindSchema = z.enum(["dish", "buffet_batch", "set_menu"]);
export type RecipeKind = z.infer<typeof recipeKindSchema>;

export const recipeLineSchema = z.object({
  itemId: z.string().uuid().nullable().optional(),
  subRecipeId: z.string().uuid().nullable().optional(),
  qty: z.number().positive(vi.common.quantityPositive),
  uom: z.string().min(1, vi.restaurant.uomNotSelected),
  lossPct: z.number().min(0).max(100).default(0),
  note: z.string().optional(),
});

export const recipeSaveSchema = z
  .object({
    propertyId: z.string().uuid(),
    id: z.string().uuid().optional(),
    code: z.string().trim().min(1, vi.restaurant.dishCodeNotEntered),
    name: z.string().trim().min(1, vi.restaurant.dishNameNotEntered),
    kind: recipeKindSchema,
    groupName: z.string().trim().optional(),
    yieldQty: z.number().positive().optional(),
    yieldUom: z.string().optional(),
    portionsPerBatch: z.number().positive().optional(),
    dietFlags: z.array(z.string().trim().min(1)).default([]),
    salePrice: z.number().nonnegative().optional(),
    isActive: z.boolean().default(true),
    notes: z.string().optional(),
    lines: z.array(recipeLineSchema).default([]),
  })
  .superRefine((data, ctx) => {
    data.lines.forEach((line, i) => {
      const hasItem = !!line.itemId;
      const hasSub = !!line.subRecipeId;
      if (hasItem === hasSub) {
        ctx.addIssue({
          code: "custom",
          message: vi.restaurant.lineMustHaveOneIngredientOrSubRecipe,
          path: ["lines", i],
        });
      }
    });
  });

export type RecipeSaveInput = z.infer<typeof recipeSaveSchema>;

export const recipeSetActiveSchema = z.object({
  propertyId: z.string().uuid(),
  recipeId: z.string().uuid(),
  isActive: z.boolean(),
});

export type RecipeSetActiveInput = z.infer<typeof recipeSetActiveSchema>;

export const buffetMealSchema = z.enum(["breakfast", "lunch", "dinner"]);
export type BuffetMeal = z.infer<typeof buffetMealSchema>;

export const buffetSessionSaveSchema = z.object({
  propertyId: z.string().uuid(),
  id: z.string().uuid().optional(),
  businessDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, vi.restaurant.dateInvalid),
  meal: buffetMealSchema,
  guestCount: z.number().int().nonnegative().default(0),
  pricePerGuest: z.number().nonnegative().optional(),
  notes: z.string().optional(),
  dishes: z
    .array(
      z.object({
        recipeId: z.string().uuid(),
        plannedQty: z.number().positive(vi.restaurant.servingsPositive),
        note: z.string().optional(),
      }),
    )
    .default([]),
});

export type BuffetSessionSaveInput = z.infer<typeof buffetSessionSaveSchema>;

export const buffetSessionCloseSchema = z.object({
  propertyId: z.string().uuid(),
  sessionId: z.string().uuid(),
  guestCount: z.number().int().positive(vi.restaurant.guestCountPositive),
  pricePerGuest: z.number().nonnegative(vi.restaurant.pricePerGuestNonNegative),
});

export type BuffetSessionCloseInput = z.infer<typeof buffetSessionCloseSchema>;

export const buffetSessionCancelSchema = z.object({
  propertyId: z.string().uuid(),
  sessionId: z.string().uuid(),
  reason: z.string().trim().min(1, vi.restaurant.cancelReasonNotEntered),
});

export type BuffetSessionCancelInput = z.infer<
  typeof buffetSessionCancelSchema
>;

export const dishSaleRecordSchema = z.object({
  propertyId: z.string().uuid(),
  businessDate: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, vi.restaurant.dateInvalid),
  recipeId: z.string().uuid(),
  qty: z.number().positive(vi.common.quantityPositive),
  unitPrice: z.number().nonnegative(vi.common.unitPriceNonNegative),
});

export type DishSaleRecordInput = z.infer<typeof dishSaleRecordSchema>;

export const dishSaleVoidSchema = z.object({
  propertyId: z.string().uuid(),
  saleId: z.string().uuid(),
});

export type DishSaleVoidInput = z.infer<typeof dishSaleVoidSchema>;

export const depositStatusSchema = z.enum(["unpaid", "paid"]);
export type DepositStatus = z.infer<typeof depositStatusSchema>;

export const banquetSaveSchema = z
  .object({
    propertyId: z.string().uuid(),
    id: z.string().uuid().optional(),
    customerName: z
      .string()
      .trim()
      .min(1, vi.restaurant.customerNameNotEntered),
    customerPhone: z.string().trim().optional(),
    eventDate: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, vi.restaurant.dateInvalid),
    startTime: z.string().regex(/^\d{2}:\d{2}$/, vi.restaurant.timeInvalid),
    endTime: z.string().regex(/^\d{2}:\d{2}$/, vi.restaurant.timeInvalid),
    hall: z.string().trim().min(1, vi.restaurant.hallNotEntered),
    hallId: z.string().uuid().optional(),
    tablesCount: z.number().int().nonnegative().default(0),
    guestsCount: z.number().int().positive(vi.restaurant.guestCountPositive),
    depositAmount: z.number().nonnegative().default(0),
    depositStatus: depositStatusSchema.default("unpaid"),
    notes: z.string().optional(),
    dishes: z
      .array(
        z.object({
          recipeId: z.string().uuid(),
          qty: z.number().positive(vi.restaurant.servingsPositive),
          unitPrice: z.number().nonnegative().optional(),
          note: z.string().optional(),
        }),
      )
      .default([]),
  })
  .superRefine((data, ctx) => {
    if (data.endTime <= data.startTime) {
      ctx.addIssue({
        code: "custom",
        message: vi.restaurant.endTimeAfterStartTime,
        path: ["endTime"],
      });
    }
    if (data.depositStatus === "paid" && data.depositAmount <= 0) {
      ctx.addIssue({
        code: "custom",
        message: vi.restaurant.depositPaidRequiresAmount,
        path: ["depositAmount"],
      });
    }
  });

export type BanquetSaveInput = z.infer<typeof banquetSaveSchema>;

/** Danh mục sảnh (C11, Q170b): tên bắt buộc, sức chứa > 0 nếu có. */
export const banquetHallSaveSchema = z.object({
  propertyId: z.string().uuid(),
  id: z.string().uuid().optional(),
  name: z.string().trim().min(1, vi.restaurant.hallNameNotEntered),
  capacity: z.number().int().positive().optional(),
  isActive: z.boolean().default(true),
  notes: z.string().optional(),
});

export type BanquetHallSaveInput = z.infer<typeof banquetHallSaveSchema>;

export const banquetIdSchema = z.object({
  propertyId: z.string().uuid(),
  banquetId: z.string().uuid(),
});

export type BanquetIdInput = z.infer<typeof banquetIdSchema>;

export const banquetCancelSchema = banquetIdSchema.extend({
  reason: z.string().trim().min(1, vi.restaurant.cancelReasonNotEntered),
});

export type BanquetCancelInput = z.infer<typeof banquetCancelSchema>;
