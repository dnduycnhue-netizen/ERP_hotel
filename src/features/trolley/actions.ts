"use server";

import { createClient } from "@/lib/supabase/server";
import { callTrolleyRpc, type TrolleyActionResult } from "./rpc";
import {
  getTrolleyShift,
  listTrolleyParLevels,
  listTrolleyShifts,
  type TrolleyParRow,
  type TrolleyShiftDetail,
  type TrolleyShiftRow,
  type TrolleyShiftStatus,
} from "./queries";
import {
  trolleyShiftCloseSchema,
  trolleyShiftOpenSchema,
  type TrolleyShiftCloseInput,
  type TrolleyShiftOpenInput,
} from "./schemas";

export type TrolleyShiftOpenResult = {
  shift_id: string;
  opening_count_id: string;
  requisition_id: string | null;
  top_up_lines: number;
  top_up_note: string | null;
};

export type TrolleyShiftCloseResult = {
  shift_id: string;
  closing_count_id: string;
  purpose_issue_id: string | null;
  consumption_lines: number;
  surplus_lines: Array<{ item_id: string; surplus_qty: number }>;
};

function validationError(
  issues: { message: string }[],
): TrolleyActionResult<never> {
  return {
    ok: false,
    error: issues[0]?.message ?? "Dữ liệu không hợp lệ.",
    code: null,
  };
}

/**
 * Mở ca xe đẩy (RPC `trolley_shift_open`, T-034): đếm đầu ca (mù) +
 * sinh phiếu lĩnh bù tới par (nếu có kho tầng duy nhất + thiếu hàng).
 */
export async function openTrolleyShiftAction(
  input: TrolleyShiftOpenInput,
): Promise<TrolleyActionResult<TrolleyShiftOpenResult>> {
  const parsed = trolleyShiftOpenSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callTrolleyRpc<TrolleyShiftOpenResult>(
    supabase,
    "trolley_shift_open",
    {
      p_property_id: parsed.data.propertyId,
      p_trolley_wh: parsed.data.trolleyWh,
      p_counts: parsed.data.counts.map((c) => ({
        item_id: c.itemId,
        qty: c.qty,
      })),
      p_shift: parsed.data.shift,
      p_business_date: parsed.data.businessDate,
    },
  );
}

/**
 * Đóng ca xe đẩy (RPC `trolley_shift_close`, T-034): đếm cuối ca (mù) +
 * tính tiêu hao = đầu + lĩnh − cuối → purpose_issue 'housekeeping'
 * (ROOMS / GUEST_SUPPLIES); thừa thì clamp 0 + surplus_lines.
 */
export async function closeTrolleyShiftAction(
  input: TrolleyShiftCloseInput,
): Promise<TrolleyActionResult<TrolleyShiftCloseResult>> {
  const parsed = trolleyShiftCloseSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callTrolleyRpc<TrolleyShiftCloseResult>(
    supabase,
    "trolley_shift_close",
    {
      p_shift_id: parsed.data.shiftId,
      p_counts: parsed.data.counts.map((c) => ({
        item_id: c.itemId,
        qty: c.qty,
      })),
      p_rooms_done: parsed.data.roomsDone.map((r) => ({
        room_id: r.roomId,
        clean_type: r.cleanType,
        guests: r.guests ?? null,
      })),
    },
  );
}

/** Mức par của 1 xe đẩy (form mở ca tải khi đổi xe đẩy). */
export async function listTrolleyParLevelsAction(
  propertyId: string,
  trolleyWh: string,
): Promise<TrolleyActionResult<TrolleyParRow[]>> {
  return listTrolleyParLevels(propertyId, trolleyWh);
}

/** Chi tiết 1 ca (dùng khi đồng bộ lại sau khi ghi offline). */
export async function getTrolleyShiftAction(
  shiftId: string,
): Promise<TrolleyActionResult<TrolleyShiftDetail>> {
  return getTrolleyShift(shiftId);
}

/**
 * Tìm ca đang mở của 1 xe đẩy / ngày / tên ca — dùng khi đồng bộ lại
 * job mở ca bị mất phản hồi (ca có thể đã mở xong trên server).
 */
export async function listOpenTrolleyShiftAction(
  propertyId: string,
  trolleyWh: string,
  businessDate: string,
  shift: string,
): Promise<TrolleyActionResult<TrolleyShiftRow[]>> {
  return listTrolleyShifts(propertyId, {
    trolleyWh,
    businessDate,
    shift,
    status: "open" as TrolleyShiftStatus,
  });
}

export type { TrolleyShiftRow };
