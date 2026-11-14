"use server";

import { createClient } from "@/lib/supabase/server";
import { vi } from "@/i18n/vi";
import { callInventoryRpc, type InventoryActionResult } from "./rpc";
import {
  docLineQtySchema,
  docOpSchema,
  saveDocDraftSchema,
  type DocLineQtyInput,
  type DocOpInput,
  type SaveDocDraftInput,
} from "./doc-schemas";

export type DocActionResult = { id: string; doc_no?: string; status?: string };

function invalid(
  issues: { message: string }[],
): InventoryActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? vi.common.invalidData };
}

/**
 * Lưu nháp chứng từ kho (RPC `<kind>_save_draft`, T-030). Logic nghiệp vụ
 * và kiểm tra quyền ở RPC; ở đây chỉ ánh xạ payload (AGENTS.md mục 5).
 */
export async function saveDocDraftAction(
  input: SaveDocDraftInput,
): Promise<InventoryActionResult<DocActionResult>> {
  const parsed = saveDocDraftSchema.safeParse(input);
  if (!parsed.success) {
    return invalid(parsed.error.issues);
  }
  const v = parsed.data;
  const supabase = await createClient();
  const base = {
    id: v.id ?? null,
    property_id: v.propertyId,
    business_date: v.businessDate ?? null,
    note: v.note ?? null,
  };
  const note = (l: { note?: string | null }) => l.note ?? null;

  if (v.kind === "waste") {
    return callInventoryRpc<DocActionResult>(supabase, "waste_save_draft", {
      p_waste: {
        ...base,
        warehouse_id: v.warehouseId,
        reason_code: v.reasonCode,
        photo_ids: v.photoIds ?? [],
        lines: v.lines.map((l) => ({
          item_id: l.itemId,
          qty_stock: l.qty,
          note: note(l),
        })),
      },
    });
  }
  const lines = v.lines.map((l) => ({
    item_id: l.itemId,
    qty: l.qty,
    note: note(l),
  }));
  if (v.kind === "requisition") {
    return callInventoryRpc<DocActionResult>(
      supabase,
      "requisition_save_draft",
      {
        p_requisition: {
          ...base,
          outlet_id: v.outletId,
          from_warehouse_id: v.fromWarehouseId,
          to_warehouse_id: v.toWarehouseId,
          lines,
        },
      },
    );
  }
  if (v.kind === "transfer") {
    return callInventoryRpc<DocActionResult>(supabase, "transfer_save_draft", {
      p_transfer: {
        ...base,
        from_warehouse_id: v.fromWarehouseId,
        to_warehouse_id: v.toWarehouseId,
        lines,
      },
    });
  }
  return callInventoryRpc<DocActionResult>(
    supabase,
    "purpose_issue_save_draft",
    {
      p_issue: {
        ...base,
        warehouse_id: v.warehouseId,
        purpose_code: v.purposeCode,
        cost_center_id: v.costCenterId ?? null,
        expense_category_id: v.expenseCategoryId ?? null,
        lines,
      },
    },
  );
}

/** Đổi trạng thái chứng từ kho (gửi duyệt, duyệt/từ chối, ghi sổ, hủy, đảo). */
export async function docOpAction(
  input: DocOpInput,
): Promise<InventoryActionResult<DocActionResult>> {
  const parsed = docOpSchema.safeParse(input);
  if (!parsed.success) {
    return invalid(parsed.error.issues);
  }
  const { kind, op, propertyId, id, reason } = parsed.data;
  const supabase = await createClient();
  const needsReason = op === "cancel" || op === "reverse" || op === "reject";
  if (needsReason && !reason) {
    return { ok: false, error: vi.inventory.doc.reasonRequired };
  }

  if (kind === "waste" || kind === "requisition") {
    const idKey = kind === "waste" ? "p_waste_id" : "p_requisition_id";
    if (op === "submit") {
      return callInventoryRpc(supabase, `${kind}_submit`, {
        p_property_id: propertyId,
        [idKey]: id,
      });
    }
    if (op === "approve" || op === "reject") {
      return callInventoryRpc(supabase, `${kind}_decide`, {
        p_property_id: propertyId,
        [idKey]: id,
        p_decision: op === "approve" ? "approved" : "rejected",
        p_comment: reason ?? null,
      });
    }
    if (op === "cancel") {
      return callInventoryRpc(supabase, `${kind}_cancel`, {
        p_property_id: propertyId,
        [idKey]: id,
        p_reason: reason,
      });
    }
  }
  if (kind === "transfer" && op === "cancel") {
    return callInventoryRpc(supabase, "transfer_cancel", {
      p_property_id: propertyId,
      p_transfer_id: id,
      p_reason: reason,
    });
  }
  if (kind === "purpose_issue") {
    if (op === "post") {
      return callInventoryRpc(supabase, "purpose_issue_post", {
        p_issue_id: id,
      });
    }
    if (op === "cancel" || op === "reverse") {
      return callInventoryRpc(supabase, `purpose_issue_${op}`, {
        p_property_id: propertyId,
        p_issue_id: id,
        p_reason: reason,
      });
    }
  }
  return { ok: false, error: vi.common.invalidData };
}

/** Xuất/chuyển/nhận theo dòng (RPC requisition_issue, requisition_confirm_receipt, transfer_send/receive). */
export async function docLineQtyAction(
  input: DocLineQtyInput,
): Promise<InventoryActionResult<DocActionResult>> {
  const parsed = docLineQtySchema.safeParse(input);
  if (!parsed.success) {
    return invalid(parsed.error.issues);
  }
  const { kind, id, lines, note } = parsed.data;
  const supabase = await createClient();
  const p_lines = lines
    .filter((l) => l.qtyStock > 0)
    .map((l) => ({ line_id: l.lineId, qty_stock: l.qtyStock }));
  if (p_lines.length === 0) {
    return { ok: false, error: vi.inventory.doc.needQty };
  }
  switch (kind) {
    case "requisition_issue":
      return callInventoryRpc(supabase, "requisition_issue", {
        p_requisition_id: id,
        p_lines,
      });
    case "requisition_receive":
      return callInventoryRpc(supabase, "requisition_confirm_receipt", {
        p_requisition_id: id,
        p_lines,
        p_discrepancy_note: note ?? null,
      });
    case "transfer_send":
      return callInventoryRpc(supabase, "transfer_send", {
        p_transfer_id: id,
        p_lines,
      });
    case "transfer_receive":
      return callInventoryRpc(supabase, "transfer_receive", {
        p_transfer_id: id,
        p_lines,
      });
  }
}
