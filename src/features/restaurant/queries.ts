import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import type { RestaurantActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* Nha hang (M06) — doc truc tiep qua RLS (mau T-041/T-042, khong co   */
/* RPC list/get); ghi chi qua RPC. `database.types.ts` chua co cac     */
/* bang nay nen ep kieu co chu dich tai dung nhung cho doc duoi day.   */
/*                                                                     */
/* LUU Y QUYEN DOC (policy SELECT cua migration 500000): bat ky ma    */
/* restaurant.* nao cung doc duoc recipes; buffet/banquet/sales theo  */
/* ma tuong ung (xem M06 §6).                                         */
/* ------------------------------------------------------------------ */

export type RecipeRow = {
  id: string;
  code: string;
  name: string;
  kind: "dish" | "buffet_batch" | "set_menu";
  group_name: string | null;
  yield_qty: number | null;
  yield_uom: string | null;
  portions_per_batch: number | null;
  diet_flags: string[];
  sale_price: number | null;
  is_active: boolean;
  notes: string | null;
  version_no: number | null;
  foodcost: number | null;
  has_unknown_cost: boolean;
};

export type RecipeLineRow = {
  id: string;
  item_id: string | null;
  sub_recipe_id: string | null;
  item_code: string | null;
  item_name: string | null;
  sub_recipe_code: string | null;
  sub_recipe_name: string | null;
  qty: number;
  uom: string;
  loss_pct: number;
  note: string | null;
};

export type RecipeDetail = RecipeRow & {
  lines: RecipeLineRow[];
};

export type BuffetSessionRow = {
  id: string;
  business_date: string;
  meal: "breakfast" | "lunch" | "dinner";
  guest_count: number;
  price_per_guest: number | null;
  status: "planned" | "open" | "closed" | "cancelled";
  cancel_reason: string | null;
  notes: string | null;
  dish_count: number;
};

export type BuffetSessionDishRow = {
  recipe_id: string;
  recipe_code: string;
  recipe_name: string;
  planned_qty: number;
  note: string | null;
};

export type BuffetSessionDetail = BuffetSessionRow & {
  dishes: BuffetSessionDishRow[];
};

export type DishSaleRow = {
  id: string;
  business_date: string;
  recipe_id: string | null;
  recipe_code: string | null;
  recipe_name: string | null;
  source: "manual" | "buffet" | "banquet";
  ref_id: string | null;
  qty: number;
  unit_price: number;
  amount: number;
  voided_at: string | null;
};

export type BanquetRow = {
  id: string;
  doc_no: string;
  customer_name: string;
  customer_phone: string | null;
  event_date: string;
  start_time: string;
  end_time: string;
  hall: string;
  tables_count: number;
  guests_count: number;
  deposit_amount: number;
  status: "new" | "confirmed" | "in_progress" | "completed" | "cancelled";
  cancel_reason: string | null;
  notes: string | null;
  dish_count: number;
};

export type BanquetDishRow = {
  recipe_id: string;
  recipe_code: string;
  recipe_name: string;
  qty: number;
  unit_price: number;
  note: string | null;
};

export type BanquetDetail = BanquetRow & {
  dishes: BanquetDishRow[];
};

export type KitchenToday = {
  ok: boolean;
  business_date: string;
  dishes: Array<{
    id: string;
    code: string;
    name: string;
    kind: string;
    group_name: string | null;
    sale_price: number | null;
    foodcost: number | null;
    has_unknown_cost: boolean;
  }>;
  buffet_sessions: Array<{
    id: string;
    meal: string;
    guest_count: number;
    price_per_guest: number | null;
    status: string;
    dishes: Array<{
      recipe_id: string;
      recipe_code: string;
      recipe_name: string;
      planned_qty: number;
    }>;
  }>;
  banquets: Array<{
    id: string;
    doc_no: string;
    customer_name: string;
    hall: string;
    start_time: string;
    end_time: string;
    guests_count: number;
    status: string;
    dishes: Array<{
      recipe_id: string;
      recipe_code: string;
      recipe_name: string;
      qty: number;
    }>;
  }>;
  prep: Array<{
    item_id: string;
    item_code: string;
    item_name: string;
    uom: string;
    total_qty: number;
  }>;
};

export type SalesSummary = {
  ok: boolean;
  from: string;
  to: string;
  totals: {
    qty: number;
    revenue: number;
    foodcost: number;
    gross_profit: number;
    has_unknown_cost: boolean;
  };
  by_day: Array<{ business_date: string; qty: number; revenue: number }>;
  by_dish: Array<{
    recipe_id: string | null;
    recipe_code: string | null;
    recipe_name: string;
    qty: number;
    revenue: number;
    foodcost: number | null;
    gross_profit: number | null;
  }>;
};

/** Quyền nhà hàng của người gọi tại 1 property (qua RPC `my_permissions`). */
export type RestaurantPerms = {
  canView: boolean;
  canManageDish: boolean;
  canRecordSale: boolean;
  canManageBuffet: boolean;
  canManageBanquet: boolean;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}

function toError(error: { message: string }): RestaurantActionResult<never> {
  return {
    ok: false,
    error: getRpcErrorMessage(extractRpcCode(error.message)),
  };
}

export async function getRestaurantPerms(
  propertyId: string,
): Promise<RestaurantPerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  const canManageDish = perms.has("restaurant.dish.manage");
  const canRecordSale = perms.has("restaurant.sale.record");
  const canManageBuffet = perms.has("restaurant.buffet.manage");
  const canManageBanquet = perms.has("restaurant.banquet.manage");
  return {
    canView:
      perms.has("restaurant.view") ||
      canManageDish ||
      canRecordSale ||
      canManageBuffet ||
      canManageBanquet,
    canManageDish,
    canRecordSale,
    canManageBuffet,
    canManageBanquet,
  };
}

async function getPropertyOrgId(propertyId: string): Promise<string | null> {
  const supabase = await createClient();
  const { data } = await supabase
    .from("properties")
    .select("org_id")
    .eq("id", propertyId)
    .maybeSingle();
  return (data as { org_id: string } | null)?.org_id ?? null;
}

type RawRecipeRow = {
  id: string;
  code: string;
  name: string;
  kind: string;
  group_name: string | null;
  yield_qty: number | null;
  yield_uom: string | null;
  portions_per_batch: number | null;
  diet_flags: string[] | null;
  sale_price: number | null;
  is_active: boolean;
  notes: string | null;
};

type FoodcostRow = {
  recipe_id: string;
  foodcost: number | null;
  has_unknown_cost: boolean;
};

async function getFoodcostMap(
  propertyId: string,
): Promise<Map<string, FoodcostRow>> {
  const supabase = await createClient();
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: FoodcostRow[] | null;
    error: { message: string } | null;
  }>;
  const { data } = await caller("recipe_foodcost_list", {
    p_property_id: propertyId,
  });
  return new Map((data ?? []).map((r) => [r.recipe_id, r]));
}

/** Danh sách món ăn (kèm version active + foodcost). */
export async function listRecipes(
  propertyId: string,
  opts: { kind?: string | null; search?: string | null } = {},
): Promise<RestaurantActionResult<RecipeRow[]>> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: true, data: [] };
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("recipes")
    .select(
      "id, code, name, kind, group_name, yield_qty, yield_uom, portions_per_batch, diet_flags, sale_price, is_active, notes",
    )
    .eq("org_id", orgId)
    .order("kind", { ascending: true })
    .order("name", { ascending: true })
    .limit(200);
  if (opts.kind) query = query.eq("kind", opts.kind);
  if (opts.search?.trim()) {
    const term = `%${opts.search.trim()}%`;
    query = query.or(`name.ilike.${term},code.ilike.${term}`);
  }
  const { data, error } = await query;
  if (error) return toError(error);
  const rows = (data ?? []) as unknown as RawRecipeRow[];

  const { data: versions } = await untyped(supabase)
    .from("recipe_versions")
    .select("recipe_id, version_no")
    .eq("org_id", orgId)
    .eq("status", "active");
  const versionMap = new Map(
    (
      (versions ?? []) as unknown as Array<{
        recipe_id: string;
        version_no: number;
      }>
    ).map((v) => [v.recipe_id, v.version_no]),
  );
  const foodcosts = await getFoodcostMap(propertyId);
  return {
    ok: true,
    data: rows.map((r) => ({
      ...r,
      kind: r.kind as RecipeRow["kind"],
      diet_flags: r.diet_flags ?? [],
      version_no: versionMap.get(r.id) ?? null,
      foodcost: foodcosts.get(r.id)?.foodcost ?? null,
      has_unknown_cost: foodcosts.get(r.id)?.has_unknown_cost ?? false,
    })),
  };
}

/** Chi tiết 1 món + version active + dòng định lượng. */
export async function getRecipe(
  propertyId: string,
  recipeId: string,
): Promise<RestaurantActionResult<RecipeDetail | null>> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: true, data: null };
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("recipes")
    .select(
      "id, code, name, kind, group_name, yield_qty, yield_uom, portions_per_batch, diet_flags, sale_price, is_active, notes",
    )
    .eq("org_id", orgId)
    .eq("id", recipeId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: true, data: null };
  const raw = data as unknown as RawRecipeRow;

  const { data: version } = await untyped(supabase)
    .from("recipe_versions")
    .select("id, version_no")
    .eq("org_id", orgId)
    .eq("recipe_id", recipeId)
    .eq("status", "active")
    .maybeSingle();
  const v = version as { id: string; version_no: number } | null;

  let lines: RecipeLineRow[] = [];
  if (v) {
    const { data: lineData } = await untyped(supabase)
      .from("recipe_lines")
      .select(
        "id, item_id, sub_recipe_id, qty, uom, loss_pct, note, item:items(code, name), sub_recipe:recipes(code, name)",
      )
      .eq("version_id", v.id)
      .order("created_at", { ascending: true });
    lines = (
      (lineData ?? []) as unknown as Array<{
        id: string;
        item_id: string | null;
        sub_recipe_id: string | null;
        qty: number;
        uom: string;
        loss_pct: number;
        note: string | null;
        item: { code: string; name: string } | null;
        sub_recipe: { code: string; name: string } | null;
      }>
    ).map((l) => ({
      id: l.id,
      item_id: l.item_id,
      sub_recipe_id: l.sub_recipe_id,
      item_code: l.item?.code ?? null,
      item_name: l.item?.name ?? null,
      sub_recipe_code: l.sub_recipe?.code ?? null,
      sub_recipe_name: l.sub_recipe?.name ?? null,
      qty: l.qty,
      uom: l.uom,
      loss_pct: l.loss_pct,
      note: l.note,
    }));
  }

  const foodcosts = await getFoodcostMap(propertyId);
  return {
    ok: true,
    data: {
      ...raw,
      kind: raw.kind as RecipeRow["kind"],
      diet_flags: raw.diet_flags ?? [],
      version_no: v?.version_no ?? null,
      foodcost: foodcosts.get(raw.id)?.foodcost ?? null,
      has_unknown_cost: foodcosts.get(raw.id)?.has_unknown_cost ?? false,
      lines,
    },
  };
}

/** Màn bếp hôm nay (RPC `restaurant_kitchen_today`). */
export async function getKitchenToday(
  propertyId: string,
  businessDate: string,
): Promise<RestaurantActionResult<KitchenToday>> {
  const supabase = await createClient();
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: KitchenToday | null;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller("restaurant_kitchen_today", {
    p_property_id: propertyId,
    p_business_date: businessDate,
  });
  if (error) return toError(error);
  return { ok: true, data: data as KitchenToday };
}

/** Danh sách phiên buffet trong khoảng ngày. */
export async function listBuffetSessions(
  propertyId: string,
  from: string,
  to: string,
): Promise<RestaurantActionResult<BuffetSessionRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("buffet_sessions")
    .select(
      "id, business_date, meal, guest_count, price_per_guest, status, cancel_reason, notes, dishes:buffet_session_dishes(id)",
    )
    .eq("property_id", propertyId)
    .gte("business_date", from)
    .lte("business_date", to)
    .order("business_date", { ascending: false })
    .order("meal", { ascending: true })
    .limit(100);
  if (error) return toError(error);
  return {
    ok: true,
    data: (
      (data ?? []) as unknown as Array<
        Omit<BuffetSessionRow, "dish_count"> & {
          dishes: Array<{ id: string }>;
        }
      >
    ).map((s) => ({
      ...s,
      meal: s.meal as BuffetSessionRow["meal"],
      status: s.status as BuffetSessionRow["status"],
      dish_count: s.dishes?.length ?? 0,
    })),
  };
}

/** Chi tiết 1 phiên buffet + món trong phiên. */
export async function getBuffetSession(
  propertyId: string,
  sessionId: string,
): Promise<RestaurantActionResult<BuffetSessionDetail | null>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("buffet_sessions")
    .select(
      "id, business_date, meal, guest_count, price_per_guest, status, cancel_reason, notes",
    )
    .eq("property_id", propertyId)
    .eq("id", sessionId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: true, data: null };
  const raw = data as unknown as Omit<BuffetSessionRow, "dish_count">;
  const { data: dishData } = await untyped(supabase)
    .from("buffet_session_dishes")
    .select("recipe_id, planned_qty, note, recipe:recipes(code, name)")
    .eq("session_id", sessionId)
    .order("created_at", { ascending: true });
  const dishes = (
    (dishData ?? []) as unknown as Array<{
      recipe_id: string;
      planned_qty: number;
      note: string | null;
      recipe: { code: string; name: string } | null;
    }>
  ).map((d) => ({
    recipe_id: d.recipe_id,
    recipe_code: d.recipe?.code ?? "",
    recipe_name: d.recipe?.name ?? "",
    planned_qty: d.planned_qty,
    note: d.note,
  }));
  return {
    ok: true,
    data: {
      ...raw,
      meal: raw.meal as BuffetSessionRow["meal"],
      status: raw.status as BuffetSessionRow["status"],
      dish_count: dishes.length,
      dishes,
    },
  };
}

/** Dòng bán trong khoảng ngày (mới nhất trước). */
export async function listDishSales(
  propertyId: string,
  from: string,
  to: string,
): Promise<RestaurantActionResult<DishSaleRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("dish_sales")
    .select(
      "id, business_date, recipe_id, source, ref_id, qty, unit_price, amount, voided_at, recipe:recipes(code, name)",
    )
    .eq("property_id", propertyId)
    .gte("business_date", from)
    .lte("business_date", to)
    .order("business_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(200);
  if (error) return toError(error);
  return {
    ok: true,
    data: (
      (data ?? []) as unknown as Array<
        Omit<DishSaleRow, "recipe_code" | "recipe_name"> & {
          recipe: { code: string; name: string } | null;
        }
      >
    ).map((s) => ({
      ...s,
      source: s.source as DishSaleRow["source"],
      recipe_code: s.recipe?.code ?? null,
      recipe_name: s.recipe?.name ?? null,
    })),
  };
}

/** Tổng hợp doanh thu (RPC `restaurant_sales_summary`). */
export async function getSalesSummary(
  propertyId: string,
  from: string,
  to: string,
): Promise<RestaurantActionResult<SalesSummary>> {
  const supabase = await createClient();
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{
    data: SalesSummary | null;
    error: { message: string } | null;
  }>;
  const { data, error } = await caller("restaurant_sales_summary", {
    p_property_id: propertyId,
    p_from: from,
    p_to: to,
  });
  if (error) return toError(error);
  return { ok: true, data: data as SalesSummary };
}

/** Danh sách tiệc trong khoảng ngày. */
export async function listBanquets(
  propertyId: string,
  from: string,
  to: string,
  status?: string | null,
): Promise<RestaurantActionResult<BanquetRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("banquets")
    .select(
      "id, doc_no, customer_name, customer_phone, event_date, start_time, end_time, hall, tables_count, guests_count, deposit_amount, status, cancel_reason, notes, dishes:banquet_dishes(id)",
    )
    .eq("property_id", propertyId)
    .gte("event_date", from)
    .lte("event_date", to)
    .order("event_date", { ascending: true })
    .order("start_time", { ascending: true })
    .limit(100);
  if (status) query = query.eq("status", status);
  const { data, error } = await query;
  if (error) return toError(error);
  return {
    ok: true,
    data: (
      (data ?? []) as unknown as Array<
        Omit<BanquetRow, "dish_count"> & { dishes: Array<{ id: string }> }
      >
    ).map((b) => ({
      ...b,
      status: b.status as BanquetRow["status"],
      dish_count: b.dishes?.length ?? 0,
    })),
  };
}

/** Chi tiết 1 tiệc + thực đơn. */
export async function getBanquet(
  propertyId: string,
  banquetId: string,
): Promise<RestaurantActionResult<BanquetDetail | null>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("banquets")
    .select(
      "id, doc_no, customer_name, customer_phone, event_date, start_time, end_time, hall, tables_count, guests_count, deposit_amount, status, cancel_reason, notes",
    )
    .eq("property_id", propertyId)
    .eq("id", banquetId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: true, data: null };
  const raw = data as unknown as Omit<BanquetRow, "dish_count">;
  const { data: dishData } = await untyped(supabase)
    .from("banquet_dishes")
    .select("recipe_id, qty, unit_price, note, recipe:recipes(code, name)")
    .eq("banquet_id", banquetId)
    .order("created_at", { ascending: true });
  const dishes = (
    (dishData ?? []) as unknown as Array<{
      recipe_id: string;
      qty: number;
      unit_price: number;
      note: string | null;
      recipe: { code: string; name: string } | null;
    }>
  ).map((d) => ({
    recipe_id: d.recipe_id,
    recipe_code: d.recipe?.code ?? "",
    recipe_name: d.recipe?.name ?? "",
    qty: d.qty,
    unit_price: d.unit_price,
    note: d.note,
  }));
  return {
    ok: true,
    data: {
      ...raw,
      status: raw.status as BanquetRow["status"],
      dish_count: dishes.length,
      dishes,
    },
  };
}
