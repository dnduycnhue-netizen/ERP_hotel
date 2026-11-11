import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import { callTrolleyRpc, type TrolleyActionResult } from "./rpc";
import type { TrolleyCleanType, TrolleyShiftName } from "./schemas";

/* ------------------------------------------------------------------ */
/* Xe đẩy buồng phòng — đọc trực tiếp `trolley_shifts` /               */
/* `trolley_par_levels` / `rooms` (RLS SELECT-only thực thi ở tầng     */
/* dữ liệu) + RPC `trolley_shift_get` (390000) cho chi tiết ca.        */
/*                                                                      */
/* LƯU Ý QUYỀN ĐỌC: người buồng phòng KHÔNG đọc được `stock_counts` /  */
/* `stock_count_lines` (cần 1 trong 5 quyền count.*) và `purpose_issues`*/
/* (cần purpose_issue.post/reverse hoặc stock.view_qty) nên chi tiết   */
/* ca (số đếm đầu/cuối, phiếu tiêu hao) BẮT BUỘC đi qua RPC            */
/* SECURITY DEFINER `trolley_shift_get` — không đọc trực tiếp.         */
/* `database.types.ts` chưa có các bảng này nên ép kiểu có chủ đích    */
/* tại đúng những chỗ đọc dưới đây.                                    */
/* ------------------------------------------------------------------ */

export type TrolleyShiftStatus = "open" | "closed" | "cancelled";

/** 1 ca xe đẩy trong danh sách. */
export type TrolleyShiftRow = {
  id: string;
  org_id: string;
  property_id: string;
  trolley_warehouse_id: string;
  trolley_code: string | null;
  trolley_name: string | null;
  attendant_id: string;
  business_date: string;
  shift: string;
  status: TrolleyShiftStatus;
  requisition_id: string | null;
  purpose_issue_id: string | null;
  rooms_done: TrolleyRoomDone[];
  closed_by: string | null;
  closed_at: string | null;
  created_at: string;
};

/** 1 dòng mức par trên xe đẩy (KHÔNG hiện par_qty khi đếm — đếm mù). */
export type TrolleyParRow = {
  item_id: string;
  item_code: string;
  item_name: string;
  stock_uom: string;
  par_qty: number;
};

/** 1 dòng đếm (đầu/cuối ca) trả về từ `trolley_shift_get`. */
export type TrolleyCountLine = {
  item_id: string;
  item_code: string;
  item_name: string;
  stock_uom: string;
  qty: number;
};

/** 1 dòng tiêu hao của ca đã đóng. */
export type TrolleyConsumptionRow = {
  item_id: string;
  item_code: string;
  item_name: string;
  stock_uom: string;
  opening_qty: number;
  received_qty: number;
  closing_qty: number;
  consumed_qty: number;
  surplus_qty: number;
};

/** 1 phòng đã dọn trong ca (`rooms_done`). */
export type TrolleyRoomDone = {
  room_id: string;
  clean_type: TrolleyCleanType;
  guests?: number;
};

/** Chi tiết 1 ca xe đẩy (RPC `trolley_shift_get`). */
export type TrolleyShiftDetail = {
  shift: {
    id: string;
    org_id: string;
    property_id: string;
    trolley_warehouse_id: string;
    trolley_code: string | null;
    trolley_name: string | null;
    attendant_id: string;
    business_date: string;
    shift: string;
    status: TrolleyShiftStatus;
    opening_count_id: string | null;
    closing_count_id: string | null;
    rooms_done: TrolleyRoomDone[];
    requisition_id: string | null;
    requisition_doc_no: string | null;
    requisition_status: string | null;
    purpose_issue_id: string | null;
    purpose_issue_doc_no: string | null;
    closed_by: string | null;
    closed_at: string | null;
    created_at: string;
  };
  opening_counts: TrolleyCountLine[];
  /** null khi ca chưa đóng. */
  closing_counts: TrolleyCountLine[] | null;
  /** [] khi ca chưa đóng. */
  consumption: TrolleyConsumptionRow[];
};

/** 1 phòng của khách sạn (phục vụ chọn phòng đã dọn khi đóng ca). */
export type TrolleyRoomRow = {
  id: string;
  room_no: string;
  floor: string | null;
};

/** Quyền xe đẩy của người gọi tại 1 property. */
export type TrolleyPerms = {
  canOperate: boolean;
  canManageStandard: boolean;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

function toError(error: { message: string }): TrolleyActionResult<never> {
  const match = error.message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return {
    ok: false,
    error: getRpcErrorMessage(match ? match[0] : null),
    code: match ? match[0] : null,
  };
}

/** Danh sách ca xe đẩy của 1 property (mới nhất trước). */
export async function listTrolleyShifts(
  propertyId: string,
  filter?: {
    trolleyWh?: string;
    businessDate?: string;
    shift?: string;
    status?: TrolleyShiftStatus;
  },
  limit = 50,
): Promise<TrolleyActionResult<TrolleyShiftRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("trolley_shifts")
    .select(
      "id, org_id, property_id, trolley_warehouse_id, attendant_id, business_date, shift, status, requisition_id, purpose_issue_id, rooms_done, closed_by, closed_at, created_at, trolley_warehouse:warehouses(name, code)",
    )
    .eq("property_id", propertyId)
    .order("business_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(limit);
  if (filter?.trolleyWh)
    query = query.eq("trolley_warehouse_id", filter.trolleyWh);
  if (filter?.businessDate)
    query = query.eq("business_date", filter.businessDate);
  if (filter?.shift) query = query.eq("shift", filter.shift);
  if (filter?.status) query = query.eq("status", filter.status);
  const { data, error } = await query;
  if (error) return toError(error);
  const rows = (data ?? []) as unknown as Array<{
    id: string;
    org_id: string;
    property_id: string;
    trolley_warehouse_id: string;
    attendant_id: string;
    business_date: string;
    shift: string;
    status: TrolleyShiftStatus;
    requisition_id: string | null;
    purpose_issue_id: string | null;
    rooms_done: TrolleyRoomDone[];
    closed_by: string | null;
    closed_at: string | null;
    created_at: string;
    trolley_warehouse: { name: string; code: string } | null;
  }>;
  return {
    ok: true,
    data: rows.map((r) => ({
      id: r.id,
      org_id: r.org_id,
      property_id: r.property_id,
      trolley_warehouse_id: r.trolley_warehouse_id,
      trolley_code: r.trolley_warehouse?.code ?? null,
      trolley_name: r.trolley_warehouse?.name ?? null,
      attendant_id: r.attendant_id,
      business_date: r.business_date,
      shift: r.shift,
      status: r.status,
      requisition_id: r.requisition_id,
      purpose_issue_id: r.purpose_issue_id,
      rooms_done: Array.isArray(r.rooms_done) ? r.rooms_done : [],
      closed_by: r.closed_by,
      closed_at: r.closed_at,
      created_at: r.created_at,
    })),
  };
}

/** Mức par của 1 xe đẩy + tên/ĐVT vật tư (tên cần `item.view`). */
export async function listTrolleyParLevels(
  propertyId: string,
  trolleyWh: string,
): Promise<TrolleyActionResult<TrolleyParRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("trolley_par_levels")
    .select("item_id, par_qty, item:items(code, name, stock_uom)")
    .eq("property_id", propertyId)
    .eq("trolley_warehouse_id", trolleyWh)
    .order("item_id", { ascending: true });
  if (error) return toError(error);
  const rows = (data ?? []) as unknown as Array<{
    item_id: string;
    par_qty: number;
    item: { code: string; name: string; stock_uom: string } | null;
  }>;
  return {
    ok: true,
    data: rows
      .filter((r) => r.item !== null)
      .map((r) => ({
        item_id: r.item_id,
        item_code: (r.item as { code: string }).code,
        item_name: (r.item as { name: string }).name,
        stock_uom: (r.item as { stock_uom: string }).stock_uom,
        par_qty: r.par_qty,
      }))
      .sort((a, b) => a.item_code.localeCompare(b.item_code)),
  };
}

/** Chi tiết 1 ca xe đẩy (RPC `trolley_shift_get`, 390000). */
export async function getTrolleyShift(
  shiftId: string,
): Promise<TrolleyActionResult<TrolleyShiftDetail>> {
  const supabase = await createClient();
  return callTrolleyRpc<TrolleyShiftDetail>(supabase, "trolley_shift_get", {
    p_shift_id: shiftId,
  });
}

/** Danh sách phòng của 1 property (phục vụ chọn phòng đã dọn). */
export async function listTrolleyRooms(
  propertyId: string,
): Promise<TrolleyActionResult<TrolleyRoomRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("rooms")
    .select("id, room_no, floor")
    .eq("property_id", propertyId)
    .order("room_no", { ascending: true });
  if (error) return toError(error);
  return { ok: true, data: (data ?? []) as unknown as TrolleyRoomRow[] };
}

/** Quyền xe đẩy của người gọi tại 1 property. */
export async function getTrolleyPerms(
  propertyId: string,
): Promise<TrolleyPerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  return {
    canOperate: perms.has("hk.trolley.operate"),
    canManageStandard: perms.has("hk.standard.manage"),
  };
}

export type { TrolleyShiftName };
