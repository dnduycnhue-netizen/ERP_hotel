import "server-only";

import { createClient } from "@/lib/supabase/server";
import { callReceivingRpc, type ReceivingActionResult } from "./rpc";

/** 1 PO den han nhan trong ngay — KHONG co so luong / don gia (mu). */
export type ReceivingTaskRow = {
  po_id: string;
  doc_no: string;
  supplier_name: string;
  channel: "contract" | "quote" | "market";
  expected_date: string | null;
  line_count: number;
};

/** 1 dong hang can nhan — chi ten / dac ta / mau QC / can anh, khong co so luong. */
export type ReceivingTaskLineRow = {
  po_line_id: string;
  item_id: string;
  item_name: string;
  spec: string | null;
  qc_template: unknown;
  photo_required: boolean;
  uom: string;
  track_lot: boolean;
  shelf_life_days: number | null;
};

export type ReceivingTaskDetail = {
  po_id: string;
  doc_no: string;
  supplier_name: string;
  channel: string;
  lines: ReceivingTaskLineRow[];
};

export type ReceiptLineRow = {
  id: string;
  po_line_id: string | null;
  item_id: string;
  item_name: string;
  gross_qty: number;
  tare_qty: number;
  net_qty: number;
  net_qty_stock: number;
  uom: string;
  accepted_qty_stock: number;
  over_po_qty_stock: number;
  qc_status: "pass" | "fail" | "conditional";
  temperature_c: number | null;
  lot_no: string | null;
  expiry_date: string | null;
  weigh_count: number;
  needs_reweigh: boolean;
  photo_ids: string[];
  /** Chi co khi caller co `po.view_price`; nguoi nhan thay null. */
  unit_cost: number | null;
  line_amount: number | null;
};

export type ReceiptRow = {
  id: string;
  doc_no: string;
  po_id: string | null;
  supplier_name: string;
  warehouse_id: string;
  direct_issue_warehouse_id: string | null;
  status: string;
  receiver_id: string;
  received_at: string;
  /** Chi co khi caller co `po.view_price`; nguoi nhan thay null. */
  total_amount: number | null;
  reverse_reason: string | null;
  lines: ReceiptLineRow[];
};

/** Header phieu nhan trong danh sach — khong co total_amount. */
export type ReceiptListRow = {
  id: string;
  doc_no: string;
  po_id: string | null;
  po_doc_no: string | null;
  supplier_name: string;
  status: string;
  receiver_id: string;
  received_at: string;
  line_count: number;
};

/** Header phieu tra NCC trong danh sach — total_amount chi khi co po.view_price. */
export type SupplierReturnRow = {
  id: string;
  doc_no: string;
  status: "recorded" | "posted" | "cancelled";
  supplier_name: string;
  gr_doc_no: string | null;
  po_doc_no: string | null;
  line_count: number;
  total_qty_stock: number;
  total_amount: number | null;
  created_at: string;
  created_by: string | null;
  confirmed_at: string | null;
  cancelled_at: string | null;
};

/** 1 dong phieu tra NCC — unit_cost/line_amount chi khi co po.view_price. */
export type SupplierReturnLineRow = {
  id: string;
  gr_line_id: string | null;
  item_id: string;
  item_name: string;
  qty_stock: number;
  unit_cost: number | null;
  line_amount: number | null;
  reason: string | null;
  photo_ids: string[];
  supplier_signature_path: string | null;
};

/** Chi tiet 1 phieu tra NCC. */
export type SupplierReturnDetail = {
  id: string;
  doc_no: string;
  status: "recorded" | "posted" | "cancelled";
  reason: string | null;
  supplier_name: string;
  gr_id: string | null;
  gr_doc_no: string | null;
  po_id: string | null;
  po_doc_no: string | null;
  supplier_signature_path: string | null;
  photo_ids: string[];
  created_by: string | null;
  created_at: string;
  confirmed_by: string | null;
  confirmed_at: string | null;
  cancelled_by: string | null;
  cancelled_at: string | null;
  cancel_reason: string | null;
  total_amount: number | null;
  lines: SupplierReturnLineRow[];
};

/** 1 dong phieu nhan con tra duoc — so tra toi da = returnable_qty_stock. */
export type EligibleReturnLineRow = {
  gr_line_id: string;
  po_line_id: string | null;
  item_id: string;
  item_name: string;
  uom: string;
  accepted_qty_stock: number;
  returned_qty_stock: number;
  returnable_qty_stock: number;
  unit_cost: number | null;
};

/** Danh sach phieu tra NCC co loc (RPC `supplier_return_list`, T-026). */
export async function listSupplierReturns(
  propertyId: string,
  opts?: {
    status?: string | null;
    search?: string | null;
    limit?: number;
    offset?: number;
  },
): Promise<
  ReceivingActionResult<{ returns: SupplierReturnRow[]; total: number }>
> {
  const supabase = await createClient();
  return callReceivingRpc<{ returns: SupplierReturnRow[]; total: number }>(
    supabase,
    "supplier_return_list",
    {
      p_property_id: propertyId,
      p_status: opts?.status ?? null,
      p_search: opts?.search ?? null,
      p_limit: opts?.limit ?? 20,
      p_offset: opts?.offset ?? 0,
    },
  );
}

/** Chi tiet 1 phieu tra NCC (RPC `supplier_return_get`, T-026). */
export async function getSupplierReturn(
  returnId: string,
): Promise<ReceivingActionResult<SupplierReturnDetail>> {
  const supabase = await createClient();
  return callReceivingRpc<SupplierReturnDetail>(
    supabase,
    "supplier_return_get",
    { p_return_id: returnId },
  );
}

/** Dong cua phieu nhan da post con tra duoc (RPC `supplier_return_eligible_lines`, T-026). */
export async function eligibleReturnLines(grId: string): Promise<
  ReceivingActionResult<{
    gr_id: string;
    gr_doc_no: string;
    lines: EligibleReturnLineRow[];
  }>
> {
  const supabase = await createClient();
  return callReceivingRpc<{
    gr_id: string;
    gr_doc_no: string;
    lines: EligibleReturnLineRow[];
  }>(supabase, "supplier_return_eligible_lines", { p_gr_id: grId });
}

/** Danh sach PO den han nhan trong ngay (RPC `receiving_list_tasks`, T-023). */
export async function listReceivingTasks(
  propertyId: string,
  date?: string,
): Promise<ReceivingActionResult<ReceivingTaskRow[]>> {
  const supabase = await createClient();
  const res = await callReceivingRpc<{ tasks: ReceivingTaskRow[] }>(
    supabase,
    "receiving_list_tasks",
    { p_property_id: propertyId, p_date: date ?? null },
  );
  if (!res.ok) return res;
  return { ok: true, data: res.data.tasks ?? [] };
}

/** Chi tiet 1 PO de nhan (RPC `receiving_get_task`, T-023). */
export async function getReceivingTask(
  poId: string,
): Promise<ReceivingActionResult<ReceivingTaskDetail>> {
  const supabase = await createClient();
  return callReceivingRpc<ReceivingTaskDetail>(supabase, "receiving_get_task", {
    p_po_id: poId,
  });
}

/** Chi tiet 1 phieu nhan (RPC `receiving_get_receipt`, T-023). */
export async function getReceipt(
  grId: string,
): Promise<ReceivingActionResult<ReceiptRow>> {
  const supabase = await createClient();
  return callReceivingRpc<ReceiptRow>(supabase, "receiving_get_receipt", {
    p_gr_id: grId,
  });
}

/** Danh sach phieu nhan (RPC `receiving_list_receipts`, T-023). */
export async function listReceipts(
  propertyId: string,
  opts?: {
    status?: string | null;
    search?: string | null;
    limit?: number;
    offset?: number;
  },
): Promise<
  ReceivingActionResult<{ receipts: ReceiptListRow[]; total: number }>
> {
  const supabase = await createClient();
  return callReceivingRpc<{ receipts: ReceiptListRow[]; total: number }>(
    supabase,
    "receiving_list_receipts",
    {
      p_property_id: propertyId,
      p_status: opts?.status ?? null,
      p_search: opts?.search ?? null,
      p_limit: opts?.limit ?? 20,
      p_offset: opts?.offset ?? 0,
    },
  );
}
