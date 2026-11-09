import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import { callCountRpc, type CountActionResult } from "./rpc";
import type { CountListFilterInput } from "./schemas";

/* ------------------------------------------------------------------ */
/* Đợt kiểm kê — đọc trực tiếp `stock_counts` + 2 view của T-032       */
/* (không có RPC count_list/count_get; RLS + view mù thực thi ở tầng    */
/* dữ liệu: v_count_sheet chỉ người đếm, v_count_result chỉ người có   */
/* count.view_variance và không phải người đếm).                        */
/* `database.types.ts` chưa có các bảng/view này nên ép kiểu có chủ     */
/* đích tại đúng những chỗ đọc dưới đây.                               */
/* ------------------------------------------------------------------ */

export type CountStatus =
  | "open"
  | "counting"
  | "recount"
  | "submitted"
  | "locked"
  | "adjusted"
  | "cancelled";

export type CountKind =
  "shift_key" | "monthly_full" | "cycle" | "trolley" | "minibar_audit";

export type CountLineFlag = "ok" | "recount" | "red";

/** 1 dòng trong danh sách đợt kiểm kê. */
export type CountRow = {
  id: string;
  org_id: string;
  property_id: string;
  warehouse_id: string;
  warehouse_name: string | null;
  doc_no: string;
  kind: CountKind;
  business_date: string;
  shift: string | null;
  status: CountStatus;
  counter_ids: string[];
  opened_by: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
};

/** 1 dòng trong phiếu đếm mù (view `v_count_sheet`). */
export type CountSheetRow = {
  count_id: string;
  warehouse_id: string;
  business_date: string;
  count_status: CountStatus;
  line_id: string;
  item_id: string;
  item_code: string;
  item_name: string;
  stock_uom: string;
  my_counted_qty: number | null;
  my_count_detail: unknown;
  has_counted: boolean;
  final_qty: number | null;
  flag: CountLineFlag | null;
  reason_code: string | null;
  explanation: string | null;
  photo_ids: string[] | null;
};

/** 1 dòng trong biên bản chênh lệch (view `v_count_result`). */
export type CountResultRow = {
  count_id: string;
  warehouse_id: string;
  business_date: string;
  count_status: CountStatus;
  line_id: string;
  item_id: string;
  item_code: string;
  item_name: string;
  stock_uom: string;
  count_detail: unknown;
  counted_qty_1: number | null;
  counted_qty_2: number | null;
  final_qty: number | null;
  book_qty: number | null;
  theoretical_qty: number | null;
  variance_qty: number | null;
  variance_pct: number | null;
  flag: CountLineFlag | null;
  reason_code: string | null;
  explanation: string | null;
  photo_ids: string[] | null;
};

/** 1 phiếu điều chỉnh chênh lệch (`count_adjustments`). */
export type CountAdjustmentRow = {
  id: string;
  count_id: string;
  status: "pending" | "approved";
  moves_posted: number | null;
  total_value: number | null;
  approved_by: string | null;
  approved_at: string | null;
};

/** 1 người được đếm tại kho (RPC `count_list_counters`, T-033). */
export type CountCounter = {
  id: string;
  employee_code: string;
  full_name: string;
};

/** Chi tiết vật tư phục vụ form ghi dòng đếm (đơn vị mua + cân chai). */
export type CountItemDetail = {
  id: string;
  code: string;
  name: string;
  stock_uom: string;
  tare_g: number | null;
  density_g_ml: number | null;
  purchase_units: Array<{
    uom: string;
    factor_to_stock: number;
    is_default: boolean;
  }>;
};

/** Quyền kiểm kê của người gọi tại 1 property (qua RPC `my_permissions`). */
export type CountPerms = {
  canOpen: boolean;
  canPerform: boolean;
  canViewVariance: boolean;
  canLock: boolean;
  canAdjustApprove: boolean;
  canViewValue: boolean;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}

function toError(error: { message: string }): CountActionResult<never> {
  return {
    ok: false,
    error: getRpcErrorMessage(extractRpcCode(error.message)),
  };
}

/** Danh sách đợt kiểm kê của 1 property (phân trang theo business_date). */
export async function listCounts(
  input: CountListFilterInput,
): Promise<CountActionResult<{ items: CountRow[]; total: number }>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  let query = client
    .from("stock_counts")
    .select(
      "id, org_id, property_id, warehouse_id, doc_no, kind, business_date, shift, status, counter_ids, opened_by, created_by, created_at, updated_at",
      { count: "exact" },
    )
    .eq("property_id", input.propertyId)
    .order("business_date", { ascending: false })
    .order("created_at", { ascending: false })
    .range(input.offset, input.offset + input.limit - 1);
  if (input.status) query = query.eq("status", input.status);
  if (input.warehouseId) query = query.eq("warehouse_id", input.warehouseId);
  const { data, error, count } = await query;
  if (error) return toError(error);
  const rows = (data ?? []) as unknown as Omit<CountRow, "warehouse_name">[];
  const warehouseIds = [...new Set(rows.map((r) => r.warehouse_id))];
  const names = new Map<string, string>();
  if (warehouseIds.length > 0) {
    const { data: whData } = await client
      .from("warehouses")
      .select("id, name")
      .in("id", warehouseIds);
    for (const wh of (whData ?? []) as Array<{ id: string; name: string }>) {
      names.set(wh.id, wh.name);
    }
  }
  return {
    ok: true,
    data: {
      items: rows.map((r) => ({
        ...r,
        warehouse_name: names.get(r.warehouse_id) ?? null,
      })),
      total: count ?? rows.length,
    },
  };
}

/** 1 đợt kiểm kê + tên kho (RLS `stock_counts` yêu cầu 1 trong 5 quyền count). */
export async function getCount(
  countId: string,
): Promise<CountActionResult<CountRow>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("stock_counts")
    .select(
      "id, org_id, property_id, warehouse_id, doc_no, kind, business_date, shift, status, counter_ids, opened_by, created_by, created_at, updated_at",
    )
    .eq("id", countId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: false, error: getRpcErrorMessage(null) };
  const row = data as unknown as Omit<CountRow, "warehouse_name">;
  const { data: whData } = await client
    .from("warehouses")
    .select("name")
    .eq("id", row.warehouse_id)
    .maybeSingle();
  return {
    ok: true,
    data: {
      ...row,
      warehouse_name: (whData as { name: string } | null)?.name ?? null,
    },
  };
}

/**
 * Phiếu đếm mù của 1 đợt (view `v_count_sheet`). Người không nằm trong
 * `counter_ids` nhận mảng rỗng (RLS ở view). TUYỆT ĐỐI không hiện
 * book_qty/theoretical_qty/variance ở UI đếm — view cũng không có các cột đó.
 */
export async function getCountSheet(
  countId: string,
): Promise<CountActionResult<CountSheetRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("v_count_sheet")
    .select(
      "count_id, warehouse_id, business_date, count_status, line_id, item_id, item_code, item_name, stock_uom, my_counted_qty, my_count_detail, has_counted, final_qty, flag, reason_code, explanation, photo_ids",
    )
    .eq("count_id", countId)
    .order("item_code", { ascending: true });
  if (error) return toError(error);
  return { ok: true, data: (data ?? []) as unknown as CountSheetRow[] };
}

/**
 * Biên bản chênh lệch của 1 đợt (view `v_count_result`). Người đếm hoặc
 * người không có `count.view_variance` nhận mảng rỗng (RLS ở view).
 */
export async function getCountResult(
  countId: string,
): Promise<CountActionResult<CountResultRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("v_count_result")
    .select(
      "count_id, warehouse_id, business_date, count_status, line_id, item_id, item_code, item_name, stock_uom, count_detail, counted_qty_1, counted_qty_2, final_qty, book_qty, theoretical_qty, variance_qty, variance_pct, flag, reason_code, explanation, photo_ids",
    )
    .eq("count_id", countId)
    .order("item_code", { ascending: true });
  if (error) return toError(error);
  return { ok: true, data: (data ?? []) as unknown as CountResultRow[] };
}

/** Phiếu điều chỉnh chênh lệch của 1 đợt (nếu đã khóa). */
export async function getCountAdjustment(
  countId: string,
): Promise<CountActionResult<CountAdjustmentRow | null>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("count_adjustments")
    .select(
      "id, count_id, status, moves_posted, total_value, approved_by, approved_at",
    )
    .eq("count_id", countId)
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) return toError(error);
  return {
    ok: true,
    data: (data ?? null) as unknown as CountAdjustmentRow | null,
  };
}

/** Người được đếm tại kho (RPC `count_list_counters`, T-033). */
export async function listCounters(
  propertyId: string,
  warehouseId: string,
): Promise<CountActionResult<CountCounter[]>> {
  const supabase = await createClient();
  return callCountRpc<CountCounter[]>(supabase, "count_list_counters", {
    p_property_id: propertyId,
    p_warehouse_id: warehouseId,
  });
}

/** Chi tiết vật tư phục vụ form ghi dòng đếm. */
export async function getCountItemDetail(
  itemId: string,
  orgId: string,
): Promise<CountActionResult<CountItemDetail>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("items")
    .select("id, code, name, stock_uom, tare_g, density_g_ml")
    .eq("id", itemId)
    .eq("org_id", orgId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: false, error: getRpcErrorMessage(null) };
  const item = data as unknown as Omit<CountItemDetail, "purchase_units">;
  const { data: unitsData, error: unitsError } = await client
    .from("item_purchase_units")
    .select("uom, factor_to_stock, is_default")
    .eq("item_id", itemId)
    .eq("org_id", orgId)
    .order("is_default", { ascending: false });
  if (unitsError) return toError(unitsError);
  return {
    ok: true,
    data: {
      ...item,
      purchase_units: (unitsData ??
        []) as unknown as CountItemDetail["purchase_units"],
    },
  };
}

/** Chi tiết vật tư cho các dòng đếm (1 query items + 1 query purchase units). */
export async function getCountSheetItems(
  orgId: string,
  itemIds: string[],
): Promise<CountActionResult<Record<string, CountItemDetail>>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  if (itemIds.length === 0) {
    return { ok: true, data: {} };
  }
  const { data, error } = await client
    .from("items")
    .select("id, code, name, stock_uom, tare_g, density_g_ml")
    .eq("org_id", orgId)
    .in("id", itemIds);
  if (error) return toError(error);
  const items = (data ?? []) as unknown as Omit<
    CountItemDetail,
    "purchase_units"
  >[];
  const { data: unitsData, error: unitsError } = await client
    .from("item_purchase_units")
    .select("item_id, uom, factor_to_stock, is_default")
    .eq("org_id", orgId)
    .in("item_id", itemIds)
    .order("is_default", { ascending: false });
  if (unitsError) return toError(unitsError);
  const unitsByItem = new Map<string, CountItemDetail["purchase_units"]>();
  for (const u of (unitsData ?? []) as Array<{
    item_id: string;
    uom: string;
    factor_to_stock: number;
    is_default: boolean;
  }>) {
    const list = unitsByItem.get(u.item_id) ?? [];
    list.push({
      uom: u.uom,
      factor_to_stock: u.factor_to_stock,
      is_default: u.is_default,
    });
    unitsByItem.set(u.item_id, list);
  }
  const result: Record<string, CountItemDetail> = {};
  for (const item of items) {
    result[item.id] = {
      ...item,
      purchase_units: unitsByItem.get(item.id) ?? [],
    };
  }
  return { ok: true, data: result };
}

/** Quyền kiểm kê của người gọi tại 1 property. */
export async function getCountPerms(propertyId: string): Promise<CountPerms> {
  const supabase = await createClient();
  const caller = supabase.rpc.bind(supabase) as unknown as (
    fn: string,
    args: Record<string, unknown>,
  ) => Promise<{ data: string[] | null; error: { message: string } | null }>;
  const { data } = await caller("my_permissions", { p_property: propertyId });
  const perms = new Set(data ?? []);
  return {
    canOpen: perms.has("count.open"),
    canPerform: perms.has("count.perform"),
    canViewVariance: perms.has("count.view_variance"),
    canLock: perms.has("count.lock"),
    canAdjustApprove: perms.has("count.adjust.approve"),
    canViewValue: perms.has("stock.view_value"),
  };
}
