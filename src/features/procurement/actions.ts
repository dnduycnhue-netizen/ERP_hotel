"use server";
import { vi } from "@/i18n/vi";

import { createClient } from "@/lib/supabase/server";
import { callProcurementRpc, type ProcurementActionResult } from "./rpc";
import {
  advanceDecideSchema,
  advanceDisburseSchema,
  advanceRequestSchema,
  approvalDecideSchema,
  approvalDelegationDeleteSchema,
  approvalDelegationSaveSchema,
  itemSearchSchema,
  marketOrderCreateSchema,
  poCancelSchema,
  poCloseSchema,
  poCreateFromPrSchema,
  poSaveDraftSchema,
  poSendSchema,
  poSubmitSchema,
  prCancelSchema,
  prDecideSchema,
  prSaveDraftSchema,
  prSubmitSchema,
  type AdvanceDecideInput,
  type AdvanceDisburseInput,
  type AdvanceRequestInput,
  type ApprovalDecideInput,
  type ApprovalDelegationDeleteInput,
  type ApprovalDelegationSaveInput,
  type ItemSearchInput,
  type MarketOrderCreateInput,
  type PoCancelInput,
  type PoCloseInput,
  type PoCreateFromPrInput,
  type PoSaveDraftInput,
  type PoSendInput,
  type PoSubmitInput,
  type PrCancelInput,
  type PrDecideInput,
  type PrSaveDraftInput,
  type PrSubmitInput,
} from "./schemas";
import { listItems } from "@/features/master/queries";

export type PrPoResult = {
  id: string;
  doc_no: string;
  status: string;
  steps?: number;
  pending_steps?: number;
  lines?: number;
  total_amount?: number;
  kind?: string;
};

export type ApprovalDecideResult = {
  doc_type: string;
  doc_id: string;
  status: string;
  pending_steps: number;
};

function validationError(
  issues: { message: string }[],
): ProcurementActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? vi.common.invalidData };
}

/** Tạo/sửa PR nháp (RPC `pr_save_draft`, T-020). */
export async function savePrDraftAction(
  input: PrSaveDraftInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = prSaveDraftSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "pr_save_draft", {
    p_property_id: parsed.data.propertyId,
    p_pr: {
      id: parsed.data.id ?? null,
      outlet_id: parsed.data.outletId ?? null,
      kind: parsed.data.kind,
      need_date: parsed.data.needDate ?? null,
      note: parsed.data.note ?? null,
      lines: parsed.data.lines.map((line) => ({
        id: line.id ?? null,
        item_id: line.itemId ?? null,
        description: line.description ?? null,
        qty: line.qty,
        uom: line.uom,
        expense_category_id: line.expenseCategoryId ?? null,
        cost_center_id: line.costCenterId ?? null,
        reason: line.reason ?? null,
      })),
    },
  });
}

/** Gửi PR duyệt (RPC `pr_submit`, T-020). */
export async function submitPrAction(
  input: PrSubmitInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = prSubmitSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "pr_submit", {
    p_property_id: parsed.data.propertyId,
    p_pr_id: parsed.data.prId,
  });
}

/** Duyệt/từ chối PR (RPC `pr_decide`, T-020). */
export async function decidePrAction(
  input: PrDecideInput,
): Promise<ProcurementActionResult<ApprovalDecideResult>> {
  const parsed = prDecideSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<ApprovalDecideResult>(supabase, "pr_decide", {
    p_property_id: parsed.data.propertyId,
    p_pr_id: parsed.data.prId,
    p_decision: parsed.data.decision,
    p_comment: parsed.data.comment ?? null,
  });
}

/** Hủy PR nháp/đã gửi (RPC `pr_cancel`, T-020). */
export async function cancelPrAction(
  input: PrCancelInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = prCancelSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "pr_cancel", {
    p_property_id: parsed.data.propertyId,
    p_pr_id: parsed.data.prId,
    p_reason: parsed.data.reason,
  });
}

/** Tạo PO từ dòng PR đã duyệt (RPC `po_create_from_pr`, T-020). */
export async function createPoFromPrAction(
  input: PoCreateFromPrInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = poCreateFromPrSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "po_create_from_pr", {
    p_property_id: parsed.data.propertyId,
    p_pr_line_ids: parsed.data.prLineIds,
    p_supplier_id: parsed.data.supplierId,
    p_channel: parsed.data.channel,
  });
}

/** Sửa PO nháp (RPC `po_save_draft`, T-020). */
export async function savePoDraftAction(
  input: PoSaveDraftInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = poSaveDraftSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "po_save_draft", {
    p_property_id: parsed.data.propertyId,
    p_po: {
      id: parsed.data.id,
      expected_date: parsed.data.expectedDate ?? null,
      over_ceiling_reason: parsed.data.overCeilingReason ?? null,
      lines: parsed.data.lines.map((line) => ({
        id: line.id ?? null,
        item_id: line.itemId ?? null,
        description: line.description ?? null,
        qty: line.qty,
        uom: line.uom,
        unit_price: line.unitPrice ?? null,
        expense_category_id: line.expenseCategoryId ?? null,
        cost_center_id: line.costCenterId ?? null,
      })),
    },
  });
}

/** Gửi PO duyệt (RPC `po_submit`, T-020). */
export async function submitPoAction(
  input: PoSubmitInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = poSubmitSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "po_submit", {
    p_property_id: parsed.data.propertyId,
    p_po_id: parsed.data.poId,
  });
}

/** Duyệt/từ chối bước duyệt hiện tại của PR hoặc PO (RPC `approval_decide`, T-020). */
export async function decideApprovalAction(
  input: ApprovalDecideInput,
): Promise<ProcurementActionResult<ApprovalDecideResult>> {
  const parsed = approvalDecideSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<ApprovalDecideResult>(supabase, "approval_decide", {
    p_property_id: parsed.data.propertyId,
    p_doc_type: parsed.data.docType,
    p_doc_id: parsed.data.docId,
    p_decision: parsed.data.decision,
    p_comment: parsed.data.comment ?? null,
  });
}

/** Gửi PO cho NCC (RPC `po_send`, T-020). */
export async function sendPoAction(
  input: PoSendInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = poSendSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "po_send", {
    p_property_id: parsed.data.propertyId,
    p_po_id: parsed.data.poId,
  });
}

/** Đóng phần còn thiếu của PO (RPC `po_close`, T-020). */
export async function closePoAction(
  input: PoCloseInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = poCloseSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "po_close", {
    p_property_id: parsed.data.propertyId,
    p_po_id: parsed.data.poId,
    p_reason: parsed.data.reason,
  });
}

/** Hủy PO (RPC `po_cancel`, T-020). */
export async function cancelPoAction(
  input: PoCancelInput,
): Promise<ProcurementActionResult<PrPoResult>> {
  const parsed = poCancelSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<PrPoResult>(supabase, "po_cancel", {
    p_property_id: parsed.data.propertyId,
    p_po_id: parsed.data.poId,
    p_reason: parsed.data.reason,
  });
}

export type ItemSearchResult = {
  id: string;
  code: string;
  name: string;
  stockUom: string;
  allowedChannels: string[];
};

/**
 * Tìm vật tư cho form yêu cầu mua (T-021): gọi `listItems` của danh mục
 * (bảng `items` đã có trong `database.types.ts`, không phải bảng thu mua).
 * Chỉ trả vật tư chưa bị gộp mã; giới hạn 10 kết quả cho ô tìm kiếm.
 */
export async function searchItemsAction(
  input: ItemSearchInput,
): Promise<ProcurementActionResult<ItemSearchResult[]>> {
  const parsed = itemSearchSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const { items } = await listItems({
    propertyId: parsed.data.propertyId,
    search: parsed.data.search,
    pageSize: 10,
  });
  return {
    ok: true,
    data: items
      .filter((item) => !item.merged_into_id)
      .map((item) => ({
        id: item.id,
        code: item.code,
        name: item.name,
        stockUom: item.stock_uom,
        allowedChannels: item.allowed_channels ?? [],
      })),
  };
}

/** Tạo/sửa ủy quyền duyệt (RPC `admin_approval_delegation_save`, T-020). */
export async function saveApprovalDelegationAction(
  input: ApprovalDelegationSaveInput,
): Promise<ProcurementActionResult<{ id: string }>> {
  const parsed = approvalDelegationSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<{ id: string }>(
    supabase,
    "admin_approval_delegation_save",
    {
      p_org_id: parsed.data.orgId,
      p_delegation: {
        id: parsed.data.id ?? null,
        from_user: parsed.data.fromUser,
        to_user: parsed.data.toUser,
        property_id: parsed.data.propertyId ?? null,
        valid_from: parsed.data.validFrom,
        valid_to: parsed.data.validTo,
        reason: parsed.data.reason ?? null,
      },
    },
  );
}

/** Xóa ủy quyền duyệt (RPC `admin_approval_delegation_delete`, T-020). */
export async function deleteApprovalDelegationAction(
  input: ApprovalDelegationDeleteInput,
): Promise<ProcurementActionResult<{ id: string }>> {
  const parsed = approvalDelegationDeleteSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<{ id: string }>(
    supabase,
    "admin_approval_delegation_delete",
    {
      p_org_id: parsed.data.orgId,
      p_delegation_id: parsed.data.delegationId,
    },
  );
}

export type MarketOrderCreateResult = {
  po_id: string;
  po_doc_no: string;
  advance_id: string;
  advance_doc_no: string;
  status: string;
  lines: number;
  total_amount: number;
};

export type AdvanceResult = {
  id: string;
  doc_no: string;
  status: string;
  due_settle_at?: string | null;
};

/** Tạo lệnh mua chợ + tạm ứng (RPC `market_order_create`, T-022). */
export async function createMarketOrderAction(
  input: MarketOrderCreateInput,
): Promise<ProcurementActionResult<MarketOrderCreateResult>> {
  const parsed = marketOrderCreateSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<MarketOrderCreateResult>(
    supabase,
    "market_order_create",
    {
      p_property_id: parsed.data.propertyId,
      p_lines: parsed.data.lines.map((line) => ({
        item_id: line.itemId ?? null,
        description: line.description ?? null,
        qty: line.qty,
        uom: line.uom,
        unit_price: line.unitPrice ?? null,
        expense_category_id: line.expenseCategoryId ?? null,
        cost_center_id: line.costCenterId ?? null,
      })),
      p_advance_amount: parsed.data.advanceAmount,
      p_purpose: parsed.data.purpose,
      p_expected_date: parsed.data.expectedDate ?? null,
    },
  );
}

/** Đề nghị tạm ứng độc lập (RPC `advance_request`, T-022). */
export async function requestAdvanceAction(
  input: AdvanceRequestInput,
): Promise<ProcurementActionResult<AdvanceResult>> {
  const parsed = advanceRequestSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<AdvanceResult>(supabase, "advance_request", {
    p_property_id: parsed.data.propertyId,
    p_amount: parsed.data.amount,
    p_purpose: parsed.data.purpose,
  });
}

/** Duyệt/từ chối tạm ứng (RPC `advance_decide`, T-022). */
export async function decideAdvanceAction(
  input: AdvanceDecideInput,
): Promise<ProcurementActionResult<AdvanceResult>> {
  const parsed = advanceDecideSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<AdvanceResult>(supabase, "advance_decide", {
    p_property_id: parsed.data.propertyId,
    p_advance_id: parsed.data.advanceId,
    p_approved: parsed.data.approved,
    p_reason: parsed.data.reason ?? null,
  });
}

/** Chi tiền tạm ứng (RPC `advance_disburse`, T-022). */
export async function disburseAdvanceAction(
  input: AdvanceDisburseInput,
): Promise<ProcurementActionResult<AdvanceResult>> {
  const parsed = advanceDisburseSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callProcurementRpc<AdvanceResult>(supabase, "advance_disburse", {
    p_property_id: parsed.data.propertyId,
    p_advance_id: parsed.data.advanceId,
    p_note: parsed.data.note ?? null,
  });
}
