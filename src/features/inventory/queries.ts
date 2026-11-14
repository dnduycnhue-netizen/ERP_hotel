import { searchWords } from "@/lib/text/normalize";
import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import { callInventoryRpc, type InventoryActionResult } from "./rpc";
import type { DocListInput, StockCardInput, StockListInput } from "./schemas";
import { vi } from "@/i18n/vi";

/* ------------------------------------------------------------------ */
/* Chứng từ kho — qua 8 RPC list/get của T-030 (không giá ở list;      */
/* purpose_issue/waste chỉ trả giá khi caller có stock.view_value).    */
/* ------------------------------------------------------------------ */

/** 1 dòng trong danh sách phiếu lĩnh (RPC `requisition_list`, T-030). */
export type RequisitionRow = {
  id: string;
  doc_no: string;
  status: string;
  business_date: string;
  note: string | null;
  outlet_id: string;
  outlet_name: string | null;
  from_warehouse_id: string;
  from_warehouse_name: string | null;
  to_warehouse_id: string;
  to_warehouse_name: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  line_count: number;
  total_qty_stock: number;
  total_issued_qty_stock: number;
  total_received_qty_stock: number;
};

export type RequisitionLineRow = {
  id: string;
  item_id: string;
  item_name: string;
  uom: string;
  qty: number;
  qty_stock: number;
  issued_qty_stock: number;
  received_qty_stock: number;
  lot_id: string | null;
  lot_no: string | null;
  note: string | null;
};

/** Chi tiết phiếu lĩnh (RPC `requisition_get`, T-030). */
export type RequisitionDetail = Omit<
  RequisitionRow,
  | "line_count"
  | "total_qty_stock"
  | "total_issued_qty_stock"
  | "total_received_qty_stock"
> & {
  property_id: string;
  discrepancy_note: string | null;
  lines: RequisitionLineRow[];
};

/** 1 dòng trong danh sách điều chuyển (RPC `transfer_list`, T-030). */
export type TransferRow = {
  id: string;
  doc_no: string;
  status: string;
  business_date: string;
  note: string | null;
  from_warehouse_id: string;
  from_warehouse_name: string | null;
  to_warehouse_id: string;
  to_warehouse_name: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  line_count: number;
  total_qty_stock: number;
  total_sent_qty_stock: number;
  total_received_qty_stock: number;
};

export type TransferLineRow = {
  id: string;
  item_id: string;
  item_name: string;
  uom: string;
  qty: number;
  qty_stock: number;
  sent_qty_stock: number;
  received_qty_stock: number;
  lot_id: string | null;
  lot_no: string | null;
  note: string | null;
};

/** Chi tiết điều chuyển (RPC `transfer_get`, T-030). */
export type TransferDetail = Omit<
  TransferRow,
  | "line_count"
  | "total_qty_stock"
  | "total_sent_qty_stock"
  | "total_received_qty_stock"
> & {
  property_id: string;
  lines: TransferLineRow[];
};

/** 1 dòng trong danh sách xuất mục đích (RPC `purpose_issue_list`, T-030). */
export type PurposeIssueRow = {
  id: string;
  doc_no: string;
  status: string;
  business_date: string;
  note: string | null;
  purpose_code: string;
  warehouse_id: string;
  warehouse_name: string | null;
  cost_center_id: string | null;
  cost_center_name: string | null;
  expense_category_id: string | null;
  expense_category_name: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  line_count: number;
  total_qty_stock: number;
};

export type PurposeIssueLineRow = {
  id: string;
  item_id: string;
  item_name: string;
  uom: string;
  qty: number;
  qty_stock: number;
  lot_id: string | null;
  lot_no: string | null;
  note: string | null;
  /** Chỉ có khi caller có `stock.view_value`; không có quyền thấy null. */
  unit_cost: number | null;
  line_amount: number | null;
};

/** Chi tiết xuất mục đích (RPC `purpose_issue_get`, T-030). */
export type PurposeIssueDetail = Omit<
  PurposeIssueRow,
  "line_count" | "total_qty_stock"
> & {
  property_id: string;
  work_order_id: string | null;
  lines: PurposeIssueLineRow[];
};

/** 1 dòng trong danh sách hủy hàng (RPC `waste_list`, T-030). */
export type WasteRow = {
  id: string;
  doc_no: string;
  status: string;
  business_date: string;
  note: string | null;
  reason_code: string;
  warehouse_id: string;
  warehouse_name: string | null;
  /** Chỉ có khi caller có `stock.view_value`; không có quyền thấy null. */
  total_value: number | null;
  proposed_by: string | null;
  approved_by: string | null;
  created_by: string | null;
  created_at: string;
  updated_at: string;
  line_count: number;
  total_qty_stock: number;
};

export type WasteLineRow = {
  id: string;
  item_id: string;
  item_name: string;
  lot_id: string | null;
  lot_no: string | null;
  qty_stock: number;
  note: string | null;
  /** Chỉ có khi caller có `stock.view_value`; không có quyền thấy null. */
  unit_cost: number | null;
  line_amount: number | null;
};

/** Chi tiết hủy hàng (RPC `waste_get`, T-030). */
export type WasteDetail = Omit<WasteRow, "line_count" | "total_qty_stock"> & {
  property_id: string;
  photo_ids: string[];
  lines: WasteLineRow[];
};

function listArgs(input: DocListInput): Record<string, unknown> {
  return {
    p_property_id: input.propertyId,
    p_status: input.status ?? null,
    p_search: input.search ?? null,
    p_limit: input.limit,
    p_offset: input.offset,
  };
}

/** Danh sách phiếu lĩnh (RPC `requisition_list`, T-030). */
export async function listRequisitions(
  input: DocListInput,
): Promise<InventoryActionResult<{ rows: RequisitionRow[]; total: number }>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "requisition_list", listArgs(input));
}

/** Chi tiết 1 phiếu lĩnh (RPC `requisition_get`, T-030). */
export async function getRequisition(
  requisitionId: string,
): Promise<InventoryActionResult<RequisitionDetail>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "requisition_get", {
    p_requisition_id: requisitionId,
  });
}

/** Danh sách điều chuyển (RPC `transfer_list`, T-030). */
export async function listTransfers(
  input: DocListInput,
): Promise<InventoryActionResult<{ rows: TransferRow[]; total: number }>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "transfer_list", listArgs(input));
}

/** Chi tiết 1 điều chuyển (RPC `transfer_get`, T-030). */
export async function getTransfer(
  transferId: string,
): Promise<InventoryActionResult<TransferDetail>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "transfer_get", {
    p_transfer_id: transferId,
  });
}

/** Danh sách xuất mục đích (RPC `purpose_issue_list`, T-030). */
export async function listPurposeIssues(
  input: DocListInput,
): Promise<InventoryActionResult<{ rows: PurposeIssueRow[]; total: number }>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "purpose_issue_list", listArgs(input));
}

/** Chi tiết 1 phiếu xuất mục đích (RPC `purpose_issue_get`, T-030). */
export async function getPurposeIssue(
  issueId: string,
): Promise<InventoryActionResult<PurposeIssueDetail>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "purpose_issue_get", {
    p_issue_id: issueId,
  });
}

/** Danh sách hủy hàng (RPC `waste_list`, T-030). */
export async function listWaste(
  input: DocListInput,
): Promise<InventoryActionResult<{ rows: WasteRow[]; total: number }>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "waste_list", listArgs(input));
}

/** Chi tiết 1 phiếu hủy hàng (RPC `waste_get`, T-030). */
export async function getWaste(
  wasteId: string,
): Promise<InventoryActionResult<WasteDetail>> {
  const supabase = await createClient();
  return callInventoryRpc(supabase, "waste_get", { p_waste_id: wasteId });
}

/* ------------------------------------------------------------------ */
/* Tồn kho + thẻ kho — đọc trực tiếp qua SELECT (không có RPC đọc tồn:  */
/* `stock_balance_get` trong 09-API-RPC §4 chưa từng được code). RLS    */
/* trên stock_moves/stock_balances đã chặn theo stock.view_qty /        */
/* stock.view_value theo từng kho; item_costs chỉ đọc được khi có       */
/* stock.view_value. Cột giá trị chỉ SELECT khi caller có quyền đó     */
/* (kiểm tra qua my_permissions, cùng cách các RPC T-030 dùng          */
/* has_perm 2 đối số). Số liệu tổng hợp ở đây chỉ để HIỂN THỊ, không   */
/* ghi lại đâu (AGENTS.md quy tắc 7).                                  */
/* ------------------------------------------------------------------ */

export type StockPerms = {
  canViewQty: boolean;
  canViewValue: boolean;
};

async function getStockPerms(
  supabase: SupabaseClient<Database>,
  propertyId: string,
): Promise<StockPerms> {
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  const canViewValue = perms.has("stock.view_value");
  return {
    canViewValue,
    canViewQty: canViewValue || perms.has("stock.view_qty"),
  };
}

/** 1 dòng tồn kho gộp theo kho + mặt hàng (cộng dồn các lô). */
export type StockRow = {
  warehouse_id: string;
  warehouse_name: string;
  item_id: string;
  item_code: string;
  item_name: string;
  stock_uom: string;
  qty: number;
  lot_count: number;
  /** Chỉ có khi caller có `stock.view_value`; không có quyền thấy null. */
  avg_cost: number | null;
  value: number | null;
};

export type StockListResult = {
  rows: StockRow[];
  total: number;
  /** Tổng giá trị tồn của trang hiện tại; null khi không có stock.view_value. */
  page_total_value: number | null;
  canViewValue: boolean;
  warehouses: { id: string; name: string }[];
};

/** Tồn kho theo kho + mặt hàng, gộp các lô (T-031). */
export async function listStock(
  input: StockListInput,
): Promise<InventoryActionResult<StockListResult>> {
  const supabase = await createClient();
  const perms = await getStockPerms(supabase, input.propertyId);
  if (!perms.canViewQty) {
    return { ok: false, error: vi.inventory.noStockViewPermission };
  }

  const { data: property, error: propertyError } = await supabase
    .from("properties")
    .select("org_id, legal_entity_id")
    .eq("id", input.propertyId)
    .single();
  if (propertyError || !property) {
    return { ok: false, error: vi.inventory.propertyNotFound };
  }

  // Tìm mã/tên vật tư trước để lọc theo item_id (balances không có tên).
  let itemIds: string[] | null = null;
  const search = input.search?.trim() ?? "";
  if (search !== "") {
    // Tìm không dấu, từng từ (AND) trên items.name_search (Q273/Q276, C6-N5).
    let itemQuery = supabase
      .from("items")
      .select("id")
      .eq("org_id", property.org_id);
    for (const word of searchWords(search)) {
      itemQuery = itemQuery.ilike("name_search", `%${escapeIlike(word)}%`);
    }
    const { data: found, error: searchError } = await itemQuery.limit(200);
    if (searchError) {
      return { ok: false, error: vi.inventory.itemSearchFailed };
    }
    itemIds = (found ?? []).map((row) => row.id);
    if (itemIds.length === 0) {
      const warehouses = await listWarehouses(supabase, input.propertyId);
      return {
        ok: true,
        data: {
          rows: [],
          total: 0,
          page_total_value: perms.canViewValue ? 0 : null,
          canViewValue: perms.canViewValue,
          warehouses,
        },
      };
    }
  }

  // Lấy toàn bộ số dư của KS (tối đa 5000 dòng) rồi gộp theo kho + mặt
  // hàng ở dưới: phân trang trên dòng thô sẽ xé lẻ các lô của cùng 1 mã
  // sang 2 trang. KS thường chỉ có vài trăm mã x ~10 kho nên đủ dùng;
  // khi vượt ngưỡng sẽ cần RPC `stock_balance_get` phía server (xem Q28).
  let balancesQuery = supabase
    .from("stock_balances")
    .select("warehouse_id, item_id, lot_id, qty")
    .eq("property_id", input.propertyId);
  if (input.warehouseId) {
    balancesQuery = balancesQuery.eq("warehouse_id", input.warehouseId);
  }
  if (itemIds) {
    balancesQuery = balancesQuery.in("item_id", itemIds);
  }
  const { data: balances, error: balancesError } = await balancesQuery
    .order("warehouse_id", { ascending: true })
    .order("item_id", { ascending: true })
    .limit(5000);
  if (balancesError) {
    return { ok: false, error: vi.inventory.stockLoadFailed };
  }

  const warehouses = await listWarehouses(supabase, input.propertyId);
  const warehouseNames = new Map(warehouses.map((w) => [w.id, w.name]));

  const itemIdSet = [...new Set((balances ?? []).map((b) => b.item_id))];
  const itemsMap = new Map<
    string,
    { code: string; name: string; stock_uom: string }
  >();
  if (itemIdSet.length > 0) {
    const { data: items, error: itemsError } = await supabase
      .from("items")
      .select("id, code, name, stock_uom")
      .in("id", itemIdSet);
    if (itemsError) {
      return { ok: false, error: vi.inventory.itemsLoadFailed };
    }
    for (const item of items ?? []) {
      itemsMap.set(item.id, {
        code: item.code,
        name: item.name,
        stock_uom: item.stock_uom,
      });
    }
  }

  const avgCosts = new Map<string, number>();
  if (perms.canViewValue && itemIdSet.length > 0) {
    const { data: costs, error: costsError } = await supabase
      .from("item_costs")
      .select("item_id, avg_cost")
      .eq("legal_entity_id", property.legal_entity_id)
      .in("item_id", itemIdSet);
    if (costsError) {
      return { ok: false, error: vi.inventory.avgCostLoadFailed };
    }
    for (const cost of costs ?? []) {
      avgCosts.set(cost.item_id, Number(cost.avg_cost));
    }
  }

  const grouped = new Map<string, StockRow>();
  for (const balance of balances ?? []) {
    const key = `${balance.warehouse_id}|${balance.item_id}`;
    const item = itemsMap.get(balance.item_id);
    const existing = grouped.get(key);
    const qty = Number(balance.qty);
    if (existing) {
      existing.qty += qty;
      if (balance.lot_id) {
        existing.lot_count += 1;
      }
    } else {
      const avgCost = perms.canViewValue
        ? (avgCosts.get(balance.item_id) ?? 0)
        : null;
      grouped.set(key, {
        warehouse_id: balance.warehouse_id,
        warehouse_name:
          warehouseNames.get(balance.warehouse_id) ?? balance.warehouse_id,
        item_id: balance.item_id,
        item_code: item?.code ?? "",
        item_name: item?.name ?? "",
        stock_uom: item?.stock_uom ?? "",
        qty,
        lot_count: balance.lot_id ? 1 : 0,
        avg_cost: avgCost,
        value: null,
      });
    }
  }
  for (const row of grouped.values()) {
    if (row.avg_cost !== null) {
      row.value = Math.round(row.qty * row.avg_cost * 100) / 100;
    }
  }
  const allRows = [...grouped.values()].sort(
    (a, b) =>
      a.warehouse_name.localeCompare(b.warehouse_name, "vi") ||
      a.item_name.localeCompare(b.item_name, "vi"),
  );
  const pageRows = allRows.slice(input.offset, input.offset + input.limit);
  const pageTotalValue = perms.canViewValue
    ? Math.round(
        pageRows.reduce((sum, row) => sum + (row.value ?? 0), 0) * 100,
      ) / 100
    : null;

  return {
    ok: true,
    data: {
      rows: pageRows,
      total: allRows.length,
      page_total_value: pageTotalValue,
      canViewValue: perms.canViewValue,
      warehouses,
    },
  };
}

async function listWarehouses(
  supabase: SupabaseClient<Database>,
  propertyId: string,
): Promise<{ id: string; name: string }[]> {
  const { data } = await supabase
    .from("warehouses")
    .select("id, name")
    .eq("property_id", propertyId)
    .order("name", { ascending: true });
  return (data ?? []).map((w) => ({ id: w.id, name: w.name }));
}

function escapeIlike(value: string): string {
  return value.replace(/[%_,\\]/g, (ch) => `\\${ch}`);
}

/** Hàng `stock_moves` thô trả về từ PostgREST (2 nhánh select khác nhau
 *  chỉ khác cột giá trị — ép về 1 type nội bộ để xử lý chung). */
type StockMoveDbRow = {
  id: number;
  business_date: string;
  posted_at: string;
  move_type: string;
  qty: number;
  unit_cost?: number | null;
  amount?: number | null;
  source_doc_type: string;
  source_doc_id: string;
  lot_id: string | null;
  reverses_move_id: number | null;
};

/** 1 dòng trong thẻ kho (bút toán từ `stock_moves`). */
export type StockMoveRow = {
  id: number;
  business_date: string;
  posted_at: string;
  move_type: string;
  qty: number;
  /** Chỉ có khi caller có `stock.view_value`; không có quyền thấy null. */
  unit_cost: number | null;
  amount: number | null;
  source_doc_type: string;
  source_doc_id: string;
  source_doc_no: string | null;
  lot_id: string | null;
  lot_no: string | null;
  expiry_date: string | null;
  reverses_move_id: number | null;
  /** Tồn sau dòng này (tính dồn từ tồn đầu kỳ); chỉ để hiển thị. */
  running_balance: number;
};

export type StockCardResult = {
  warehouse: { id: string; name: string };
  item: { id: string; code: string; name: string; stock_uom: string };
  from: string | null;
  to: string | null;
  opening: number;
  total_in: number;
  total_out: number;
  closing: number;
  ledger_qty: number;
  /** Khớp khi không lọc ngày và đủ dòng; null khi không kiểm tra được. */
  matches: boolean | null;
  truncated: boolean;
  canViewValue: boolean;
  moves: StockMoveRow[];
};

/**
 * Thẻ kho của 1 mặt hàng tại 1 kho (T-031).
 * AC: tổng thẻ kho khớp `stock_moves` và khớp tồn sổ `stock_balances` —
 * `closing` = tồn đầu kỳ + Σ qty các bút toán trong kỳ (số liệu do
 * Postgres trả về), đối chiếu với Σ qty `stock_balances` cùng kho + mã;
 * trang hiện huy hiệu Khớp/Lệch. Khi lọc theo ngày, chỉ kiểm tra khớp
 * khi xem toàn bộ lịch sử (không lọc ngày).
 */
export async function getStockCard(
  input: StockCardInput,
): Promise<InventoryActionResult<StockCardResult>> {
  const supabase = await createClient();
  const perms = await getStockPerms(supabase, input.propertyId);
  if (!perms.canViewQty) {
    return { ok: false, error: vi.inventory.noStockViewPermission };
  }

  const [{ data: warehouse }, { data: item }] = await Promise.all([
    supabase
      .from("warehouses")
      .select("id, name")
      .eq("id", input.warehouseId)
      .eq("property_id", input.propertyId)
      .single(),
    supabase
      .from("items")
      .select("id, code, name, stock_uom")
      .eq("id", input.itemId)
      .single(),
  ]);
  if (!warehouse || !item) {
    return { ok: false, error: vi.inventory.warehouseOrItemNotFound };
  }

  // Giới hạn 1001 dòng để phát hiện tràn: thẻ kho 1 mã trong 1 kho
  // hiếm khi quá 1000 bút toán; khi tràn, báo rõ là chưa kiểm tra khớp
  // được thay vì kết luận sai.
  // Cột giá trị chỉ SELECT khi caller có stock.view_value (chuỗi select
  // phải là literal để supabase-js suy được type — không dùng biến string).
  const MOVE_LIMIT = 1001;
  const { data: rawMoves, error: movesError } = perms.canViewValue
    ? await supabase
        .from("stock_moves")
        .select(
          "id, business_date, posted_at, move_type, qty, unit_cost, amount, source_doc_type, source_doc_id, lot_id, reverses_move_id",
        )
        .eq("property_id", input.propertyId)
        .eq("warehouse_id", input.warehouseId)
        .eq("item_id", input.itemId)
        .order("business_date", { ascending: true })
        .order("posted_at", { ascending: true })
        .order("id", { ascending: true })
        .limit(MOVE_LIMIT)
    : await supabase
        .from("stock_moves")
        .select(
          "id, business_date, posted_at, move_type, qty, source_doc_type, source_doc_id, lot_id, reverses_move_id",
        )
        .eq("property_id", input.propertyId)
        .eq("warehouse_id", input.warehouseId)
        .eq("item_id", input.itemId)
        .order("business_date", { ascending: true })
        .order("posted_at", { ascending: true })
        .order("id", { ascending: true })
        .limit(MOVE_LIMIT);
  if (movesError) {
    return { ok: false, error: vi.inventory.stockCardLoadFailed };
  }
  const truncated = (rawMoves ?? []).length >= MOVE_LIMIT;
  const allMoves = ((rawMoves ?? []) as unknown as StockMoveDbRow[]).slice(
    0,
    1000,
  );

  const { data: balanceRows, error: balancesError } = await supabase
    .from("stock_balances")
    .select("qty")
    .eq("warehouse_id", input.warehouseId)
    .eq("item_id", input.itemId);
  if (balancesError) {
    return { ok: false, error: vi.inventory.bookStockLoadFailed };
  }
  const ledgerQty = (balanceRows ?? []).reduce(
    (sum, row) => sum + Number(row.qty),
    0,
  );

  const from = input.from ?? null;
  const to = input.to ?? null;
  const inRange = (businessDate: string): boolean =>
    (!from || businessDate >= from) && (!to || businessDate <= to);
  const opening = allMoves
    .filter((m) => from !== null && m.business_date < from)
    .reduce((sum, m) => sum + Number(m.qty), 0);
  const ranged = allMoves.filter((m) => inRange(m.business_date));
  const totalIn = ranged
    .filter((m) => Number(m.qty) > 0)
    .reduce((sum, m) => sum + Number(m.qty), 0);
  const totalOut = ranged
    .filter((m) => Number(m.qty) < 0)
    .reduce((sum, m) => sum + Math.abs(Number(m.qty)), 0);
  const closing = opening + ranged.reduce((sum, m) => sum + Number(m.qty), 0);

  const lotIds = [
    ...new Set(
      allMoves.map((m) => m.lot_id).filter((id): id is string => id !== null),
    ),
  ];
  const lotsMap = new Map<
    string,
    { lot_no: string; expiry_date: string | null }
  >();
  if (lotIds.length > 0) {
    const { data: lots } = await supabase
      .from("lots")
      .select("id, lot_no, expiry_date")
      .in("id", lotIds);
    for (const lot of lots ?? []) {
      lotsMap.set(lot.id, {
        lot_no: lot.lot_no,
        expiry_date: lot.expiry_date,
      });
    }
  }

  const docNos = await resolveDocNumbers(supabase, allMoves);

  let running = opening;
  const moves: StockMoveRow[] = ranged.map((m) => {
    running += Number(m.qty);
    const lot = m.lot_id ? lotsMap.get(m.lot_id) : undefined;
    return {
      id: m.id,
      business_date: m.business_date,
      posted_at: m.posted_at,
      move_type: m.move_type,
      qty: Number(m.qty),
      unit_cost: perms.canViewValue ? Number(m.unit_cost ?? 0) : null,
      amount: perms.canViewValue ? Number(m.amount ?? 0) : null,
      source_doc_type: m.source_doc_type,
      source_doc_id: m.source_doc_id,
      source_doc_no:
        docNos.get(`${m.source_doc_type}:${m.source_doc_id}`) ?? null,
      lot_id: m.lot_id,
      lot_no: lot?.lot_no ?? null,
      expiry_date: lot?.expiry_date ?? null,
      reverses_move_id: m.reverses_move_id,
      running_balance: running,
    };
  });

  return {
    ok: true,
    data: {
      warehouse: { id: warehouse.id, name: warehouse.name },
      item: {
        id: item.id,
        code: item.code,
        name: item.name,
        stock_uom: item.stock_uom,
      },
      from,
      to,
      opening,
      total_in: totalIn,
      total_out: totalOut,
      closing,
      ledger_qty: ledgerQty,
      matches:
        from === null && to === null && !truncated
          ? Math.abs(closing - ledgerQty) < 0.0001
          : null,
      truncated,
      canViewValue: perms.canViewValue,
      moves,
    },
  };
}

/**
 * Tra số chứng từ gốc cho các bút toán trong thẻ kho.
 * Các bảng chứng từ T-023/T-026/T-030 chưa có trong `database.types.ts`
 * (chưa sinh lại được vì không có Docker) nên ép kiểu client có chủ
 * đích tại đúng một chỗ này — cùng lý do như `rpc.ts`.
 */
async function resolveDocNumbers(
  supabase: SupabaseClient<Database>,
  moves: { source_doc_type: string; source_doc_id: string }[],
): Promise<Map<string, string>> {
  const tables: Record<string, string> = {
    goods_receipt: "goods_receipts",
    supplier_return: "supplier_returns",
    requisition: "requisitions",
    transfer: "transfers",
    purpose_issue: "purpose_issues",
    waste: "waste_reports",
  };
  const result = new Map<string, string>();
  const byType = new Map<string, string[]>();
  for (const move of moves) {
    const table = tables[move.source_doc_type];
    if (!table) {
      continue;
    }
    const ids = byType.get(move.source_doc_type) ?? [];
    if (!ids.includes(move.source_doc_id)) {
      ids.push(move.source_doc_id);
    }
    byType.set(move.source_doc_type, ids);
  }
  const untyped = supabase as unknown as SupabaseClient;
  for (const [docType, ids] of byType) {
    const { data } = await untyped
      .from(tables[docType])
      .select("id, doc_no")
      .in("id", ids);
    for (const row of (data ?? []) as { id: string; doc_no: string }[]) {
      result.set(`${docType}:${row.id}`, row.doc_no);
    }
  }
  return result;
}
