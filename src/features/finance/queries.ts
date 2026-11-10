import "server-only";

import type { SupabaseClient } from "@supabase/supabase-js";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { createClient } from "@/lib/supabase/server";
import type { Database } from "@/lib/database.types";
import type { FinanceActionResult } from "./rpc";

/* ------------------------------------------------------------------ */
/* Tài chính — đọc trực tiếp `supplier_invoices` / lines,             */
/* `no_invoice_listings` / lines, `ap_ledger`, `advance_settlements`, */
/* `payment_requests` / lines (không có RPC list/get; RLS SELECT-only */
/* thực thi ở tầng dữ liệu). `database.types.ts` chưa có các bảng này */
/* nên ép kiểu có chủ đích tại đúng những chỗ đọc dưới đây.           */
/*                                                                     */
/* LƯU Ý QUYỀN ĐỌC (policy SELECT của migration 340000):               */
/* - Hóa đơn/dòng: invoice.manage / invoice.approve / ap.view /        */
/*   payment.request / payment.approve / payment.mark_paid /            */
/*   report.view.rpt_open_po_invoice.                                  */
/* - ap_ledger: ap.view / invoice.* / payment.* /                      */
/*   report.view.rpt_ap_aging.                                         */
/* - Bảng kê: invoice.manage / invoice.approve / ap.view.              */
/* - Quyết toán tạm ứng: advance.settle / advance.approve /             */
/*   advance.disburse / report.view.rpt_advances.                      */
/* ------------------------------------------------------------------ */

export type InvoiceStatus =
  | "draft"
  | "matched"
  | "on_hold"
  | "approved"
  | "partially_paid"
  | "paid"
  | "cancelled";

export type PaymentRequestStatus =
  "draft" | "submitted" | "approved" | "paid" | "cancelled";

export type NoInvoiceListingStatus = "draft" | "approved" | "cancelled";

/** 1 hóa đơn NCC trong danh sách. */
export type InvoiceRow = {
  id: string;
  org_id: string;
  property_id: string;
  supplier_id: string;
  supplier_name: string | null;
  supplier_code: string | null;
  doc_no: string;
  invoice_symbol: string;
  invoice_no: string;
  invoice_date: string;
  lookup_code: string | null;
  amount_before_tax: number;
  vat_amount: number;
  total: number;
  status: InvoiceStatus;
  created_by: string;
  created_at: string;
};

/** Kết quả khớp 3 chiều của 1 dòng hóa đơn (cột `match_result`). */
export type InvoiceMatchResult = {
  qty_ok: boolean | null;
  price_ok: boolean | null;
  po_qty: number | null;
  received_qty: number | null;
  available_qty: number | null;
  already_invoiced_qty: number | null;
  invoice_qty_for_po_line: number | null;
  po_unit_price: number | null;
  invoice_unit_price: number | null;
  price_diff_pct: number | null;
  tolerance_pct: number | null;
  reason: "QTY_OVER_RECEIVED" | "PRICE_OVER_TOLERANCE" | null;
};

/** 1 dòng hóa đơn (kèm tên hàng khi caller có `item.view`). */
export type InvoiceLineRow = {
  id: string;
  invoice_id: string;
  po_line_id: string;
  gr_line_id: string | null;
  item_id: string | null;
  item_code: string | null;
  item_name: string | null;
  qty: number;
  unit_price: number;
  amount: number;
  vat_rate: number;
  vat_amount: number;
  match_result: InvoiceMatchResult | null;
};

/** Chi tiết 1 hóa đơn: hóa đơn + các dòng. */
export type InvoiceDetail = {
  invoice: InvoiceRow;
  lines: InvoiceLineRow[];
};

/** 1 bảng kê mua hàng không hóa đơn trong danh sách. */
export type NoInvoiceListingRow = {
  id: string;
  org_id: string;
  property_id: string;
  po_id: string | null;
  gr_id: string | null;
  doc_no: string;
  seller_name: string;
  seller_address: string | null;
  seller_id_no: string | null;
  purchase_date: string;
  status: NoInvoiceListingStatus;
  total: number;
  created_by: string;
  created_at: string;
};

export type NoInvoiceListingLineRow = {
  id: string;
  listing_id: string;
  item_desc: string;
  qty: number;
  unit_price: number;
  amount: number;
};

export type NoInvoiceListingDetail = {
  listing: NoInvoiceListingRow;
  lines: NoInvoiceListingLineRow[];
};

/** 1 bút toán sổ công nợ (chỉ đọc — ap_ledger INSERT-only). */
export type ApLedgerRow = {
  id: string;
  org_id: string;
  legal_entity_id: string;
  property_id: string;
  supplier_id: string;
  supplier_name: string | null;
  supplier_code: string | null;
  doc_type:
    | "supplier_invoice"
    | "supplier_return"
    | "payment_request"
    | "advance_settlement";
  doc_id: string;
  amount: number;
  due_date: string | null;
  entry_date: string;
  created_at: string;
};

/** Tuổi nợ của 1 NCC — phân bổ tiền đã trả/trả hàng theo FIFO vào các
 * khoản phải trả (hạn trả sớm nhất trừ trước), rồi xếp phần còn nợ vào
 * nhóm theo ngày quá hạn tính từ `due_date` (không phải ngày hóa đơn).
 * Chỉ để hiển thị — không cộng trừ tiền để lưu (AGENTS.md quy tắc 7). */
export type SupplierAgingRow = {
  supplier_id: string;
  supplier_name: string | null;
  supplier_code: string | null;
  payable: number;
  paid: number;
  balance: number;
  notDue: number;
  overdue1to30: number;
  overdue31to60: number;
  overdue61to90: number;
  overdueOver90: number;
  oldestOverdueDays: number | null;
};

/** 1 lần quyết toán tạm ứng. */
export type AdvanceSettlementRow = {
  id: string;
  advance_id: string;
  advance_doc_no: string | null;
  doc_no: string;
  amount: number;
  refund_amount: number;
  extra_pay_amount: number;
  settled_by: string | null;
  settled_at: string;
  created_at: string;
};

/** 1 đề nghị thanh toán trong danh sách. */
export type PaymentRequestRow = {
  id: string;
  org_id: string;
  property_id: string;
  supplier_id: string;
  supplier_name: string | null;
  supplier_code: string | null;
  doc_no: string;
  total: number;
  due_date: string | null;
  status: PaymentRequestStatus;
  paid_at: string | null;
  bank_ref: string | null;
  created_by: string;
  created_at: string;
};

/** 1 dòng đề nghị thanh toán (kèm hóa đơn + số còn lại của hóa đơn). */
export type PaymentRequestLineRow = {
  id: string;
  request_id: string;
  invoice_id: string;
  invoice_doc_no: string | null;
  invoice_symbol: string | null;
  invoice_no: string | null;
  invoice_total: number | null;
  invoice_status: InvoiceStatus | null;
  amount: number;
};

export type PaymentRequestDetail = {
  request: PaymentRequestRow;
  lines: PaymentRequestLineRow[];
};

/** 1 hóa đơn còn số tiền chưa đề nghị thanh toán (phục vụ form tạo
 * đề nghị). `remaining` = total − đã trả − đã đề nghị (cùng công thức
 * RPC `payment_request_create` dùng để chặn vượt). */
export type PayableInvoiceRow = {
  id: string;
  doc_no: string;
  invoice_symbol: string;
  invoice_no: string;
  invoice_date: string;
  total: number;
  status: InvoiceStatus;
  remaining: number;
};

/** Quyền tài chính của người gọi tại 1 property (qua RPC `my_permissions`). */
export type FinancePerms = {
  canManageInvoice: boolean;
  canApproveInvoice: boolean;
  canViewAp: boolean;
  canRequestPayment: boolean;
  canApprovePayment: boolean;
  canMarkPaid: boolean;
  canSettleAdvance: boolean;
};

type UntypedClient = SupabaseClient;

function untyped(supabase: SupabaseClient<Database>): UntypedClient {
  return supabase as unknown as UntypedClient;
}

function extractRpcCode(message: string): string | null {
  const match = message.match(/ERR_[A-Z_]+(?::[A-Za-z0-9._-]+)?/);
  return match ? match[0] : null;
}

function toError(error: { message: string }): FinanceActionResult<never> {
  return {
    ok: false,
    error: getRpcErrorMessage(extractRpcCode(error.message)),
  };
}

/** Ngày hôm nay theo giờ Việt Nam (YYYY-MM-DD). */
export function todayVn(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/** Quyền tài chính của người gọi tại 1 property. */
export async function getFinancePerms(
  propertyId: string,
): Promise<FinancePerms> {
  const supabase = await createClient();
  const { data } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  const perms = new Set(data ?? []);
  return {
    canManageInvoice: perms.has("invoice.manage"),
    canApproveInvoice: perms.has("invoice.approve"),
    canViewAp: perms.has("ap.view"),
    canRequestPayment: perms.has("payment.request"),
    canApprovePayment: perms.has("payment.approve"),
    canMarkPaid: perms.has("payment.mark_paid"),
    canSettleAdvance: perms.has("advance.settle"),
  };
}

const INVOICE_COLUMNS =
  "id, org_id, property_id, supplier_id, doc_no, invoice_symbol, invoice_no, invoice_date, lookup_code, amount_before_tax, vat_amount, total, status, created_by, created_at";

type RawInvoiceRow = Omit<InvoiceRow, "supplier_name" | "supplier_code"> & {
  supplier: { name: string; code: string } | null;
};

function toInvoiceRow(raw: RawInvoiceRow): InvoiceRow {
  const { supplier, ...rest } = raw;
  return {
    ...rest,
    supplier_name: supplier?.name ?? null,
    supplier_code: supplier?.code ?? null,
  };
}

/** Danh sách hóa đơn của 1 property (mới nhất trước). */
export async function listInvoices(
  propertyId: string,
  opts: {
    status?: InvoiceStatus | null;
    supplierId?: string | null;
    from?: string | null;
    to?: string | null;
  } = {},
): Promise<FinanceActionResult<InvoiceRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("supplier_invoices")
    .select(`${INVOICE_COLUMNS}, supplier:suppliers(name, code)`)
    .eq("property_id", propertyId)
    .order("invoice_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(100);
  if (opts.status) query = query.eq("status", opts.status);
  if (opts.supplierId) query = query.eq("supplier_id", opts.supplierId);
  if (opts.from) query = query.gte("invoice_date", opts.from);
  if (opts.to) query = query.lte("invoice_date", opts.to);
  const { data, error } = await query;
  if (error) return toError(error);
  return {
    ok: true,
    data: ((data ?? []) as unknown as RawInvoiceRow[]).map(toInvoiceRow),
  };
}

/** 1 hóa đơn + các dòng (kèm tên hàng khi caller có `item.view`). */
export async function getInvoice(
  invoiceId: string,
): Promise<FinanceActionResult<InvoiceDetail>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("supplier_invoices")
    .select(`${INVOICE_COLUMNS}, supplier:suppliers(name, code)`)
    .eq("id", invoiceId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: false, error: getRpcErrorMessage(null) };
  const invoice = toInvoiceRow(data as unknown as RawInvoiceRow);
  const { data: linesData, error: linesError } = await client
    .from("supplier_invoice_lines")
    .select(
      "id, invoice_id, po_line_id, gr_line_id, item_id, qty, unit_price, amount, vat_rate, vat_amount, match_result, item:items(code, name)",
    )
    .eq("invoice_id", invoiceId)
    .order("created_at", { ascending: true });
  if (linesError) return toError(linesError);
  const lines = (
    (linesData ?? []) as unknown as Array<{
      id: string;
      invoice_id: string;
      po_line_id: string;
      gr_line_id: string | null;
      item_id: string | null;
      qty: number;
      unit_price: number;
      amount: number;
      vat_rate: number;
      vat_amount: number;
      match_result: InvoiceMatchResult | null;
      item: { code: string; name: string } | null;
    }>
  ).map((l) => ({
    id: l.id,
    invoice_id: l.invoice_id,
    po_line_id: l.po_line_id,
    gr_line_id: l.gr_line_id,
    item_id: l.item_id,
    item_code: l.item?.code ?? null,
    item_name: l.item?.name ?? null,
    qty: l.qty,
    unit_price: l.unit_price,
    amount: l.amount,
    vat_rate: l.vat_rate,
    vat_amount: l.vat_amount,
    match_result:
      l.match_result && Object.keys(l.match_result).length > 0
        ? l.match_result
        : null,
  }));
  return { ok: true, data: { invoice, lines } };
}

const LISTING_COLUMNS =
  "id, org_id, property_id, po_id, gr_id, doc_no, seller_name, seller_address, seller_id_no, purchase_date, status, total, created_by, created_at";

/** Danh sách bảng kê không hóa đơn của 1 property (mới nhất trước). */
export async function listNoInvoiceListings(
  propertyId: string,
  status: NoInvoiceListingStatus | null,
): Promise<FinanceActionResult<NoInvoiceListingRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("no_invoice_listings")
    .select(LISTING_COLUMNS)
    .eq("property_id", propertyId)
    .order("purchase_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(100);
  if (status) query = query.eq("status", status);
  const { data, error } = await query;
  if (error) return toError(error);
  return { ok: true, data: (data ?? []) as unknown as NoInvoiceListingRow[] };
}

/** 1 bảng kê + các dòng. */
export async function getNoInvoiceListing(
  listingId: string,
): Promise<FinanceActionResult<NoInvoiceListingDetail>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("no_invoice_listings")
    .select(LISTING_COLUMNS)
    .eq("id", listingId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: false, error: getRpcErrorMessage(null) };
  const { data: linesData, error: linesError } = await client
    .from("no_invoice_listing_lines")
    .select("id, listing_id, item_desc, qty, unit_price, amount")
    .eq("listing_id", listingId)
    .order("created_at", { ascending: true });
  if (linesError) return toError(linesError);
  return {
    ok: true,
    data: {
      listing: data as unknown as NoInvoiceListingRow,
      lines: (linesData ?? []) as unknown as NoInvoiceListingLineRow[],
    },
  };
}

/** Sổ công nợ của 1 property (mới nhất trước, tối đa 500 dòng). */
export async function listApLedger(
  propertyId: string,
  opts: { supplierId?: string | null } = {},
): Promise<FinanceActionResult<ApLedgerRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("ap_ledger")
    .select(
      "id, org_id, legal_entity_id, property_id, supplier_id, doc_type, doc_id, amount, due_date, entry_date, created_at, supplier:suppliers(name, code)",
    )
    .eq("property_id", propertyId)
    .order("entry_date", { ascending: false })
    .order("created_at", { ascending: false })
    .limit(500);
  if (opts.supplierId) query = query.eq("supplier_id", opts.supplierId);
  const { data, error } = await query;
  if (error) return toError(error);
  const rows = (
    (data ?? []) as unknown as Array<
      Omit<ApLedgerRow, "supplier_name" | "supplier_code"> & {
        supplier: { name: string; code: string } | null;
      }
    >
  ).map((r) => {
    const { supplier, ...rest } = r;
    return {
      ...rest,
      supplier_name: supplier?.name ?? null,
      supplier_code: supplier?.code ?? null,
    };
  });
  return { ok: true, data: rows };
}

/**
 * Tuổi nợ theo NCC (đọc `ap_ledger`).
 * Quy ước hiển thị: khoản phải trả là các bút toán amount > 0 (hóa đơn
 * duyệt, bảng kê — nếu có); tiền đã trả/trả hàng là các bút toán
 * amount < 0, phân bổ FIFO vào khoản phải trả có hạn trả sớm nhất.
 * Phần còn nợ của mỗi khoản xếp nhóm theo ngày quá hạn tính từ
 * `due_date` (khoản chưa có hạn trả tính theo `entry_date`).
 */
export async function getApAging(
  propertyId: string,
): Promise<FinanceActionResult<SupplierAgingRow[]>> {
  const ledgerRes = await listApLedger(propertyId);
  if (!ledgerRes.ok) return ledgerRes;
  const today = todayVn();
  const todayMs = new Date(`${today}T00:00:00+07:00`).getTime();

  type PositiveEntry = { due: string; amount: number };
  const bySupplier = new Map<
    string,
    {
      name: string | null;
      code: string | null;
      positives: PositiveEntry[];
      paidPool: number;
    }
  >();
  for (const row of ledgerRes.data) {
    const cur = bySupplier.get(row.supplier_id) ?? {
      name: row.supplier_name,
      code: row.supplier_code,
      positives: [],
      paidPool: 0,
    };
    cur.name = row.supplier_name ?? cur.name;
    cur.code = row.supplier_code ?? cur.code;
    if (row.amount > 0) {
      cur.positives.push({
        due: row.due_date ?? row.entry_date,
        amount: row.amount,
      });
    } else {
      cur.paidPool += -row.amount;
    }
    bySupplier.set(row.supplier_id, cur);
  }

  const rows: SupplierAgingRow[] = [];
  for (const [supplierId, s] of bySupplier) {
    const payable = s.positives.reduce((sum, p) => sum + p.amount, 0);
    const paid = Math.min(s.paidPool, payable);
    const balance = payable - paid;
    // Phân bổ tiền đã trả FIFO theo hạn trả sớm nhất.
    let pool = paid;
    const remaining = [...s.positives]
      .sort((a, b) => a.due.localeCompare(b.due))
      .map((p) => {
        const covered = Math.min(pool, p.amount);
        pool -= covered;
        return { due: p.due, amount: p.amount - covered };
      })
      .filter((p) => p.amount > 0.0001);
    let notDue = 0;
    let overdue1to30 = 0;
    let overdue31to60 = 0;
    let overdue61to90 = 0;
    let overdueOver90 = 0;
    let oldestOverdueDays: number | null = null;
    for (const p of remaining) {
      const overdueDays = Math.floor(
        (todayMs - new Date(`${p.due}T00:00:00+07:00`).getTime()) / 86400000,
      );
      if (overdueDays <= 0) {
        notDue += p.amount;
      } else {
        oldestOverdueDays =
          oldestOverdueDays === null
            ? overdueDays
            : Math.max(oldestOverdueDays, overdueDays);
        if (overdueDays <= 30) overdue1to30 += p.amount;
        else if (overdueDays <= 60) overdue31to60 += p.amount;
        else if (overdueDays <= 90) overdue61to90 += p.amount;
        else overdueOver90 += p.amount;
      }
    }
    rows.push({
      supplier_id: supplierId,
      supplier_name: s.name,
      supplier_code: s.code,
      payable,
      paid,
      balance,
      notDue,
      overdue1to30,
      overdue31to60,
      overdue61to90,
      overdueOver90,
      oldestOverdueDays,
    });
  }
  rows.sort((a, b) => b.balance - a.balance);
  return { ok: true, data: rows };
}

/** Lịch sử quyết toán tạm ứng của 1 property (mới nhất trước). */
export async function listAdvanceSettlements(
  propertyId: string,
  advanceId: string | null,
): Promise<FinanceActionResult<AdvanceSettlementRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("advance_settlements")
    .select(
      "id, advance_id, doc_no, amount, refund_amount, extra_pay_amount, settled_by, settled_at, created_at, advance:advances(doc_no)",
    )
    .eq("property_id", propertyId)
    .order("settled_at", { ascending: false })
    .limit(100);
  if (advanceId) query = query.eq("advance_id", advanceId);
  const { data, error } = await query;
  if (error) return toError(error);
  const rows = (
    (data ?? []) as unknown as Array<
      Omit<AdvanceSettlementRow, "advance_doc_no"> & {
        advance: { doc_no: string } | null;
      }
    >
  ).map((r) => {
    const { advance, ...rest } = r;
    return { ...rest, advance_doc_no: advance?.doc_no ?? null };
  });
  return { ok: true, data: rows };
}

/** 1 dòng quyết toán kèm phiếu nhận đã gắn (C12/Q74). */
export type AdvanceSettlementLineRow = {
  id: string;
  settlement_id: string;
  settlement_doc_no: string;
  amount: number;
  gr_id: string | null;
  gr_doc_no: string | null;
  receipt_photo_id: string | null;
};

/**
 * Dòng quyết toán của các phiếu quyết toán cho trước (C12/Q74) — để
 * lịch sử quyết toán hiện phiếu nhận đã gắn + dòng nào có ảnh biên lai.
 * `gr_doc_no` null khi người xem không có `receiving.view` (policy
 * SELECT của goods_receipts) hoặc dòng không gắn phiếu nhận.
 */
export async function listAdvanceSettlementLines(
  settlementIds: string[],
): Promise<FinanceActionResult<AdvanceSettlementLineRow[]>> {
  if (settlementIds.length === 0) {
    return { ok: true, data: [] };
  }
  const supabase = await createClient();
  const { data, error } = await untyped(supabase)
    .from("advance_settlement_lines")
    .select(
      "id, settlement_id, amount, gr_id, receipt_photo_id, settlement:advance_settlements(doc_no), receipt:goods_receipts(doc_no)",
    )
    .in("settlement_id", settlementIds)
    .order("created_at", { ascending: true });
  if (error) return toError(error);
  const rows = (
    (data ?? []) as unknown as Array<{
      id: string;
      settlement_id: string;
      amount: number;
      gr_id: string | null;
      receipt_photo_id: string | null;
      settlement: { doc_no: string } | null;
      receipt: { doc_no: string } | null;
    }>
  ).map((r) => ({
    id: r.id,
    settlement_id: r.settlement_id,
    settlement_doc_no: r.settlement?.doc_no ?? "",
    amount: r.amount,
    gr_id: r.gr_id,
    gr_doc_no: r.receipt?.doc_no ?? null,
    receipt_photo_id: r.receipt_photo_id,
  }));
  return { ok: true, data: rows };
}

const PAYMENT_REQUEST_COLUMNS =
  "id, org_id, property_id, supplier_id, doc_no, total, due_date, status, paid_at, bank_ref, created_by, created_at";

type RawPaymentRequestRow = Omit<
  PaymentRequestRow,
  "supplier_name" | "supplier_code"
> & {
  supplier: { name: string; code: string } | null;
};

function toPaymentRequestRow(raw: RawPaymentRequestRow): PaymentRequestRow {
  const { supplier, ...rest } = raw;
  return {
    ...rest,
    supplier_name: supplier?.name ?? null,
    supplier_code: supplier?.code ?? null,
  };
}

/** Danh sách đề nghị thanh toán của 1 property (mới nhất trước). */
export async function listPaymentRequests(
  propertyId: string,
  opts: {
    status?: PaymentRequestStatus | null;
    supplierId?: string | null;
  } = {},
): Promise<FinanceActionResult<PaymentRequestRow[]>> {
  const supabase = await createClient();
  let query = untyped(supabase)
    .from("payment_requests")
    .select(`${PAYMENT_REQUEST_COLUMNS}, supplier:suppliers(name, code)`)
    .eq("property_id", propertyId)
    .order("created_at", { ascending: false })
    .limit(100);
  if (opts.status) query = query.eq("status", opts.status);
  if (opts.supplierId) query = query.eq("supplier_id", opts.supplierId);
  const { data, error } = await query;
  if (error) return toError(error);
  return {
    ok: true,
    data: ((data ?? []) as unknown as RawPaymentRequestRow[]).map(
      toPaymentRequestRow,
    ),
  };
}

/** 1 đề nghị thanh toán + các dòng (kèm hóa đơn + số còn lại). */
export async function getPaymentRequest(
  requestId: string,
): Promise<FinanceActionResult<PaymentRequestDetail>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data, error } = await client
    .from("payment_requests")
    .select(`${PAYMENT_REQUEST_COLUMNS}, supplier:suppliers(name, code)`)
    .eq("id", requestId)
    .maybeSingle();
  if (error) return toError(error);
  if (!data) return { ok: false, error: getRpcErrorMessage(null) };
  const request = toPaymentRequestRow(data as unknown as RawPaymentRequestRow);
  const { data: linesData, error: linesError } = await client
    .from("payment_request_lines")
    .select(
      "id, request_id, invoice_id, amount, invoice:supplier_invoices(doc_no, invoice_symbol, invoice_no, total, status)",
    )
    .eq("request_id", requestId)
    .order("created_at", { ascending: true });
  if (linesError) return toError(linesError);
  const lines = (
    (linesData ?? []) as unknown as Array<{
      id: string;
      request_id: string;
      invoice_id: string;
      amount: number;
      invoice: {
        doc_no: string;
        invoice_symbol: string;
        invoice_no: string;
        total: number;
        status: InvoiceStatus;
      } | null;
    }>
  ).map((l) => ({
    id: l.id,
    request_id: l.request_id,
    invoice_id: l.invoice_id,
    invoice_doc_no: l.invoice?.doc_no ?? null,
    invoice_symbol: l.invoice?.invoice_symbol ?? null,
    invoice_no: l.invoice?.invoice_no ?? null,
    invoice_total: l.invoice?.total ?? null,
    invoice_status: l.invoice?.status ?? null,
    amount: l.amount,
  }));
  return { ok: true, data: { request, lines } };
}

/**
 * Hóa đơn của 1 NCC còn số tiền chưa đề nghị thanh toán (phục vụ form
 * tạo đề nghị). `remaining` = total − đã trả (đề nghị `paid`) − đã đề
 * nghị (`submitted`/`approved`) — cùng công thức RPC
 * `payment_request_create` dùng để chặn vượt.
 */
export async function listPayableInvoices(
  propertyId: string,
  supplierId: string,
): Promise<FinanceActionResult<PayableInvoiceRow[]>> {
  const supabase = await createClient();
  const client = untyped(supabase);
  const { data: invoices, error } = await client
    .from("supplier_invoices")
    .select(
      "id, doc_no, invoice_symbol, invoice_no, invoice_date, total, status",
    )
    .eq("property_id", propertyId)
    .eq("supplier_id", supplierId)
    .in("status", ["approved", "partially_paid"])
    .order("invoice_date", { ascending: true });
  if (error) return toError(error);
  const invList = (invoices ?? []) as unknown as Array<{
    id: string;
    doc_no: string;
    invoice_symbol: string;
    invoice_no: string;
    invoice_date: string;
    total: number;
    status: InvoiceStatus;
  }>;
  if (invList.length === 0) {
    return { ok: true, data: [] };
  }
  const invIds = invList.map((i) => i.id);
  const { data: lines, error: linesError } = await client
    .from("payment_request_lines")
    .select("invoice_id, amount, request:payment_requests(status)")
    .in("invoice_id", invIds);
  if (linesError) return toError(linesError);
  const paidByInv = new Map<string, number>();
  const requestedByInv = new Map<string, number>();
  for (const l of (lines ?? []) as unknown as Array<{
    invoice_id: string;
    amount: number;
    request: { status: string } | null;
  }>) {
    if (l.request?.status === "paid") {
      paidByInv.set(
        l.invoice_id,
        (paidByInv.get(l.invoice_id) ?? 0) + Number(l.amount),
      );
    } else if (
      l.request?.status === "submitted" ||
      l.request?.status === "approved"
    ) {
      requestedByInv.set(
        l.invoice_id,
        (requestedByInv.get(l.invoice_id) ?? 0) + Number(l.amount),
      );
    }
  }
  const rows: PayableInvoiceRow[] = invList
    .map((inv) => ({
      ...inv,
      remaining:
        Number(inv.total) -
        (paidByInv.get(inv.id) ?? 0) -
        (requestedByInv.get(inv.id) ?? 0),
    }))
    .filter((r) => r.remaining > 0.0001);
  return { ok: true, data: rows };
}
