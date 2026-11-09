"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { getPropertyOrgId, listPurchaseUnits, type PurchaseUnitRow } from "./queries";
import {
  itemSaveSchema,
  itemGroupSaveSchema,
  uomSaveSchema,
  purchaseUnitSaveSchema,
  warehouseSaveSchema,
  roomSaveSchema,
  roomTypeSaveSchema,
  outletSaveSchema,
  outletTypeSaveSchema,
  expenseCategorySaveSchema,
} from "./schemas";

export type MasterActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string };

function mapDbError(error: unknown): string {
  if (!error) return "Đã xảy ra lỗi không xác định.";

  const errObj =
    typeof error === "object" && error !== null
      ? (error as Record<string, unknown>)
      : {};
  const code = typeof errObj.code === "string" ? errObj.code : "";
  const msg = typeof errObj.message === "string" ? errObj.message : "";

  if (code === "42501" || msg.includes("ERR_FORBIDDEN")) {
    return "Bạn chưa được cấp quyền thực hiện thao tác này.";
  }

  if (code === "23505") {
    if (msg.includes("name_norm")) {
      return "Tên vật tư đã tồn tại trong danh mục (kể cả khi khác chữ hoa/thường hoặc khoảng trắng).";
    }
    if (msg.includes("code")) {
      return "Mã đã tồn tại trong danh mục.";
    }
    if (msg.includes("room_no")) {
      return "Số phòng đã tồn tại trong khách sạn.";
    }
    return "Dữ liệu bị trùng lặp với bản ghi đã có trong hệ thống.";
  }

  if (msg.includes("ERR_ITEM_HAS_STOCK_MOVES")) {
    return "Vật tư đã có phát sinh giao dịch kho, không thể xóa (chỉ có thể chuyển sang ngừng dùng).";
  }

  if (msg.includes("ERR_ITEM_UOM_CHANGE_FORBIDDEN")) {
    return "Không thể đổi đơn vị tính lưu kho của vật tư đã có phát sinh giao dịch kho.";
  }

  return msg || "Đã xảy ra lỗi khi lưu dữ liệu. Vui lòng kiểm tra lại.";
}

// 1. Items CRUD
export async function saveItemAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = itemSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }

  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) {
    return { ok: false, error: "Không xác định được tổ chức của khách sạn." };
  }

  const supabase = await createClient();

  if (id) {
    const { error } = await supabase
      .from("items")
      .update({
        code: values.code,
        name: values.name,
        name_en: values.nameEn || null,
        group_id: values.groupId,
        stock_uom: values.stockUom,
        recipe_uom: values.recipeUom || null,
        stock_to_recipe: values.stockToRecipe ?? null,
        is_key_item: values.isKeyItem,
        abc_class: values.abcClass || null,
        track_lot: values.trackLot,
        shelf_life_days: values.shelfLifeDays ?? null,
        storage_condition: values.storageCondition || null,
        vat_rate: values.vatRate ?? null,
        allowed_channels: values.allowedChannels,
        tare_g: values.tareG ?? null,
        density_g_ml: values.densityGMl ?? null,
        status: values.status,
      })
      .eq("id", id);

    if (error) {
      return { ok: false, error: mapDbError(error) };
    }
    revalidatePath(`/${propertyId}/master/items`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("items")
      .insert({
        org_id: orgId,
        code: values.code,
        name: values.name,
        name_en: values.nameEn || null,
        group_id: values.groupId,
        stock_uom: values.stockUom,
        recipe_uom: values.recipeUom || null,
        stock_to_recipe: values.stockToRecipe ?? null,
        is_key_item: values.isKeyItem,
        abc_class: values.abcClass || null,
        track_lot: values.trackLot,
        shelf_life_days: values.shelfLifeDays ?? null,
        storage_condition: values.storageCondition || null,
        vat_rate: values.vatRate ?? null,
        allowed_channels: values.allowedChannels,
        tare_g: values.tareG ?? null,
        density_g_ml: values.densityGMl ?? null,
        status: values.status,
      })
      .select("id")
      .single();

    if (error || !data) {
      return { ok: false, error: mapDbError(error) };
    }
    revalidatePath(`/${propertyId}/master/items`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteItemAction(
  propertyId: string,
  itemId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase.from("items").delete().eq("id", itemId);

  if (error) {
    return { ok: false, error: mapDbError(error) };
  }

  revalidatePath(`/${propertyId}/master/items`);
  return { ok: true, data: { id: itemId } };
}

// 2. Item Groups CRUD
export async function saveItemGroupAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = itemGroupSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }

  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) {
    return { ok: false, error: "Không xác định được tổ chức của khách sạn." };
  }

  const supabase = await createClient();

  if (id) {
    const { error } = await supabase
      .from("item_groups")
      .update({
        code_prefix: values.codePrefix,
        name: values.name,
        kind: values.kind,
        parent_id: values.parentId || null,
      })
      .eq("id", id);

    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/item-groups`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("item_groups")
      .insert({
        org_id: orgId,
        code_prefix: values.codePrefix,
        name: values.name,
        kind: values.kind,
        parent_id: values.parentId || null,
      })
      .select("id")
      .single();

    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/item-groups`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteItemGroupAction(
  propertyId: string,
  groupId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("item_groups")
    .delete()
    .eq("id", groupId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/item-groups`);
  return { ok: true, data: { id: groupId } };
}

// 3. UOMs
export async function saveUomAction(
  propertyId: string,
  input: unknown,
): Promise<MasterActionResult<{ code: string }>> {
  const parsed = uomSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }

  const supabase = await createClient();
  const { error } = await supabase.from("uoms").upsert({
    code: parsed.data.code,
    name_vi: parsed.data.nameVi,
  });

  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/uoms`);
  return { ok: true, data: { code: parsed.data.code } };
}

// 4. Purchase Units
export async function savePurchaseUnitAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = purchaseUnitSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }

  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: "Không xác định được tổ chức." };

  const supabase = await createClient();
  if (id) {
    const { error } = await supabase
      .from("item_purchase_units")
      .update({
        uom: values.uom,
        factor_to_stock: values.factorToStock,
        is_default: values.isDefault,
      })
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/items`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("item_purchase_units")
      .insert({
        org_id: orgId,
        item_id: values.itemId,
        uom: values.uom,
        factor_to_stock: values.factorToStock,
        is_default: values.isDefault,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/items`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function listPurchaseUnitsAction(
  itemId: string,
): Promise<PurchaseUnitRow[]> {
  return listPurchaseUnits(itemId);
}

export async function deletePurchaseUnitAction(
  propertyId: string,
  unitId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("item_purchase_units")
    .delete()
    .eq("id", unitId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/items`);
  return { ok: true, data: { id: unitId } };
}

// 5. Warehouses
export async function saveWarehouseAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = warehouseSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }

  const { propertyId, id, ...values } = parsed.data;
  const supabase = await createClient();

  if (id) {
    const { error } = await supabase
      .from("warehouses")
      .update({
        code: values.code,
        name: values.name,
        kind: values.kind,
        outlet_id: values.outletId || null,
      })
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/warehouses`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("warehouses")
      .insert({
        property_id: propertyId,
        code: values.code,
        name: values.name,
        kind: values.kind,
        outlet_id: values.outletId || null,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/warehouses`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteWarehouseAction(
  propertyId: string,
  warehouseId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("warehouses")
    .delete()
    .eq("id", warehouseId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/warehouses`);
  return { ok: true, data: { id: warehouseId } };
}

// 6. Rooms & Room Types
export async function saveRoomTypeAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = roomTypeSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const supabase = await createClient();

  if (id) {
    const { error } = await supabase
      .from("room_types")
      .update({
        code: values.code,
        name: values.name,
        max_guests: values.maxGuests ?? null,
      })
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/rooms`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("room_types")
      .insert({
        property_id: propertyId,
        code: values.code,
        name: values.name,
        max_guests: values.maxGuests ?? null,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/rooms`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function saveRoomAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = roomSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const supabase = await createClient();

  if (id) {
    const { error } = await supabase
      .from("rooms")
      .update({
        room_no: values.roomNo,
        floor: values.floor || null,
        room_type_id: values.roomTypeId,
      })
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/rooms`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("rooms")
      .insert({
        property_id: propertyId,
        room_no: values.roomNo,
        floor: values.floor || null,
        room_type_id: values.roomTypeId,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/rooms`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteRoomAction(
  propertyId: string,
  roomId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase.from("rooms").delete().eq("id", roomId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/rooms`);
  return { ok: true, data: { id: roomId } };
}

// 7. Outlets & Outlet Types
export async function saveOutletTypeAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = outletTypeSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: "Không xác định được tổ chức." };

  const supabase = await createClient();
  if (id) {
    const { error } = await supabase
      .from("outlet_types")
      .update({
        code: values.code,
        name: values.name,
      })
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/outlets`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("outlet_types")
      .insert({
        org_id: orgId,
        code: values.code,
        name: values.name,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/outlets`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function saveOutletAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = outletSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const supabase = await createClient();

  if (id) {
    const { error } = await supabase
      .from("outlets")
      .update({
        code: values.code,
        name: values.name,
        outlet_type_id: values.outletTypeId,
        cost_center_id: values.costCenterId || null,
      })
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/outlets`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("outlets")
      .insert({
        property_id: propertyId,
        code: values.code,
        name: values.name,
        outlet_type_id: values.outletTypeId,
        cost_center_id: values.costCenterId || null,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/outlets`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteOutletAction(
  propertyId: string,
  outletId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase.from("outlets").delete().eq("id", outletId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/outlets`);
  return { ok: true, data: { id: outletId } };
}

// 8. Expense Categories
export async function saveExpenseCategoryAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = expenseCategorySaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: "Không xác định được tổ chức." };

  const supabase = await createClient();
  if (id) {
    const { error } = await supabase
      .from("expense_categories")
      .update({
        code: values.code,
        name: values.name,
        usali_line: values.usaliLine || null,
        parent_id: values.parentId || null,
      })
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/expense-categories`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("expense_categories")
      .insert({
        org_id: orgId,
        code: values.code,
        name: values.name,
        usali_line: values.usaliLine || null,
        parent_id: values.parentId || null,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/expense-categories`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteExpenseCategoryAction(
  propertyId: string,
  categoryId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("expense_categories")
    .delete()
    .eq("id", categoryId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/expense-categories`);
  return { ok: true, data: { id: categoryId } };
}
