import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import { getPropertyOrgId } from "@/features/master/queries";
import { callMinibarRpc, type MinibarActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* Minibar — đọc trực tiếp `minibar_checks` / `minibar_check_lines` /  */
/* `minibar_price_list` / `rooms` / `items` / `stock_balances` (không  */
/* có RPC minibar_list/minibar_get; RLS SELECT-only thực thi ở tầng    */
/* dữ liệu). `database.types.ts` chưa có các bảng này nên ép kiểu có   */
/* chủ đích tại đúng những chỗ đọc dưới đây.                           */
/*                                                                     */
/* LƯU Ý QUYỀN ĐỌC (xem Q60/Q61):                                     */
/* - Tên/mã mặt hàng chỉ đọc được khi caller có `item.view` — lễ tân  */
/*   (front_desk) và chủ đầu tư/GM không có quyền này nên tên hàng     */
/*   trong phiếu kiểm trả về null; UI hiện dòng dự phòng thay vì tên.  */
/* - Tồn kho phòng chỉ đọc được khi caller có `stock.view_qty` (hoặc  */
/*   `stock.view_value`) — mẫu chỉ cấp cho thủ kho; màn văn phòng      */
/*   kiểm tra quyền trước rồi mới đọc (mẫu T-031), thiếu quyền thì     */
/*   hiện ghi chú thay vì bảng tồn.                                    */
/* ------------------------------------------------------------------ */

export type MinibarCheckStatus =
  "pending_charge" | "charged" | "waived" | "late_charge" | "written_off";

export type MinibarTrigger = "checkout" | "daily" | "audit";

/** 1 phiếu kiểm minibar trong danh sách. */
export type MinibarCheckRow = {
  id: string;
  org_id: string;
  property_id: string;
  room_id: string;
  room_no: string | null;
  room_floor: string | null;
  doc_no: string;
  business_date: string;
  trigger: MinibarTrigger;
  status: MinibarCheckStatus;
  total_amount: number;
  folio_no: string | null;
  checked_by: string | null;
  checked_at: string | null;
  charged_by: string | null;
  charged_at: string | null;
  waive_reason: string | null;
  waive_requested_by: string | null;
  waive_requested_at: string | null;
  waive_approved_by: string | null;
  waive_decided_at: string | null;
  late_note: string | null;
  write_off_reason: string | null;
  is_loss: boolean;
  created_at: string;
};

/** 1 dòng thiếu trong phiếu kiểm. `item_code`/`item_name` null khi caller không có `item.view` (xem Q60). */
export type MinibarCheckLineRow = {
  id: string;
  check_id: string;
  item_id: string;
  item_code: string | null;
  item_name: string | null;
  stock_uom: string | null;
  missing_qty: number;
  unit_price: number;
  amount: number;
  near_expiry: boolean;
};

/** Chi tiết 1 phiếu kiểm: phiếu + phòng + các dòng thiếu. */
export type MinibarCheckDetail = {
  check: MinibarCheckRow;
  lines: MinibarCheckLineRow[];
};

/** 1 mặt hàng nhóm minibar (phục vụ form kiểm / bổ sung / bảng giá). */
export type MinibarItemRow = {
  id: string;
  code: string;
  name: string;
  stock_uom: string;
  track_lot: boolean;
};

/** 1 dòng bảng giá minibar. */
export type MinibarPriceRow = {
  id: string;
  item_id: string;
  item_code: string | null;
  item_name: string | null;
  price: number;
  valid_from: string;
  valid_to: string | null;
};

/** 1 dòng tồn minibar của 1 phòng. */
export type RoomStockRow = {
  room_id: string;
  room_no: string;
  floor: string | null;
  item_id: string;
  item_code: string | null;
  item_name: string | null;
  stock_uom: string | null;
  qty: number;
};

/** 1 dòng thu hồi hàng sắp hết hạn (RPC `minibar_recall_list`). */
export type MinibarRecallRow = {
  room_no: string;
  item_id: string;
  item_code: string;
  lot_id: string;
  lot_no: string;
  expiry_date: string;
  days_left: number;
  qty: number;
};

/** Kết quả đối soát 1 ngày (RPC `minibar_reconcile`). */
export type MinibarReconcileResult = {
  property_id: string;
  date: string;
  recorded: number;
  charged: number;
  waived: number;
  late_charge: number;
  pending_today: number;
  pending_stale: number;
  diff: number;
  alert_id: string | null;
};

/** Quyền minibar của người gọi tại 1 property (qua RPC `my_permissions`). */
export type MinibarPerms = {
  canRequestCheck: boolean;
  canCheck: boolean;
  canConfirmCharge: boolean;
  canWaiveRequest: boolean;
  canWaiveApprove: boolean;
  canRefill: boolean;
  canPriceManage: boolean;
  canReconcile: boolean;
  canViewReport: boolean;
  canViewQty: boolean;
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

function toError(error: { message: string }): MinibarActionResult<never> {
  return {
    ok: false,
    error: getRpcErrorMessage(extractRpcCode(error.message)),
  };
}

/** Quyền minibar của người gọi tại 1 property. */
export async function getMinibarPerms(
  propertyId: string,
): Promise<MinibarPerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  return {
    canRequestCheck: perms.has("minibar.request_check"),
    canCheck: perms.has("minibar.check"),
    canConfirmCharge: perms.has("minibar.charge.confirm"),
    canWaiveRequest: perms.has("minibar.waive.request"),
    canWaiveApprove: perms.has("minibar.waive.approve"),
    canRefill: perms.has("minibar.refill"),
    canPriceManage: perms.has("minibar.price.manage"),
    canReconcile: perms.has("minibar.reconcile"),
    canViewReport: perms.has("report.view.rpt_minibar"),
    canViewQty: perms.has("stock.view_value") || perms.has("stock.view_qty"),
    canViewValue: perms.has("stock.view_value"),
  };
}

const CHECK_COLUMNS =
  "id, org_id, property_id, room_id, doc_no, business_date, trigger, status, total_amount, folio_no, checked_by, checked_at, charged_by, charged_at, waive_reason, waive_requested_by, waive_requested_at, waive_approved_by, waive_decided_at, late_note, write_off_reason, is_loss, created_at";

type RawCheckRow = Omit<MinibarCheckRow, "room_no" | "room_floor"> & {
  room: { room_no: string; floor: string | null } | null;
};

function toCheckRow(raw: RawCheckRow): MinibarCheckRow {
  const { room, ...rest } = raw;
  return {
    ...rest,
    room_no: room?.room_no ?? null,
    room_floor: room?.floor ?? null,
  };
}

/** Danh sách phiếu kiểm minibar của 1 property (mới nhất trước). */
export async function listMinibarChecks(
  propertyId: string,
  status: MinibarCheckStatus | null,
): Promise<MinibarActionResult<MinibarCheckRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("minibar_checks")
    .select(`${CHECK_COLUMNS}, room:rooms(room_no, floor)`)
    .eq("property_id", propertyId)
    .order("business_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(100);
  if (status) query = query.eq("status", status);
  const { data, error } = await query;
  if (error) return toError(error);
  return {
    ok: true,
    data: ((data ?? []) as unknown as RawCheckRow[]).map(toCheckRow),
  };
}

/** Phiếu kiểm đang mở (`pending_charge`) của 1 phòng, nếu có. */
export async function getOpenCheckForRoom(
  roomId: string,
): Promise<MinibarActionResult<MinibarCheckRow | null>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("minibar_checks")
    .select(`${CHECK_COLUMNS}, room:rooms(room_no, floor)`)
    .eq("room_id", roomId)
    .eq("status", "pending_charge")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error) return toError(error);
  return {
    ok: true,
    data: data ? toCheckRow(data as unknown as RawCheckRow) : null,
  };
}

/** 1 phiếu kiểm + các dòng thiếu (kèm tên hàng khi caller có `item.view`). */
export async function getMinibarCheck(
  checkId: string,
): Promise<MinibarActionResult<MinibarCheckDetail>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("minibar_checks")
    .select(`${CHECK_COLUMNS}, room:rooms(room_no, floor)`)
    .eq("id", checkId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: false, error: getRpcErrorMessage(null) };
  const check = toCheckRow(data as unknown as RawCheckRow);
  const { data: linesData, error: linesError } = await client
    .from("minibar_check_lines")
    .select(
      "id, check_id, item_id, missing_qty, unit_price, amount, near_expiry, item:items(code, name, stock_uom)",
    )
    .eq("check_id", checkId)
    .order("created_at", { ascending: true });
  if (linesError) return toError(linesError);
  const lines = (
    (linesData ?? []) as unknown as Array<{
      id: string;
      check_id: string;
      item_id: string;
      missing_qty: number;
      unit_price: number;
      amount: number;
      near_expiry: boolean;
      item: { code: string; name: string; stock_uom: string } | null;
    }>
  ).map((l) => ({
    id: l.id,
    check_id: l.check_id,
    item_id: l.item_id,
    item_code: l.item?.code ?? null,
    item_name: l.item?.name ?? null,
    stock_uom: l.item?.stock_uom ?? null,
    missing_qty: l.missing_qty,
    unit_price: l.unit_price,
    amount: l.amount,
    near_expiry: l.near_expiry,
  }));
  return { ok: true, data: { check, lines } };
}

/** Các mặt hàng nhóm `minibar` của tổ chức (còn dùng được, không phải mã tạm). */
export async function listMinibarItems(
  propertyId: string,
): Promise<MinibarActionResult<MinibarItemRow[]>> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: true, data: [] };
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("items")
    .select("id, code, name, stock_uom, track_lot, item_groups!inner(kind)")
    .eq("org_id", orgId)
    .eq("is_temp", false)
    .neq("status", "merged")
    .eq("item_groups.kind", "minibar")
    .order("code", { ascending: true });
  if (error) return toError(error);
  return {
    ok: true,
    data: ((data ?? []) as unknown as MinibarItemRow[]).map((i) => ({
      id: i.id,
      code: i.code,
      name: i.name,
      stock_uom: i.stock_uom,
      track_lot: i.track_lot,
    })),
  };
}

/** Bảng giá minibar của 1 property (mốc hiệu lực mới nhất trước). */
export async function listMinibarPrices(
  propertyId: string,
): Promise<MinibarActionResult<MinibarPriceRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("minibar_price_list")
    .select("id, item_id, price, valid_from, valid_to, item:items(code, name)")
    .eq("property_id", propertyId)
    .order("valid_from", { ascending: false })
    .limit(200);
  if (error) return toError(error);
  const rows = (
    (data ?? []) as unknown as Array<{
      id: string;
      item_id: string;
      price: number;
      valid_from: string;
      valid_to: string | null;
      item: { code: string; name: string } | null;
    }>
  ).map((r) => ({
    id: r.id,
    item_id: r.item_id,
    item_code: r.item?.code ?? null,
    item_name: r.item?.name ?? null,
    price: r.price,
    valid_from: r.valid_from,
    valid_to: r.valid_to,
  }));
  return { ok: true, data: rows };
}

/**
 * Tồn minibar từng phòng (kho `minibar_room`).
 * Chỉ đọc khi caller có `stock.view_qty`/`stock.view_value` (mẫu T-031);
 * thiếu quyền trả mảng rỗng + cờ `canViewQty=false` để UI hiện ghi chú.
 */
export async function getRoomStocks(
  propertyId: string,
): Promise<MinibarActionResult<{ rows: RoomStockRow[]; canViewQty: boolean }>> {
  const supabase = await createClient();
  const perms = await getMinibarPerms(propertyId);
  if (!perms.canViewQty) {
    return { ok: true, data: { rows: [], canViewQty: false } };
  }
  const client = untyped(supabase);
  const { data: warehouses, error: whError } = await client
    .from("warehouses")
    .select("id, room_id, room:rooms!warehouses_room_id_fkey(room_no, floor)")
    .eq("property_id", propertyId)
    .eq("kind", "minibar_room");
  if (whError) return toError(whError);
  const whList = (warehouses ?? []) as unknown as Array<{
    id: string;
    room_id: string | null;
    room: { room_no: string; floor: string | null } | null;
  }>;
  const whIds = whList.map((w) => w.id);
  if (whIds.length === 0) {
    return { ok: true, data: { rows: [], canViewQty: true } };
  }
  const { data: balances, error: balError } = await client
    .from("stock_balances")
    .select("warehouse_id, item_id, qty")
    .eq("property_id", propertyId)
    .in("warehouse_id", whIds)
    .gt("qty", 0)
    .order("warehouse_id", { ascending: true });
  if (balError) return toError(balError);
  const balList = (balances ?? []) as unknown as Array<{
    warehouse_id: string;
    item_id: string;
    qty: number;
  }>;
  const itemIds = [...new Set(balList.map((b) => b.item_id))];
  const itemsMap = new Map<
    string,
    { code: string; name: string; stock_uom: string }
  >();
  if (itemIds.length > 0) {
    const { data: items, error: itemsError } = await client
      .from("items")
      .select("id, code, name, stock_uom")
      .in("id", itemIds);
    if (itemsError) return toError(itemsError);
    for (const it of (items ?? []) as unknown as Array<{
      id: string;
      code: string;
      name: string;
      stock_uom: string;
    }>) {
      itemsMap.set(it.id, {
        code: it.code,
        name: it.name,
        stock_uom: it.stock_uom,
      });
    }
  }
  const whMap = new Map(whList.map((w) => [w.id, w]));
  const rows: RoomStockRow[] = balList
    .map((b) => {
      const wh = whMap.get(b.warehouse_id);
      if (!wh || !wh.room_id || !wh.room) return null;
      const item = itemsMap.get(b.item_id);
      return {
        room_id: wh.room_id,
        room_no: wh.room.room_no,
        floor: wh.room.floor,
        item_id: b.item_id,
        item_code: item?.code ?? null,
        item_name: item?.name ?? null,
        stock_uom: item?.stock_uom ?? null,
        qty: Number(b.qty),
      };
    })
    .filter((r): r is RoomStockRow => r !== null)
    .sort((a, b) => a.room_no.localeCompare(b.room_no));
  return { ok: true, data: { rows, canViewQty: true } };
}

/** Hàng minibar trong phòng sắp hết hạn (RPC `minibar_recall_list`). */
export async function getRecallList(
  propertyId: string,
  days: number,
): Promise<MinibarActionResult<MinibarRecallRow[]>> {
  const supabase = await createClient();
  const res = await callMinibarRpc<{
    ok: boolean;
    items: MinibarRecallRow[];
  }>(supabase, "minibar_recall_list", {
    p_property_id: propertyId,
    p_days: days,
  });
  if (!res.ok) return res;
  return { ok: true, data: res.data.items ?? [] };
}

/**
 * Báo cáo minibar 1 kỳ (đọc từ phiếu kiểm đã thu + dòng của chúng).
 * Nguồn số liệu duy nhất: `minibar_checks` status='charged' và
 * `minibar_check_lines` của chúng — KHÔNG dùng dữ liệu PMS (chưa tích
 * hợp), KHÔNG ước tính đêm phòng từ PMS. "Phòng đã kiểm thu" = số
 * phòng distinct có phiếu đã thu trong kỳ (ghi rõ trong UI).
 * Lavie nhận diện theo mã/tên chứa 'lavie' (quy ước mã ITM_LAVIE —
 * xem test T-035); Dasani KHÔNG nằm trong phiếu minibar (hàng
 * complimentary bị chặn ở submit_check) nên chỉ số Dasani không tính
 * được từ dữ liệu minibar — xem Q62.
 */
export type MinibarReport = {
  revenue: number;
  chargedChecks: number;
  roomsChecked: number;
  lavieQty: number;
  laviePerRoom: number | null;
  topItems: Array<{
    item_id: string;
    item_code: string | null;
    item_name: string | null;
    qty: number;
    amount: number;
  }>;
};

export async function getMinibarReport(
  propertyId: string,
  from: string,
  to: string,
): Promise<MinibarActionResult<MinibarReport>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data: checks, error } = await client
    .from("minibar_checks")
    .select("id, room_id, total_amount")
    .eq("property_id", propertyId)
    .eq("status", "charged")
    .gte("business_date", from)
    .lte("business_date", to);
  if (error) return toError(error);
  const checkList = (checks ?? []) as unknown as Array<{
    id: string;
    room_id: string;
    total_amount: number;
  }>;
  const revenue = checkList.reduce((s, c) => s + Number(c.total_amount), 0);
  const roomsChecked = new Set(checkList.map((c) => c.room_id)).size;
  const checkIds = checkList.map((c) => c.id);
  let lavieQty = 0;
  const topMap = new Map<
    string,
    {
      item_code: string | null;
      item_name: string | null;
      qty: number;
      amount: number;
    }
  >();
  if (checkIds.length > 0) {
    const { data: lines, error: linesError } = await client
      .from("minibar_check_lines")
      .select("check_id, item_id, missing_qty, amount, item:items(code, name)")
      .in("check_id", checkIds);
    if (linesError) return toError(linesError);
    for (const l of (lines ?? []) as unknown as Array<{
      check_id: string;
      item_id: string;
      missing_qty: number;
      amount: number;
      item: { code: string; name: string } | null;
    }>) {
      const code = l.item?.code ?? "";
      const name = l.item?.name ?? "";
      if (
        code.toLowerCase().includes("lavie") ||
        name.toLowerCase().includes("lavie")
      ) {
        lavieQty += Number(l.missing_qty);
      }
      const cur = topMap.get(l.item_id) ?? {
        item_code: l.item?.code ?? null,
        item_name: l.item?.name ?? null,
        qty: 0,
        amount: 0,
      };
      cur.qty += Number(l.missing_qty);
      cur.amount += Number(l.amount);
      topMap.set(l.item_id, cur);
    }
  }
  const topItems = [...topMap.entries()]
    .map(([item_id, v]) => ({ item_id, ...v }))
    .sort((a, b) => b.amount - a.amount)
    .slice(0, 10);
  return {
    ok: true,
    data: {
      revenue,
      chargedChecks: checkList.length,
      roomsChecked,
      lavieQty,
      laviePerRoom: roomsChecked > 0 ? lavieQty / roomsChecked : null,
      topItems,
    },
  };
}
