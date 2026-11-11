"use server";
import { vi } from "@/i18n/vi";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import {
  getPropertyOrgId,
  listPurchaseUnits,
  searchMergeTargets,
  type PurchaseUnitRow,
  type AssessmentWarning,
  type MergeTargetRow,
  listSupplierBankAccounts,
  type SupplierBankAccountRow,
  listPriceAgreementLines,
  type PriceAgreementLineRow,
} from "./queries";
import { callMasterRpc } from "./rpc";
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
  supplierSaveSchema,
  supplierDecisionSchema,
  supplierSetStatusSchema,
  supplierBankRequestSchema,
  supplierBankDecisionSchema,
  priceAgreementSaveSchema,
  priceAgreementLineSaveSchema,
  ceilingPriceSaveSchema,
  tempItemCreateSchema,
  itemMergeSchema,
  mergeTargetSearchSchema,
} from "./schemas";

export type MasterActionResult<T = unknown> =
  { ok: true; data: T } | { ok: false; error: string };

function mapDbError(error: unknown): string {
  if (!error) return vi.common.unknownError;

  const errObj =
    typeof error === "object" && error !== null
      ? (error as Record<string, unknown>)
      : {};
  const code = typeof errObj.code === "string" ? errObj.code : "";
  const msg = typeof errObj.message === "string" ? errObj.message : "";

  if (code === "42501" || msg.includes("ERR_FORBIDDEN")) {
    return vi.common.notAuthorized;
  }

  if (code === "23505") {
    if (msg.includes("name_norm")) {
      return vi.master.itemNameExists;
    }
    if (msg.includes("account_no")) {
      return vi.master.bankAccountExists;
    }
    if (msg.includes("code")) {
      return vi.master.codeExists;
    }
    if (msg.includes("room_no")) {
      return vi.master.roomNumberExists;
    }
    return vi.master.duplicateRecord;
  }

  if (code === "23503") {
    return vi.master.deleteBlockedByRelations;
  }

  if (msg.includes("ERR_SUPPLIER_HAS_BANK_ACCOUNTS")) {
    return vi.master.supplierHasBankAccountCannotDelete;
  }

  if (msg.includes("ERR_AGREEMENT_OVERLAP")) {
    return vi.master.overlappingAgreementExists;
  }

  if (msg.includes("ERR_SOD_")) {
    return vi.master.sodViolation;
  }

  if (msg.includes("ERR_INVALID_STATUS")) {
    return vi.master.recordInvalidStatus;
  }

  if (msg.includes("ERR_ITEM_HAS_STOCK_MOVES")) {
    return vi.master.itemHasTransactionsCannotDelete;
  }

  if (msg.includes("ERR_ITEM_UOM_CHANGE_FORBIDDEN")) {
    return vi.master.cannotChangeStockUomWithTransactions;
  }

  return msg || vi.master.saveFailed;
}

// 1. Items CRUD
export async function saveItemAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = itemSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }

  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) {
    return { ok: false, error: vi.master.propertyOrgUnknown };
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }

  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) {
    return { ok: false, error: vi.master.propertyOrgUnknown };
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }

  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: vi.master.orgUnknown };

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

export async function listSupplierBankAccountsAction(
  supplierId: string,
): Promise<SupplierBankAccountRow[]> {
  return listSupplierBankAccounts(supplierId);
}

export async function listPriceAgreementLinesAction(
  agreementId: string,
): Promise<PriceAgreementLineRow[]> {
  return listPriceAgreementLines(agreementId);
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: vi.master.orgUnknown };

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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
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
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: vi.master.orgUnknown };

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

// ---------------------------------------------------------------------------
// T-013: Nha cung cap + doi STK + hop dong khung + gia tran
// ---------------------------------------------------------------------------

// 9. Suppliers
export async function saveSupplierAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = supplierSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: vi.master.orgUnknown };

  const supabase = await createClient();
  const payload = {
    code: values.code,
    name: values.name,
    tax_code: values.taxCode || null,
    kind: values.kind,
    phone: values.phone || null,
    address: values.address || null,
    payment_terms_days: values.paymentTermsDays ?? null,
    food_safety_cert_until: values.foodSafetyCertUntil || null,
  };

  if (id) {
    const { error } = await supabase
      .from("suppliers")
      .update(payload)
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/suppliers`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("suppliers")
      .insert({ org_id: orgId, ...payload })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/suppliers`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteSupplierAction(
  propertyId: string,
  supplierId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("suppliers")
    .delete()
    .eq("id", supplierId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/suppliers`);
  return { ok: true, data: { id: supplierId } };
}

/** Tham dinh NCC (khong doi trang thai): tra ve danh sach canh bao. */
export async function submitSupplierAction(
  propertyId: string,
  supplierId: string,
): Promise<MasterActionResult<{ id: string; warnings: AssessmentWarning[] }>> {
  const supabase = await createClient();
  const res = await callMasterRpc<{
    ok: boolean;
    id: string;
    warnings: AssessmentWarning[];
  }>(supabase, "supplier_submit", {
    p_property_id: propertyId,
    p_supplier_id: supplierId,
  });
  if (!res.ok) return res;
  return {
    ok: true,
    data: { id: res.data.id, warnings: res.data.warnings ?? [] },
  };
}

export async function approveSupplierAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string; status: string }>> {
  const parsed = supplierDecisionSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{ ok: boolean; id: string; status: string }>(
    supabase,
    "supplier_approve",
    {
      p_property_id: parsed.data.propertyId,
      p_supplier_id: parsed.data.supplierId,
      p_approved: parsed.data.approved,
      p_reason: parsed.data.reason || null,
    },
  );
  if (!res.ok) return res;
  revalidatePath(`/${parsed.data.propertyId}/master/suppliers`);
  return { ok: true, data: { id: res.data.id, status: res.data.status } };
}

export async function setSupplierStatusAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string; status: string }>> {
  const parsed = supplierSetStatusSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{ ok: boolean; id: string; status: string }>(
    supabase,
    "supplier_set_status",
    {
      p_property_id: parsed.data.propertyId,
      p_supplier_id: parsed.data.supplierId,
      p_status: parsed.data.status,
      p_reason: parsed.data.reason,
    },
  );
  if (!res.ok) return res;
  revalidatePath(`/${parsed.data.propertyId}/master/suppliers`);
  return { ok: true, data: { id: res.data.id, status: res.data.status } };
}

// 10. Supplier bank accounts (doi STK 2 nguoi)
export async function requestBankAccountAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string; warnings: AssessmentWarning[] }>> {
  const parsed = supplierBankRequestSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{
    ok: boolean;
    id: string;
    warnings: AssessmentWarning[];
  }>(supabase, "supplier_bank_request", {
    p_property_id: parsed.data.propertyId,
    p_supplier_id: parsed.data.supplierId,
    p_bank_name: parsed.data.bankName,
    p_account_no: parsed.data.accountNo,
    p_account_name: parsed.data.accountName,
  });
  if (!res.ok) return res;
  revalidatePath(`/${parsed.data.propertyId}/master/suppliers`);
  return {
    ok: true,
    data: { id: res.data.id, warnings: res.data.warnings ?? [] },
  };
}

export async function approveBankAccountAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string; status: string }>> {
  const parsed = supplierBankDecisionSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{ ok: boolean; id: string; status: string }>(
    supabase,
    "supplier_bank_approve",
    {
      p_property_id: parsed.data.propertyId,
      p_bank_account_id: parsed.data.bankAccountId,
      p_approved: parsed.data.approved,
      p_reason: parsed.data.reason || null,
    },
  );
  if (!res.ok) return res;
  revalidatePath(`/${parsed.data.propertyId}/master/suppliers`);
  return { ok: true, data: { id: res.data.id, status: res.data.status } };
}

// 11. Price agreements (hop dong khung)
export async function savePriceAgreementAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = priceAgreementSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: vi.master.orgUnknown };

  const supabase = await createClient();
  const payload = {
    supplier_id: values.supplierId,
    valid_from: values.validFrom,
    valid_to: values.validTo,
    status: values.status,
  };

  if (id) {
    const { error } = await supabase
      .from("price_agreements")
      .update(payload)
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/prices`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("price_agreements")
      .insert({ org_id: orgId, ...payload })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/prices`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deletePriceAgreementAction(
  propertyId: string,
  agreementId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("price_agreements")
    .delete()
    .eq("id", agreementId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/prices`);
  return { ok: true, data: { id: agreementId } };
}

export async function savePriceAgreementLineAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = priceAgreementLineSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: vi.master.orgUnknown };

  const supabase = await createClient();
  const payload = {
    item_id: values.itemId,
    uom: values.uom,
    unit_price: values.unitPrice,
    warn_pct: values.warnPct ?? null,
    lock_pct: values.lockPct ?? null,
  };

  if (id) {
    const { error } = await supabase
      .from("price_agreement_lines")
      .update(payload)
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/prices`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("price_agreement_lines")
      .insert({
        org_id: orgId,
        agreement_id: values.agreementId,
        ...payload,
      })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/prices`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deletePriceAgreementLineAction(
  propertyId: string,
  lineId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("price_agreement_lines")
    .delete()
    .eq("id", lineId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/prices`);
  return { ok: true, data: { id: lineId } };
}

// 12. Ceiling prices (gia tran)
export async function saveCeilingPriceAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string }>> {
  const parsed = ceilingPriceSaveSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const { propertyId, id, ...values } = parsed.data;
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: false, error: vi.master.orgUnknown };

  const supabase = await createClient();
  const { data: userData } = await supabase.auth.getUser();
  const setBy = userData.user?.id;
  if (!setBy) return { ok: false, error: vi.common.notLoggedIn };

  const payload = {
    property_id: values.propertyScopeId || null,
    item_id: values.itemId,
    uom: values.uom,
    price: values.price,
    valid_from: values.validFrom,
    valid_to: values.validTo,
    set_by: setBy,
  };

  if (id) {
    const { error } = await supabase
      .from("ceiling_prices")
      .update(payload)
      .eq("id", id);
    if (error) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/prices`);
    return { ok: true, data: { id } };
  } else {
    const { data, error } = await supabase
      .from("ceiling_prices")
      .insert({ org_id: orgId, ...payload })
      .select("id")
      .single();
    if (error || !data) return { ok: false, error: mapDbError(error) };
    revalidatePath(`/${propertyId}/master/prices`);
    return { ok: true, data: { id: data.id } };
  }
}

export async function deleteCeilingPriceAction(
  propertyId: string,
  ceilingId: string,
): Promise<MasterActionResult<{ id: string }>> {
  const supabase = await createClient();
  const { error } = await supabase
    .from("ceiling_prices")
    .delete()
    .eq("id", ceilingId);
  if (error) return { ok: false, error: mapDbError(error) };
  revalidatePath(`/${propertyId}/master/prices`);
  return { ok: true, data: { id: ceilingId } };
}

// 12. Ma tam + gop ma (T-015)
export async function createTempItemAction(
  input: unknown,
): Promise<MasterActionResult<{ id: string; code: string }>> {
  const parsed = tempItemCreateSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{ ok: boolean; id: string; code: string }>(
    supabase,
    "item_create_temp",
    {
      p_property_id: parsed.data.propertyId,
      p_name: parsed.data.name,
      p_group_id: parsed.data.groupId,
      p_stock_uom: parsed.data.stockUom,
    },
  );
  if (!res.ok) return res;
  revalidatePath(`/${parsed.data.propertyId}/master/items`);
  return { ok: true, data: { id: res.data.id, code: res.data.code } };
}

export async function mergeItemAction(
  input: unknown,
): Promise<
  MasterActionResult<{ from_id: string; into_id: string; moved_count: number }>
> {
  const parsed = itemMergeSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const supabase = await createClient();
  const res = await callMasterRpc<{
    ok: boolean;
    from_id: string;
    into_id: string;
    moved_count: number;
  }>(supabase, "item_merge", {
    p_property_id: parsed.data.propertyId,
    p_from_id: parsed.data.fromId,
    p_into_id: parsed.data.intoId,
  });
  if (!res.ok) return res;
  revalidatePath(`/${parsed.data.propertyId}/master/items`);
  return {
    ok: true,
    data: {
      from_id: res.data.from_id,
      into_id: res.data.into_id,
      moved_count: res.data.moved_count,
    },
  };
}

export async function searchMergeTargetsAction(
  input: unknown,
): Promise<MasterActionResult<{ targets: MergeTargetRow[] }>> {
  const parsed = mergeTargetSearchSchema.safeParse(input);
  if (!parsed.success) {
    return {
      ok: false,
      error: parsed.error.issues[0]?.message ?? vi.common.invalidData,
    };
  }
  const targets = await searchMergeTargets(parsed.data);
  return { ok: true, data: { targets } };
}
