"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callRestaurantRpc, type RestaurantActionResult } from "./rpc";
import {
  banquetCancelSchema,
  banquetHallSaveSchema,
  banquetIdSchema,
  banquetSaveSchema,
  buffetSessionCancelSchema,
  buffetSessionCloseSchema,
  buffetSessionSaveSchema,
  dishSaleRecordSchema,
  dishSaleVoidSchema,
  recipeSaveSchema,
  recipeSetActiveSchema,
  type BanquetCancelInput,
  type BanquetHallSaveInput,
  type BanquetIdInput,
  type BanquetSaveInput,
  type BuffetSessionCancelInput,
  type BuffetSessionCloseInput,
  type BuffetSessionSaveInput,
  type DishSaleRecordInput,
  type DishSaleVoidInput,
  type RecipeSaveInput,
  type RecipeSetActiveInput,
} from "./schemas";

export type RecipeSaveResult = {
  ok: boolean;
  id: string;
  version_no: number;
};

export type IdResult = { ok: boolean; id: string };

export type BuffetCloseResult = {
  ok: boolean;
  id: string;
  revenue: number;
};

export type BanquetCompleteResult = {
  ok: boolean;
  id: string;
  revenue: number;
};

/** Kết quả xác nhận tiệc: kèm phiếu lĩnh nháp tự sinh (C11, Q169). */
export type BanquetConfirmResult = {
  ok: boolean;
  id: string;
  requisition_id: string | null;
  requisition_note: string | null;
};

function validationError(
  issues: { message: string }[],
): RestaurantActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? "Dữ liệu không hợp lệ." };
}

function restaurantPath(propertyId: string, sub = ""): string {
  return `/${propertyId}/restaurant${sub}`;
}

/** Tạo / cập nhật món ăn + công thức (RPC `recipe_save`). */
export async function saveRecipeAction(
  input: RecipeSaveInput,
): Promise<RestaurantActionResult<RecipeSaveResult>> {
  const parsed = recipeSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<RecipeSaveResult>(
    supabase,
    "recipe_save",
    {
      p_property_id: parsed.data.propertyId,
      p_recipe: {
        id: parsed.data.id ?? null,
        code: parsed.data.code,
        name: parsed.data.name,
        kind: parsed.data.kind,
        group_name: parsed.data.groupName ?? null,
        yield_qty: parsed.data.yieldQty ?? null,
        yield_uom: parsed.data.yieldUom ?? null,
        portions_per_batch: parsed.data.portionsPerBatch ?? null,
        diet_flags: parsed.data.dietFlags,
        sale_price: parsed.data.salePrice ?? null,
        is_active: parsed.data.isActive,
        notes: parsed.data.notes ?? null,
        lines: parsed.data.lines.map((l) => ({
          item_id: l.itemId ?? null,
          sub_recipe_id: l.subRecipeId ?? null,
          qty: l.qty,
          uom: l.uom,
          loss_pct: l.lossPct,
          note: l.note ?? null,
        })),
      },
    },
  );
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/dishes"));
    if (parsed.data.id) {
      revalidatePath(
        restaurantPath(parsed.data.propertyId, `/dishes/${parsed.data.id}`),
      );
    }
  }
  return res;
}

/** Bật / tắt món (RPC `recipe_set_active`). */
export async function setRecipeActiveAction(
  input: RecipeSetActiveInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = recipeSetActiveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(supabase, "recipe_set_active", {
    p_property_id: parsed.data.propertyId,
    p_recipe_id: parsed.data.recipeId,
    p_is_active: parsed.data.isActive,
  });
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/dishes"));
  }
  return res;
}

/** Tạo / cập nhật phiên buffet (RPC `buffet_session_save`). */
export async function saveBuffetSessionAction(
  input: BuffetSessionSaveInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = buffetSessionSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(
    supabase,
    "buffet_session_save",
    {
      p_property_id: parsed.data.propertyId,
      p_session: {
        id: parsed.data.id ?? null,
        business_date: parsed.data.businessDate,
        meal: parsed.data.meal,
        guest_count: parsed.data.guestCount,
        price_per_guest: parsed.data.pricePerGuest ?? null,
        notes: parsed.data.notes ?? null,
        dishes: parsed.data.dishes.map((d) => ({
          recipe_id: d.recipeId,
          planned_qty: d.plannedQty,
          note: d.note ?? null,
        })),
      },
    },
  );
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/buffet"));
    if (parsed.data.id) {
      revalidatePath(
        restaurantPath(parsed.data.propertyId, `/buffet/${parsed.data.id}`),
      );
    }
  }
  return res;
}

/** Đóng phiên buffet — ghi doanh thu theo khách (RPC `buffet_session_close`). */
export async function closeBuffetSessionAction(
  input: BuffetSessionCloseInput,
): Promise<RestaurantActionResult<BuffetCloseResult>> {
  const parsed = buffetSessionCloseSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<BuffetCloseResult>(
    supabase,
    "buffet_session_close",
    {
      p_property_id: parsed.data.propertyId,
      p_session_id: parsed.data.sessionId,
      p_guest_count: parsed.data.guestCount,
      p_price_per_guest: parsed.data.pricePerGuest,
    },
  );
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/buffet"));
    revalidatePath(
      restaurantPath(
        parsed.data.propertyId,
        `/buffet/${parsed.data.sessionId}`,
      ),
    );
    revalidatePath(restaurantPath(parsed.data.propertyId, "/sales"));
  }
  return res;
}

/** Hủy phiên buffet (RPC `buffet_session_cancel`). */
export async function cancelBuffetSessionAction(
  input: BuffetSessionCancelInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = buffetSessionCancelSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(
    supabase,
    "buffet_session_cancel",
    {
      p_property_id: parsed.data.propertyId,
      p_session_id: parsed.data.sessionId,
      p_reason: parsed.data.reason,
    },
  );
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/buffet"));
  }
  return res;
}

/** Ghi bán tay (RPC `dish_sale_record`). */
export async function recordDishSaleAction(
  input: DishSaleRecordInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = dishSaleRecordSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(supabase, "dish_sale_record", {
    p_property_id: parsed.data.propertyId,
    p_business_date: parsed.data.businessDate,
    p_recipe_id: parsed.data.recipeId,
    p_qty: parsed.data.qty,
    p_unit_price: parsed.data.unitPrice,
  });
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/sales"));
  }
  return res;
}

/** Hủy dòng bán tay ghi sai (RPC `dish_sale_void`). */
export async function voidDishSaleAction(
  input: DishSaleVoidInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = dishSaleVoidSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(supabase, "dish_sale_void", {
    p_property_id: parsed.data.propertyId,
    p_sale_id: parsed.data.saleId,
  });
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/sales"));
  }
  return res;
}

/** Tạo / cập nhật tiệc (RPC `banquet_save`). */
export async function saveBanquetAction(
  input: BanquetSaveInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = banquetSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(supabase, "banquet_save", {
    p_property_id: parsed.data.propertyId,
    p_banquet: {
      id: parsed.data.id ?? null,
      customer_name: parsed.data.customerName,
      customer_phone: parsed.data.customerPhone ?? null,
      event_date: parsed.data.eventDate,
      start_time: parsed.data.startTime,
      end_time: parsed.data.endTime,
      hall: parsed.data.hall,
      hall_id: parsed.data.hallId ?? null,
      tables_count: parsed.data.tablesCount,
      guests_count: parsed.data.guestsCount,
      deposit_amount: parsed.data.depositAmount,
      deposit_status: parsed.data.depositStatus,
      notes: parsed.data.notes ?? null,
      dishes: parsed.data.dishes.map((d) => ({
        recipe_id: d.recipeId,
        qty: d.qty,
        unit_price: d.unitPrice ?? null,
        note: d.note ?? null,
      })),
    },
  });
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/banquets"));
    if (parsed.data.id) {
      revalidatePath(
        restaurantPath(parsed.data.propertyId, `/banquets/${parsed.data.id}`),
      );
    }
  }
  return res;
}

async function banquetStatusAction(
  fn: string,
  input: BanquetIdInput,
  propertyId: string,
  banquetId: string,
): Promise<RestaurantActionResult<IdResult>> {
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(supabase, fn, {
    p_property_id: propertyId,
    p_banquet_id: banquetId,
  });
  if (res.ok) {
    revalidatePath(restaurantPath(propertyId, "/banquets"));
    revalidatePath(restaurantPath(propertyId, `/banquets/${banquetId}`));
    if (fn === "banquet_complete") {
      revalidatePath(restaurantPath(propertyId, "/sales"));
    }
  }
  return res;
}

/** Xác nhận tiệc (RPC `banquet_confirm`) — kèm phiếu lĩnh nháp tự sinh. */
export async function confirmBanquetAction(
  input: BanquetIdInput,
): Promise<RestaurantActionResult<BanquetConfirmResult>> {
  const parsed = banquetIdSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<BanquetConfirmResult>(
    supabase,
    "banquet_confirm",
    {
      p_property_id: parsed.data.propertyId,
      p_banquet_id: parsed.data.banquetId,
    },
  );
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/banquets"));
    revalidatePath(
      restaurantPath(
        parsed.data.propertyId,
        `/banquets/${parsed.data.banquetId}`,
      ),
    );
    revalidatePath(restaurantPath(parsed.data.propertyId, "/kitchen"));
  }
  return res;
}

/** Bắt đầu tiệc (RPC `banquet_start`). */
export async function startBanquetAction(
  input: BanquetIdInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = banquetIdSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return banquetStatusAction(
    "banquet_start",
    parsed.data,
    parsed.data.propertyId,
    parsed.data.banquetId,
  );
}

/** Hoàn thành tiệc — ghi doanh thu từng món (RPC `banquet_complete`). */
export async function completeBanquetAction(
  input: BanquetIdInput,
): Promise<RestaurantActionResult<BanquetCompleteResult>> {
  const parsed = banquetIdSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<BanquetCompleteResult>(
    supabase,
    "banquet_complete",
    {
      p_property_id: parsed.data.propertyId,
      p_banquet_id: parsed.data.banquetId,
    },
  );
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/banquets"));
    revalidatePath(
      restaurantPath(
        parsed.data.propertyId,
        `/banquets/${parsed.data.banquetId}`,
      ),
    );
    revalidatePath(restaurantPath(parsed.data.propertyId, "/sales"));
  }
  return res;
}

/** Tạo / cập nhật sảnh trong danh mục (C11, Q170b — RPC `banquet_hall_save`). */
export async function saveBanquetHallAction(
  input: BanquetHallSaveInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = banquetHallSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(supabase, "banquet_hall_save", {
    p_property_id: parsed.data.propertyId,
    p_hall: {
      id: parsed.data.id ?? null,
      name: parsed.data.name,
      capacity: parsed.data.capacity ?? null,
      is_active: parsed.data.isActive,
      notes: parsed.data.notes ?? null,
    },
  });
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/halls"));
    revalidatePath(restaurantPath(parsed.data.propertyId, "/banquets"));
  }
  return res;
}

/** Hủy tiệc (RPC `banquet_cancel`). */
export async function cancelBanquetAction(
  input: BanquetCancelInput,
): Promise<RestaurantActionResult<IdResult>> {
  const parsed = banquetCancelSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callRestaurantRpc<IdResult>(supabase, "banquet_cancel", {
    p_property_id: parsed.data.propertyId,
    p_banquet_id: parsed.data.banquetId,
    p_reason: parsed.data.reason,
  });
  if (res.ok) {
    revalidatePath(restaurantPath(parsed.data.propertyId, "/banquets"));
    revalidatePath(
      restaurantPath(
        parsed.data.propertyId,
        `/banquets/${parsed.data.banquetId}`,
      ),
    );
  }
  return res;
}
