import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import { getPropertyOrgId } from "@/features/master/queries";
import type { RoomCleanType } from "./schemas";
import type { HousekeepingActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* Tiêu chuẩn setup phòng — đọc trực tiếp `room_setup_standards` /    */
/* `items` (RLS SELECT-only thực thi ở tầng dữ liệu, migration         */
/* 310000 §5); ghi qua RPC `room_setup_standard_set` /                 */
/* `room_setup_standard_delete` (xem features/housekeeping/actions).   */
/* `database.types.ts` chưa có bảng này nên ép kiểu có chủ đích tại    */
/* đúng những chỗ đọc dưới đây (mẫu features/trolley/queries.ts).      */
/* ------------------------------------------------------------------ */

/** 1 dòng tiêu chuẩn setup phòng (kèm tên loại phòng + tên hàng). */
export type RoomSetupStandardRow = {
  id: string;
  property_id: string;
  room_type_id: string;
  room_type_code: string | null;
  room_type_name: string | null;
  clean_type: RoomCleanType;
  item_id: string;
  item_code: string | null;
  item_name: string | null;
  stock_uom: string | null;
  qty: number;
  per_guest: boolean;
};

/** 1 mặt hàng dùng được làm chuẩn setup (mã tạm bị loại ở tầng RPC). */
export type StandardItemRow = {
  id: string;
  code: string;
  name: string;
  stock_uom: string;
};

/** Quyền buồng phòng của người gọi tại 1 property. */
export type HousekeepingPerms = {
  canManageStandard: boolean;
  canOperateTrolley: boolean;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

function toError(error: { message: string }): HousekeepingActionResult<never> {
  const match = error.message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return {
    ok: false,
    error: getRpcErrorMessage(match ? match[0] : null),
    code: match ? match[0] : null,
  };
}

/** Toàn bộ tiêu chuẩn setup phòng của 1 property (mới nhất sau cùng). */
export async function listRoomSetupStandards(
  propertyId: string,
): Promise<HousekeepingActionResult<RoomSetupStandardRow[]>> {
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("room_setup_standards")
    .select(
      "id, property_id, room_type_id, clean_type, item_id, qty, per_guest, room_type:room_types(code, name), item:items(code, name, stock_uom)",
    )
    .eq("property_id", propertyId)
    .order("room_type_id", { ascending: true })
    .order("clean_type", { ascending: true })
    .order("item_id", { ascending: true });
  if (error) return toError(error);
  const rows = (data ?? []) as unknown as Array<{
    id: string;
    property_id: string;
    room_type_id: string;
    clean_type: RoomCleanType;
    item_id: string;
    qty: number;
    per_guest: boolean;
    room_type: { code: string; name: string } | null;
    item: { code: string; name: string; stock_uom: string } | null;
  }>;
  return {
    ok: true,
    data: rows.map((r) => ({
      id: r.id,
      property_id: r.property_id,
      room_type_id: r.room_type_id,
      room_type_code: r.room_type?.code ?? null,
      room_type_name: r.room_type?.name ?? null,
      clean_type: r.clean_type,
      item_id: r.item_id,
      item_code: r.item?.code ?? null,
      item_name: r.item?.name ?? null,
      stock_uom: r.item?.stock_uom ?? null,
      qty: r.qty,
      per_guest: r.per_guest,
    })),
  };
}

/**
 * Mặt hàng của org (không phải mã tạm, chưa bị gộp) để chọn khi tạo
 * chuẩn setup. Không lọc theo nhóm hàng — M07 cho phép mọi nhóm vật
 * tư làm chuẩn setup (amenity, complimentary, collateral, linen…).
 */
export async function listStandardItems(
  propertyId: string,
): Promise<HousekeepingActionResult<StandardItemRow[]>> {
  const orgId = await getPropertyOrgId(propertyId);
  if (!orgId) return { ok: true, data: [] };
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("items")
    .select("id, code, name, stock_uom")
    .eq("org_id", orgId)
    .eq("is_temp", false)
    .neq("status", "merged")
    .order("code", { ascending: true });
  if (error) return toError(error);
  return { ok: true, data: (data ?? []) as unknown as StandardItemRow[] };
}

/** Quyền buồng phòng của người gọi tại 1 property. */
export async function getHousekeepingPerms(
  propertyId: string,
): Promise<HousekeepingPerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  return {
    canManageStandard: perms.has("hk.standard.manage"),
    canOperateTrolley: perms.has("hk.trolley.operate"),
  };
}
