import "server-only";

import { createClient } from "@/lib/supabase/server";
import { callProcurementRpc, type ProcurementActionResult } from "./rpc";

export type PrRow = {
  id: string;
  doc_no: string;
  kind: "stock" | "service";
  need_date: string | null;
  status: string;
  note: string | null;
  outlet_id: string | null;
  outlet_name: string | null;
  created_by: string;
  created_by_name: string | null;
  created_at: string;
  updated_at: string;
  line_count: number;
};

export type PrLineRow = {
  id: string;
  pr_id: string;
  item_id: string | null;
  item_code: string | null;
  item_name: string | null;
  description: string | null;
  qty: number;
  uom: string;
  expense_category_id: string | null;
  cost_center_id: string | null;
  reason: string | null;
  converted_qty: number;
  created_at: string;
};

export type PoRow = {
  id: string;
  doc_no: string;
  kind: "stock" | "service";
  channel: "contract" | "quote" | "market";
  supplier_id: string | null;
  supplier_name: string | null;
  order_date: string;
  expected_date: string | null;
  total_amount: number;
  status: string;
  over_ceiling_reason: string | null;
  created_by: string;
  created_by_name: string | null;
  created_at: string;
  updated_at: string;
  line_count: number;
  received_qty_stock: number;
};

export type PoLineRow = {
  id: string;
  po_id: string;
  pr_line_id: string | null;
  item_id: string | null;
  item_code: string | null;
  item_name: string | null;
  description: string | null;
  qty: number;
  uom: string;
  qty_stock: number | null;
  unit_price: number;
  price_source: "agreement" | "quote" | "ceiling" | "manual";
  ceiling_price: number | null;
  over_ceiling: boolean;
  received_qty_stock: number;
  expense_category_id: string | null;
  cost_center_id: string | null;
  created_at: string;
};

export type ApprovalStepRow = {
  id: string;
  step: number;
  approver_role_id: string | null;
  approver_role_name: string | null;
  approver_user_id: string | null;
  required_perm: string;
  decision: "pending" | "approved" | "rejected";
  comment: string | null;
  decided_by: string | null;
  decided_by_name: string | null;
  decided_at: string | null;
  delegated_from: string | null;
  delegated_from_name: string | null;
  created_at: string;
};

type ListResult<T> = { total: number; rows: T[] };

export type AdvanceRow = {
  id: string;
  doc_no: string;
  employee_id: string;
  employee_name: string | null;
  amount: number;
  purpose: string;
  status: string;
  requested_at: string;
  decided_by: string | null;
  decided_at: string | null;
  decide_reason: string | null;
  disbursed_at: string | null;
  due_settle_at: string | null;
  created_at: string;
  po_id: string | null;
  po_doc_no: string | null;
  po_status: string | null;
};

export type AdvanceDetail = {
  advance: AdvanceRow & {
    legal_entity_id: string;
    property_id: string;
    disbursed_note: string | null;
    settled_at: string | null;
    created_by: string;
    updated_at: string;
  };
  po: {
    id: string;
    doc_no: string;
    status: string;
    total_amount: number;
    channel: string;
  } | null;
};

/** Danh sách tạm ứng qua RPC `advance_list` (T-022). */
export async function listAdvances(
  propertyId: string,
  opts: {
    status?: string;
    search?: string;
    page?: number;
    pageSize?: number;
  } = {},
): Promise<ProcurementActionResult<ListResult<AdvanceRow>>> {
  const supabase = await createClient();
  const page = Math.max(1, opts.page ?? 1);
  const pageSize = Math.min(100, Math.max(1, opts.pageSize ?? 20));
  const res = await callProcurementRpc<ListResult<AdvanceRow>>(
    supabase,
    "advance_list",
    {
      p_property_id: propertyId,
      p_status: opts.status ?? null,
      p_search: opts.search ?? null,
      p_limit: pageSize,
      p_offset: (page - 1) * pageSize,
    },
  );
  if (!res.ok) {
    return res;
  }
  return {
    ok: true,
    data: { total: res.data.total ?? 0, rows: res.data.rows ?? [] },
  };
}

/** Chi tiết tạm ứng + PO liên kết qua RPC `advance_get` (T-022). */
export async function getAdvance(
  propertyId: string,
  advanceId: string,
): Promise<ProcurementActionResult<AdvanceDetail>> {
  const supabase = await createClient();
  const res = await callProcurementRpc<AdvanceDetail>(supabase, "advance_get", {
    p_property_id: propertyId,
    p_advance_id: advanceId,
  });
  if (!res.ok) {
    return res;
  }
  return { ok: true, data: res.data };
}

/** Danh sách PR qua RPC `pr_list` (T-020). */
export async function listPrs(
  propertyId: string,
  opts: {
    status?: string;
    search?: string;
    page?: number;
    pageSize?: number;
  } = {},
): Promise<ProcurementActionResult<ListResult<PrRow>>> {
  const supabase = await createClient();
  const page = Math.max(1, opts.page ?? 1);
  const pageSize = Math.min(100, Math.max(1, opts.pageSize ?? 20));
  const res = await callProcurementRpc<ListResult<PrRow>>(supabase, "pr_list", {
    p_property_id: propertyId,
    p_status: opts.status ?? null,
    p_search: opts.search ?? null,
    p_limit: pageSize,
    p_offset: (page - 1) * pageSize,
  });
  if (!res.ok) {
    return res;
  }
  return {
    ok: true,
    data: { total: res.data.total ?? 0, rows: res.data.rows ?? [] },
  };
}

/** Chi tiết PR + dòng qua RPC `pr_get` (T-020). */
export async function getPr(
  propertyId: string,
  prId: string,
): Promise<ProcurementActionResult<{ pr: PrRow; lines: PrLineRow[] }>> {
  const supabase = await createClient();
  const res = await callProcurementRpc<{ pr: PrRow; lines: PrLineRow[] }>(
    supabase,
    "pr_get",
    { p_property_id: propertyId, p_pr_id: prId },
  );
  if (!res.ok) {
    return res;
  }
  return { ok: true, data: { pr: res.data.pr, lines: res.data.lines ?? [] } };
}

/** Danh sách PO qua RPC `po_list` (T-020). C6: loc them theo kenh
 * (`p_channel` cua migration 20261109525000) cho danh sach lenh mua cho. */
export async function listPos(
  propertyId: string,
  opts: {
    status?: string;
    search?: string;
    channel?: "contract" | "quote" | "market";
    page?: number;
    pageSize?: number;
  } = {},
): Promise<ProcurementActionResult<ListResult<PoRow>>> {
  const supabase = await createClient();
  const page = Math.max(1, opts.page ?? 1);
  const pageSize = Math.min(100, Math.max(1, opts.pageSize ?? 20));
  const res = await callProcurementRpc<ListResult<PoRow>>(supabase, "po_list", {
    p_property_id: propertyId,
    p_status: opts.status ?? null,
    p_search: opts.search ?? null,
    p_limit: pageSize,
    p_offset: (page - 1) * pageSize,
    p_channel: opts.channel ?? null,
  });
  if (!res.ok) {
    return res;
  }
  return {
    ok: true,
    data: { total: res.data.total ?? 0, rows: res.data.rows ?? [] },
  };
}

/** Chi tiết PO + dòng qua RPC `po_get` (T-020). */
export async function getPo(
  propertyId: string,
  poId: string,
): Promise<ProcurementActionResult<{ po: PoRow; lines: PoLineRow[] }>> {
  const supabase = await createClient();
  const res = await callProcurementRpc<{ po: PoRow; lines: PoLineRow[] }>(
    supabase,
    "po_get",
    { p_property_id: propertyId, p_po_id: poId },
  );
  if (!res.ok) {
    return res;
  }
  return { ok: true, data: { po: res.data.po, lines: res.data.lines ?? [] } };
}

/** Timeline duyệt của 1 chứng từ qua RPC `approval_timeline` (T-020; Q73: thêm 'payment_request'). */
export async function listApprovalSteps(
  propertyId: string,
  docType: "pr" | "po" | "payment_request",
  docId: string,
): Promise<ProcurementActionResult<ApprovalStepRow[]>> {
  const supabase = await createClient();
  const res = await callProcurementRpc<{ steps: ApprovalStepRow[] }>(
    supabase,
    "approval_timeline",
    {
      p_property_id: propertyId,
      p_doc_type: docType,
      p_doc_id: docId,
    },
  );
  if (!res.ok) {
    return res;
  }
  return { ok: true, data: res.data.steps ?? [] };
}
