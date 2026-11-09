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
  supplier_id: string;
  supplier_name: string;
  order_date: string;
  expected_date: string | null;
  total_amount: number;
  status: string;
  over_ceiling_reason: string | null;
  created_by: string;
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

/** Danh sách PO qua RPC `po_list` (T-020). */
export async function listPos(
  propertyId: string,
  opts: {
    status?: string;
    search?: string;
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

/** Timeline duyệt của 1 chứng từ qua RPC `approval_timeline` (T-020). */
export async function listApprovalSteps(
  propertyId: string,
  docType: "pr" | "po",
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
