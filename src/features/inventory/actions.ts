"use server";
import { vi } from "@/i18n/vi";

import { createClient } from "@/lib/supabase/server";
import {
  getPurposeIssue,
  getRequisition,
  getStockCard,
  getTransfer,
  getWaste,
  listPurposeIssues,
  listRequisitions,
  listStock,
  listTransfers,
  listWaste,
  type PurposeIssueDetail,
  type RequisitionDetail,
  type StockCardResult,
  type StockListResult,
  type TransferDetail,
  type WasteDetail,
} from "./queries";
import {
  docListSchema,
  stockCardSchema,
  stockListSchema,
  type DocListInput,
  type StockCardInput,
  type StockListInput,
} from "./schemas";
import type { InventoryActionResult } from "./rpc";

function validationError(
  issues: { message: string }[],
): InventoryActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? vi.common.invalidData };
}

/** Danh sách phiếu lĩnh (RPC `requisition_list`, T-030). */
export async function listRequisitionsAction(input: DocListInput) {
  const parsed = docListSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return listRequisitions(parsed.data);
}

/** Chi tiết 1 phiếu lĩnh (RPC `requisition_get`, T-030). */
export async function getRequisitionAction(
  requisitionId: string,
): Promise<InventoryActionResult<RequisitionDetail>> {
  return getRequisition(requisitionId);
}

/** Danh sách điều chuyển (RPC `transfer_list`, T-030). */
export async function listTransfersAction(input: DocListInput) {
  const parsed = docListSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return listTransfers(parsed.data);
}

/** Chi tiết 1 điều chuyển (RPC `transfer_get`, T-030). */
export async function getTransferAction(
  transferId: string,
): Promise<InventoryActionResult<TransferDetail>> {
  return getTransfer(transferId);
}

/** Danh sách xuất mục đích (RPC `purpose_issue_list`, T-030). */
export async function listPurposeIssuesAction(input: DocListInput) {
  const parsed = docListSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return listPurposeIssues(parsed.data);
}

/** Chi tiết 1 phiếu xuất mục đích (RPC `purpose_issue_get`, T-030). */
export async function getPurposeIssueAction(
  issueId: string,
): Promise<InventoryActionResult<PurposeIssueDetail>> {
  return getPurposeIssue(issueId);
}

/** Danh sách hủy hàng (RPC `waste_list`, T-030). */
export async function listWasteAction(input: DocListInput) {
  const parsed = docListSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return listWaste(parsed.data);
}

/** Chi tiết 1 phiếu hủy hàng (RPC `waste_get`, T-030). */
export async function getWasteAction(
  wasteId: string,
): Promise<InventoryActionResult<WasteDetail>> {
  return getWaste(wasteId);
}

/** Tồn kho theo kho + mặt hàng (đọc trực tiếp, RLS đã chặn quyền). */
export async function listStockAction(
  input: StockListInput,
): Promise<InventoryActionResult<StockListResult>> {
  const parsed = stockListSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return listStock(parsed.data);
}

/** Thẻ kho của 1 mặt hàng tại 1 kho (đọc trực tiếp, RLS đã chặn quyền). */
export async function getStockCardAction(
  input: StockCardInput,
): Promise<InventoryActionResult<StockCardResult>> {
  const parsed = stockCardSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  return getStockCard(parsed.data);
}

/** Danh sách kho của KS (cho bộ lọc tồn kho / thẻ kho). */
export async function listInventoryWarehousesAction(propertyId: string) {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("warehouses")
    .select("id, name")
    .eq("property_id", propertyId)
    .order("name", { ascending: true });
  if (error) {
    return { ok: false as const, error: vi.inventory.warehouseListLoadFailed };
  }
  return {
    ok: true as const,
    data: (data ?? []).map((w) => ({ id: w.id, name: w.name })),
  };
}
