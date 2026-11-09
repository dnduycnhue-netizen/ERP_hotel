import "server-only";

import { createClient } from "@/lib/supabase/server";

export async function getPropertyOrgId(
  propertyId: string,
): Promise<string | null> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("properties")
    .select("org_id")
    .eq("id", propertyId)
    .single();
  return data?.org_id ?? null;
}

export type ItemRow = {
  id: string;
  code: string;
  name: string;
  name_norm: string;
  name_en: string | null;
  group_id: string;
  group_name?: string;
  stock_uom: string;
  recipe_uom: string | null;
  stock_to_recipe: number | null;
  is_key_item: boolean;
  abc_class: string | null;
  track_lot: boolean;
  shelf_life_days: number | null;
  storage_condition: string | null;
  vat_rate: number | null;
  allowed_channels: string[];
  tare_g: number | null;
  density_g_ml: number | null;
  is_temp: boolean;
  status: string;
  created_at: string;
  updated_at: string;
};

export async function listItems({
  propertyId,
  search,
  groupId,
  isTemp,
  missingConversion,
  isKeyItem,
  page = 1,
  pageSize = 20,
}: {
  propertyId: string;
  search?: string;
  groupId?: string;
  isTemp?: boolean;
  missingConversion?: boolean;
  isKeyItem?: boolean;
  page?: number;
  pageSize?: number;
}): Promise<{ items: ItemRow[]; total: number }> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { items: [], total: 0 };

  const supabase = await createClient();
  let query = supabase
    .from("items")
    .select(
      `
      id, code, name, name_norm, name_en, group_id, stock_uom, recipe_uom,
      stock_to_recipe, is_key_item, abc_class, track_lot, shelf_life_days,
      storage_condition, vat_rate, allowed_channels, tare_g, density_g_ml,
      is_temp, status, created_at, updated_at,
      group:item_groups(name)
    `,
      { count: "exact" },
    )
    .eq("org_id", orgId);

  if (search && search.trim()) {
    const term = `%${search.trim()}%`;
    query = query.or(`name.ilike.${term},code.ilike.${term}`);
  }

  if (groupId) {
    query = query.eq("group_id", groupId);
  }

  if (isTemp !== undefined) {
    query = query.eq("is_temp", isTemp);
  }

  if (isKeyItem !== undefined) {
    query = query.eq("is_key_item", isKeyItem);
  }

  if (missingConversion) {
    query = query.not("recipe_uom", "is", null).is("stock_to_recipe", null);
  }

  const from = (page - 1) * pageSize;
  const to = from + pageSize - 1;

  query = query.order("code", { ascending: true }).range(from, to);

  const { data, count, error } = await query;
  if (error || !data) {
    return { items: [], total: 0 };
  }

  type RawItemResult = {
    id: string;
    code: string;
    name: string;
    name_norm: string;
    name_en: string | null;
    group_id: string;
    stock_uom: string;
    recipe_uom: string | null;
    stock_to_recipe: number | null;
    is_key_item: boolean;
    abc_class: string | null;
    track_lot: boolean;
    shelf_life_days: number | null;
    storage_condition: string | null;
    vat_rate: number | null;
    allowed_channels: string[] | null;
    tare_g: number | null;
    density_g_ml: number | null;
    is_temp: boolean;
    status: string;
    created_at: string;
    updated_at: string;
    group: { name: string } | null;
  };

  const items: ItemRow[] = (data as unknown as RawItemResult[]).map((row) => ({
    id: row.id,
    code: row.code,
    name: row.name,
    name_norm: row.name_norm,
    name_en: row.name_en,
    group_id: row.group_id,
    group_name: row.group?.name,
    stock_uom: row.stock_uom,
    recipe_uom: row.recipe_uom,
    stock_to_recipe: row.stock_to_recipe ? Number(row.stock_to_recipe) : null,
    is_key_item: row.is_key_item,
    abc_class: row.abc_class,
    track_lot: row.track_lot,
    shelf_life_days: row.shelf_life_days,
    storage_condition: row.storage_condition,
    vat_rate: row.vat_rate ? Number(row.vat_rate) : null,
    allowed_channels: row.allowed_channels ?? ["contract", "market"],
    tare_g: row.tare_g ? Number(row.tare_g) : null,
    density_g_ml: row.density_g_ml ? Number(row.density_g_ml) : null,
    is_temp: row.is_temp,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at,
  }));

  return { items, total: count ?? 0 };
}

export type ItemGroupRow = {
  id: string;
  code_prefix: string;
  name: string;
  kind: string;
  parent_id: string | null;
};

export async function listItemGroups(
  propertyId: string,
): Promise<ItemGroupRow[]> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return [];

  const supabase = await createClient();
  const { data } = await supabase
    .from("item_groups")
    .select("id, code_prefix, name, kind, parent_id")
    .eq("org_id", orgId)
    .order("code_prefix", { ascending: true });

  return data ?? [];
}

export type UomRow = {
  code: string;
  name_vi: string;
};

export async function listUoms(): Promise<UomRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("uoms")
    .select("code, name_vi")
    .order("code", { ascending: true });

  return data ?? [];
}

export type PurchaseUnitRow = {
  id: string;
  item_id: string;
  uom: string;
  factor_to_stock: number;
  is_default: boolean;
};

export async function listPurchaseUnits(
  itemId: string,
): Promise<PurchaseUnitRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("item_purchase_units")
    .select("id, item_id, uom, factor_to_stock, is_default")
    .eq("item_id", itemId)
    .order("is_default", { ascending: false });

  return (
    data?.map((row) => ({
      ...row,
      factor_to_stock: Number(row.factor_to_stock),
    })) ?? []
  );
}

export type WarehouseRow = {
  id: string;
  property_id: string;
  code: string;
  name: string;
  kind: string;
  outlet_id: string | null;
  outlet_name?: string;
};

export async function listWarehouses(
  propertyId: string,
): Promise<WarehouseRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("warehouses")
    .select(
      "id, property_id, code, name, kind, outlet_id, outlet:outlets(name)",
    )
    .eq("property_id", propertyId)
    .order("code", { ascending: true });

  type RawWarehouseResult = {
    id: string;
    property_id: string;
    code: string;
    name: string;
    kind: string;
    outlet_id: string | null;
    outlet: { name: string } | null;
  };

  return (
    (data as unknown as RawWarehouseResult[])?.map((row) => ({
      id: row.id,
      property_id: row.property_id,
      code: row.code,
      name: row.name,
      kind: row.kind,
      outlet_id: row.outlet_id,
      outlet_name: row.outlet?.name,
    })) ?? []
  );
}

export type RoomTypeRow = {
  id: string;
  property_id: string;
  code: string;
  name: string;
  max_guests: number | null;
};

export async function listRoomTypes(
  propertyId: string,
): Promise<RoomTypeRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("room_types")
    .select("id, property_id, code, name, max_guests")
    .eq("property_id", propertyId)
    .order("code", { ascending: true });

  return data ?? [];
}

export type RoomRow = {
  id: string;
  property_id: string;
  room_no: string;
  floor: string | null;
  room_type_id: string;
  room_type_name?: string;
};

export async function listRooms(propertyId: string): Promise<RoomRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("rooms")
    .select(
      "id, property_id, room_no, floor, room_type_id, room_type:room_types(name)",
    )
    .eq("property_id", propertyId)
    .order("room_no", { ascending: true });

  type RawRoomResult = {
    id: string;
    property_id: string;
    room_no: string;
    floor: string | null;
    room_type_id: string;
    room_type: { name: string } | null;
  };

  return (
    (data as unknown as RawRoomResult[])?.map((row) => ({
      id: row.id,
      property_id: row.property_id,
      room_no: row.room_no,
      floor: row.floor,
      room_type_id: row.room_type_id,
      room_type_name: row.room_type?.name,
    })) ?? []
  );
}

export type OutletTypeRow = {
  id: string;
  org_id: string;
  code: string;
  name: string;
};

export async function listOutletTypes(
  propertyId: string,
): Promise<OutletTypeRow[]> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return [];

  const supabase = await createClient();
  const { data } = await supabase
    .from("outlet_types")
    .select("id, org_id, code, name")
    .eq("org_id", orgId)
    .order("code", { ascending: true });

  return data ?? [];
}

export type CostCenterRow = {
  id: string;
  org_id: string;
  code: string;
  name: string;
  usali_department: string | null;
};

export async function listCostCenters(
  propertyId: string,
): Promise<CostCenterRow[]> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return [];

  const supabase = await createClient();
  const { data } = await supabase
    .from("cost_centers")
    .select("id, org_id, code, name, usali_department")
    .eq("org_id", orgId)
    .order("code", { ascending: true });

  return data ?? [];
}

export type OutletRow = {
  id: string;
  property_id: string;
  code: string;
  name: string;
  outlet_type_id: string;
  outlet_type_name?: string;
  cost_center_id: string | null;
  cost_center_name?: string;
};

export async function listOutlets(propertyId: string): Promise<OutletRow[]> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("outlets")
    .select(
      "id, property_id, code, name, outlet_type_id, cost_center_id, outlet_type:outlet_types(name), cost_center:cost_centers(name)",
    )
    .eq("property_id", propertyId)
    .order("code", { ascending: true });

  type RawOutletResult = {
    id: string;
    property_id: string;
    code: string;
    name: string;
    outlet_type_id: string;
    cost_center_id: string | null;
    outlet_type: { name: string } | null;
    cost_center: { name: string } | null;
  };

  return (
    (data as unknown as RawOutletResult[])?.map((row) => ({
      id: row.id,
      property_id: row.property_id,
      code: row.code,
      name: row.name,
      outlet_type_id: row.outlet_type_id,
      outlet_type_name: row.outlet_type?.name,
      cost_center_id: row.cost_center_id,
      cost_center_name: row.cost_center?.name,
    })) ?? []
  );
}

export type ExpenseCategoryRow = {
  id: string;
  org_id: string;
  code: string;
  name: string;
  usali_line: string | null;
  parent_id: string | null;
};

export async function listExpenseCategories(
  propertyId: string,
): Promise<ExpenseCategoryRow[]> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return [];

  const supabase = await createClient();
  const { data } = await supabase
    .from("expense_categories")
    .select("id, org_id, code, name, usali_line, parent_id")
    .eq("org_id", orgId)
    .order("code", { ascending: true });

  return data ?? [];
}
