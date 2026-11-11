"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callHousekeepingRpc, type HousekeepingActionResult } from "./rpc";
import {
  roomSetupStandardDeleteSchema,
  roomSetupStandardSaveSchema,
  type RoomSetupStandardDeleteInput,
  type RoomSetupStandardSaveInput,
} from "./schemas";

export type RoomSetupStandardSaveResult = {
  ok: boolean;
  id: string;
  room_type_id: string;
  clean_type: string;
  item_id: string;
  qty: number;
  per_guest: boolean;
};

function validationError(
  issues: { message: string }[],
): HousekeepingActionResult<never> {
  return {
    ok: false,
    error: issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    code: null,
  };
}

function standardsPath(propertyId: string): string {
  return `/${propertyId}/housekeeping/standards`;
}

/**
 * Lưu (thêm/sửa) 1 dòng tiêu chuẩn phòng (RPC `room_setup_standard_set`,
 * 310000): upsert theo (room_type_id, clean_type, item_id, per_guest).
 * Sửa số lượng của dòng có sẵn = upsert cùng khóa; sửa khóa (loại
 * phòng/loại dọn/món hàng/theo khách) thì xóa dòng cũ rồi tạo mới
 * (xem StandardsManager).
 */
export async function saveStandardAction(
  input: RoomSetupStandardSaveInput,
): Promise<HousekeepingActionResult<RoomSetupStandardSaveResult>> {
  const parsed = roomSetupStandardSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callHousekeepingRpc<RoomSetupStandardSaveResult>(
    supabase,
    "room_setup_standard_set",
    {
      p_property_id: parsed.data.propertyId,
      p_room_type_id: parsed.data.roomTypeId,
      p_clean_type: parsed.data.cleanType,
      p_item_id: parsed.data.itemId,
      p_qty: parsed.data.qty,
      p_per_guest: parsed.data.perGuest,
    },
  );
  if (res.ok) {
    revalidatePath(standardsPath(parsed.data.propertyId));
  }
  return res;
}

/** Xóa 1 dòng tiêu chuẩn phòng (RPC `room_setup_standard_delete`, C7). */
export async function deleteStandardAction(
  input: RoomSetupStandardDeleteInput,
): Promise<HousekeepingActionResult<{ ok: boolean; id: string }>> {
  const parsed = roomSetupStandardDeleteSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callHousekeepingRpc<{ ok: boolean; id: string }>(
    supabase,
    "room_setup_standard_delete",
    {
      p_standard_id: parsed.data.standardId,
    },
  );
  if (res.ok) {
    revalidatePath(standardsPath(parsed.data.propertyId));
  }
  return res;
}
