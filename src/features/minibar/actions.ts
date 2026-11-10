"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callMinibarRpc, type MinibarActionResult } from "./rpc";
import {
  minibarConfirmChargeSchema,
  minibarDecideWaiveSchema,
  minibarMarkLateChargeSchema,
  minibarPriceSetSchema,
  minibarReconcileSchema,
  minibarRefillSchema,
  minibarRequestCheckSchema,
  minibarRequestWaiveSchema,
  minibarSubmitCheckSchema,
  minibarWriteOffSchema,
  type MinibarConfirmChargeInput,
  type MinibarDecideWaiveInput,
  type MinibarMarkLateChargeInput,
  type MinibarPriceSetInput,
  type MinibarReconcileInput,
  type MinibarRefillInput,
  type MinibarRequestCheckInput,
  type MinibarRequestWaiveInput,
  type MinibarSubmitCheckInput,
  type MinibarWriteOffInput,
} from "./schemas";
import type { MinibarReconcileResult, MinibarRecallRow } from "./queries";
import { getRecallList } from "./queries";

export type RequestCheckResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  existing: boolean;
  room_no: string;
};

export type SubmitCheckResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  total_amount: number;
  is_loss: boolean;
  duplicate: boolean;
};

export type ConfirmChargeResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  folio_no: string;
  total_amount: number;
};

export type WaiveResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  decision?: string;
};

export type RefillResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  lines: number;
  room_no: string;
};

export type PriceSetResult = {
  ok: boolean;
  id: string;
  item_id: string;
  price: number;
  valid_from: string;
  valid_to: string | null;
};

function validationError(
  issues: { message: string }[],
): MinibarActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? "Dữ liệu không hợp lệ." };
}

function frontdeskPath(propertyId: string): string {
  return `/${propertyId}/frontdesk/minibar`;
}

function frontdeskDetailPath(propertyId: string, checkId: string): string {
  return `/${propertyId}/frontdesk/minibar/${checkId}`;
}

function mobilePath(propertyId: string): string {
  return `/m/${propertyId}/minibar`;
}

function housekeepingPath(propertyId: string): string {
  return `/${propertyId}/housekeeping/minibar`;
}

/** Lễ tân yêu cầu kiểm minibar khi khách trả phòng (RPC `minibar_request_check`). */
export async function requestCheckAction(
  input: MinibarRequestCheckInput,
): Promise<MinibarActionResult<RequestCheckResult>> {
  const parsed = minibarRequestCheckSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<RequestCheckResult>(
    supabase,
    "minibar_request_check",
    {
      p_room_id: parsed.data.roomId,
      p_trigger: parsed.data.trigger,
    },
  );
  if (res.ok) {
    revalidatePath(frontdeskPath(parsed.data.propertyId));
    revalidatePath(mobilePath(parsed.data.propertyId));
  }
  return res;
}

/**
 * Buồng phòng nộp kết quả kiểm (RPC `minibar_submit_check`).
 * Idempotent theo `clientUuid`: gửi lại cùng UUID trả kết quả cũ,
 * không ghi trùng (mẫu T-023/T-025).
 */
export async function submitCheckAction(
  input: MinibarSubmitCheckInput,
): Promise<MinibarActionResult<SubmitCheckResult>> {
  const parsed = minibarSubmitCheckSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<SubmitCheckResult>(
    supabase,
    "minibar_submit_check",
    {
      p_check_id: parsed.data.checkId,
      p_lines: parsed.data.lines.map((l) => ({
        item_id: l.itemId,
        missing_qty: l.missingQty,
        near_expiry: l.nearExpiry ?? false,
      })),
      p_client_uuid: parsed.data.clientUuid,
    },
  );
  if (res.ok) {
    revalidatePath(frontdeskPath(parsed.data.propertyId));
    revalidatePath(
      frontdeskDetailPath(parsed.data.propertyId, parsed.data.checkId),
    );
    revalidatePath(mobilePath(parsed.data.propertyId));
  }
  return res;
}

/** Lễ tân xác nhận đã thu + số folio (RPC `minibar_confirm_charge`). */
export async function confirmChargeAction(
  input: MinibarConfirmChargeInput,
): Promise<MinibarActionResult<ConfirmChargeResult>> {
  const parsed = minibarConfirmChargeSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<ConfirmChargeResult>(
    supabase,
    "minibar_confirm_charge",
    {
      p_check_id: parsed.data.checkId,
      p_folio_no: parsed.data.folioNo,
    },
  );
  if (res.ok) {
    revalidatePath(frontdeskPath(parsed.data.propertyId));
    revalidatePath(
      frontdeskDetailPath(parsed.data.propertyId, parsed.data.checkId),
    );
    revalidatePath(housekeepingPath(parsed.data.propertyId));
  }
  return res;
}

/** Đề nghị miễn tiền minibar (RPC `minibar_request_waive`). */
export async function requestWaiveAction(
  input: MinibarRequestWaiveInput,
): Promise<MinibarActionResult<WaiveResult>> {
  const parsed = minibarRequestWaiveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<WaiveResult>(
    supabase,
    "minibar_request_waive",
    {
      p_check_id: parsed.data.checkId,
      p_reason: parsed.data.reason,
    },
  );
  if (res.ok) {
    revalidatePath(frontdeskPath(parsed.data.propertyId));
    revalidatePath(
      frontdeskDetailPath(parsed.data.propertyId, parsed.data.checkId),
    );
  }
  return res;
}

/** Quản lý duyệt/từ chối đề nghị miễn (RPC `minibar_decide_waive`). */
export async function decideWaiveAction(
  input: MinibarDecideWaiveInput,
): Promise<MinibarActionResult<WaiveResult>> {
  const parsed = minibarDecideWaiveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<WaiveResult>(
    supabase,
    "minibar_decide_waive",
    {
      p_check_id: parsed.data.checkId,
      p_decision: parsed.data.decision,
      p_note: parsed.data.note ?? null,
    },
  );
  if (res.ok) {
    revalidatePath(frontdeskPath(parsed.data.propertyId));
    revalidatePath(
      frontdeskDetailPath(parsed.data.propertyId, parsed.data.checkId),
    );
    revalidatePath(housekeepingPath(parsed.data.propertyId));
  }
  return res;
}

/** Chuyển phiếu sang thu muộn (RPC `minibar_mark_late_charge`). */
export async function markLateChargeAction(
  input: MinibarMarkLateChargeInput,
): Promise<MinibarActionResult<{ ok: boolean; id: string; status: string }>> {
  const parsed = minibarMarkLateChargeSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<{ ok: boolean; id: string; status: string }>(
    supabase,
    "minibar_mark_late_charge",
    {
      p_check_id: parsed.data.checkId,
      p_note: parsed.data.note ?? null,
    },
  );
  if (res.ok) {
    revalidatePath(frontdeskPath(parsed.data.propertyId));
    revalidatePath(
      frontdeskDetailPath(parsed.data.propertyId, parsed.data.checkId),
    );
  }
  return res;
}

/** Xóa sổ phiếu kiểm (RPC `minibar_write_off`, gm). */
export async function writeOffAction(
  input: MinibarWriteOffInput,
): Promise<MinibarActionResult<{ ok: boolean; id: string; status: string }>> {
  const parsed = minibarWriteOffSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<{ ok: boolean; id: string; status: string }>(
    supabase,
    "minibar_write_off",
    {
      p_check_id: parsed.data.checkId,
      p_reason: parsed.data.reason,
    },
  );
  if (res.ok) {
    revalidatePath(frontdeskPath(parsed.data.propertyId));
    revalidatePath(
      frontdeskDetailPath(parsed.data.propertyId, parsed.data.checkId),
    );
    revalidatePath(housekeepingPath(parsed.data.propertyId));
  }
  return res;
}

/** Bổ sung minibar vào phòng (RPC `minibar_refill`). */
export async function refillAction(
  input: MinibarRefillInput,
): Promise<MinibarActionResult<RefillResult>> {
  const parsed = minibarRefillSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<RefillResult>(supabase, "minibar_refill", {
    p_room_id: parsed.data.roomId,
    p_lines: parsed.data.lines.map((l) => ({
      item_id: l.itemId,
      qty: l.qty,
      lot_id: l.lotId ?? null,
    })),
  });
  if (res.ok) {
    revalidatePath(housekeepingPath(parsed.data.propertyId));
  }
  return res;
}

/** Đặt giá minibar theo mốc hiệu lực (RPC `minibar_price_set`). */
export async function priceSetAction(
  input: MinibarPriceSetInput,
): Promise<MinibarActionResult<PriceSetResult>> {
  const parsed = minibarPriceSetSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callMinibarRpc<PriceSetResult>(
    supabase,
    "minibar_price_set",
    {
      p_property_id: parsed.data.propertyId,
      p_item_id: parsed.data.itemId,
      p_price: parsed.data.price,
      p_valid_from: parsed.data.validFrom,
      p_valid_to: parsed.data.validTo ?? null,
    },
  );
  if (res.ok) {
    revalidatePath(housekeepingPath(parsed.data.propertyId));
  }
  return res;
}

/**
 * Đối soát minibar 1 ngày (RPC `minibar_reconcile`).
 * Hàm không kiểm tra quyền trong DB (để pg_cron gọi được — Q57);
 * màn đối soát chỉ hiện với người có `minibar.reconcile`.
 */
export async function reconcileAction(
  input: MinibarReconcileInput,
): Promise<MinibarActionResult<MinibarReconcileResult>> {
  const parsed = minibarReconcileSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callMinibarRpc<MinibarReconcileResult>(supabase, "minibar_reconcile", {
    p_property_id: parsed.data.propertyId,
    p_date: parsed.data.date,
  });
}

/** Danh sách thu hồi hàng sắp hết hạn (RPC `minibar_recall_list`). */
export async function recallListAction(
  propertyId: string,
  days: number,
): Promise<MinibarActionResult<MinibarRecallRow[]>> {
  return getRecallList(propertyId, days);
}

export type {
  MinibarCheckRow,
  MinibarCheckDetail,
  MinibarCheckLineRow,
  MinibarItemRow,
  MinibarPriceRow,
  MinibarReconcileResult,
  RoomStockRow,
} from "./queries";
