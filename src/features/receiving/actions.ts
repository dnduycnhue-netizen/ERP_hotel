"use server";

import { createClient } from "@/lib/supabase/server";
import { callReceivingRpc, type ReceivingActionResult } from "./rpc";
import {
  qcTemplateDeleteSchema,
  qcTemplateSaveSchema,
  receivingListReceiptsSchema,
  receivingOverrideLineSchema,
  receivingPostSchema,
  receivingRecordLineSchema,
  receivingReverseSchema,
  receivingStartSchema,
  supplierReturnPostSchema,
  type QcTemplateDeleteInput,
  type QcTemplateSaveInput,
  type ReceivingListReceiptsInput,
  type ReceivingOverrideLineInput,
  type ReceivingPostInput,
  type ReceivingRecordLineInput,
  type ReceivingReverseInput,
  type ReceivingStartInput,
  type SupplierReturnPostInput,
} from "./schemas";

export type ReceivingStartResult = {
  id: string;
  doc_no: string;
};

export type ReceivingRecordLineResult = {
  id: string;
  weigh_count: number;
  needs_reweigh: boolean;
  accepted_qty_stock_capped: number;
  short_shelf_life_warning: boolean;
};

export type ReceivingPostResult = {
  id: string;
  lines_posted: number;
};

export type SupplierReturnResult = {
  id: string;
  doc_no: string;
};

function validationError(
  issues: { message: string }[],
): ReceivingActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? "Dữ liệu không hợp lệ." };
}

/** Mo phieu nhan nhap cho 1 PO (RPC `receiving_start`, T-023). */
export async function startReceivingAction(
  input: ReceivingStartInput,
): Promise<ReceivingActionResult<ReceivingStartResult>> {
  const parsed = receivingStartSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc<ReceivingStartResult>(supabase, "receiving_start", {
    p_po_id: parsed.data.poId,
    p_warehouse_id: parsed.data.warehouseId,
    p_direct_issue_wh: parsed.data.directIssueWarehouseId ?? null,
    p_client_uuid: parsed.data.clientUuid ?? null,
  });
}

/** Ghi 1 dong nhan hang; goi lan 2 cung dong = can lai (RPC `receiving_record_line`, T-023). */
export async function recordReceivingLineAction(
  input: ReceivingRecordLineInput,
): Promise<ReceivingActionResult<ReceivingRecordLineResult>> {
  const parsed = receivingRecordLineSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc<ReceivingRecordLineResult>(
    supabase,
    "receiving_record_line",
    {
      p_gr_id: parsed.data.grId,
      p_po_line_id: parsed.data.poLineId,
      p_item_id: parsed.data.itemId,
      p_gross: parsed.data.gross,
      p_tare: parsed.data.tare,
      p_uom: parsed.data.uom ?? null,
      p_qc: parsed.data.qc,
      p_lot: parsed.data.lot ?? null,
      p_expiry: parsed.data.expiry ?? null,
      p_photo_ids: parsed.data.photoIds ?? null,
      p_client_uuid: parsed.data.clientUuid ?? null,
    },
  );
}

/** Duyet nhan vuot tran cho 1 dong (RPC `receiving_override_line`, T-023). */
export async function overrideReceivingLineAction(
  input: ReceivingOverrideLineInput,
): Promise<ReceivingActionResult<{ id: string; accepted_qty_stock: number }>> {
  const parsed = receivingOverrideLineSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc(supabase, "receiving_override_line", {
    p_gr_line_id: parsed.data.grLineId,
    p_reason: parsed.data.reason,
  });
}

/** Ghi so phieu nhan (RPC `receiving_post`, T-023). */
export async function postReceivingAction(
  input: ReceivingPostInput,
): Promise<ReceivingActionResult<ReceivingPostResult>> {
  const parsed = receivingPostSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc<ReceivingPostResult>(supabase, "receiving_post", {
    p_gr_id: parsed.data.grId,
    p_pin: parsed.data.pin,
  });
}

/** Tra hang da nhan ve NCC (RPC `supplier_return_post`, T-023). */
export async function postSupplierReturnAction(
  input: SupplierReturnPostInput,
): Promise<ReceivingActionResult<SupplierReturnResult>> {
  const parsed = supplierReturnPostSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc<SupplierReturnResult>(
    supabase,
    "supplier_return_post",
    {
      p_gr_id: parsed.data.grId,
      p_lines: parsed.data.lines.map((line) => ({
        gr_line_id: line.grLineId,
        qty_stock: line.qtyStock,
        reason: line.reason ?? null,
        photo_ids: line.photoIds ?? null,
        supplier_signature_path: line.supplierSignaturePath ?? null,
      })),
    },
  );
}

/** Dao phieu nhan da post (RPC `receiving_reverse`, T-023). */
export async function reverseReceivingAction(
  input: ReceivingReverseInput,
): Promise<ReceivingActionResult<{ id: string }>> {
  const parsed = receivingReverseSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc(supabase, "receiving_reverse", {
    p_gr_id: parsed.data.grId,
    p_reason: parsed.data.reason,
  });
}

/** Luu mau checklist QC theo nhom hang (RPC `admin_qc_template_save`, T-023). */
export async function saveQcTemplateAction(
  input: QcTemplateSaveInput,
): Promise<ReceivingActionResult<{ id: string }>> {
  const parsed = qcTemplateSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc(supabase, "admin_qc_template_save", {
    p_org_id: parsed.data.orgId,
    p_item_group_id: parsed.data.itemGroupId,
    p_checklist: parsed.data.checklist,
  });
}

/** Xoa mau checklist QC (RPC `admin_qc_template_delete`, T-023). */
export async function deleteQcTemplateAction(
  input: QcTemplateDeleteInput,
): Promise<ReceivingActionResult<{ id: string }>> {
  const parsed = qcTemplateDeleteSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc(supabase, "admin_qc_template_delete", {
    p_template_id: parsed.data.templateId,
  });
}

/** Danh sach phieu nhan co loc (RPC `receiving_list_receipts`, T-023). */
export async function listReceiptsAction(
  input: ReceivingListReceiptsInput,
): Promise<
  ReceivingActionResult<{
    receipts: import("./queries").ReceiptListRow[];
    total: number;
  }>
> {
  const parsed = receivingListReceiptsSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  return callReceivingRpc(supabase, "receiving_list_receipts", {
    p_property_id: parsed.data.propertyId,
    p_status: parsed.data.status ?? null,
    p_search: parsed.data.search ?? null,
    p_limit: parsed.data.limit,
    p_offset: parsed.data.offset,
  });
}
