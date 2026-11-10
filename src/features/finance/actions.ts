"use server";

import { revalidatePath } from "next/cache";
import { createClient } from "@/lib/supabase/server";
import { callFinanceRpc, type FinanceActionResult } from "./rpc";
import {
  advanceSettleSchema,
  invoiceApproveSchema,
  invoiceMatchSchema,
  invoiceSaveDraftSchema,
  noInvoiceListingApproveSchema,
  noInvoiceListingSaveSchema,
  paymentMarkPaidSchema,
  paymentRequestCreateSchema,
  paymentRequestDecideSchema,
  type AdvanceSettleInput,
  type InvoiceApproveInput,
  type InvoiceMatchInput,
  type InvoiceSaveDraftInput,
  type NoInvoiceListingApproveInput,
  type NoInvoiceListingSaveInput,
  type PaymentMarkPaidInput,
  type PaymentRequestCreateInput,
  type PaymentRequestDecideInput,
} from "./schemas";

export type InvoiceSaveResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  total: number;
};

export type InvoiceMatchResult = {
  ok: boolean;
  id: string;
  status: string;
  lines: Array<{
    line_id: string;
    po_line_id: string;
    qty_ok: boolean;
    price_ok: boolean;
    reason: string | null;
  }>;
};

export type InvoiceApproveResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
};

export type AdvanceSettleResult = {
  ok: boolean;
  id: string;
  advance_id: string;
  doc_no: string;
  spent: number;
  refund_amount: number;
  extra_pay_amount: number;
  status: string;
};

export type PaymentRequestCreateResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  total: number;
};

export type PaymentRequestDecideResult = {
  ok: boolean;
  id: string;
  status: string;
};

export type PaymentMarkPaidResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
};

export type NoInvoiceListingSaveResult = {
  ok: boolean;
  id: string;
  doc_no: string;
  status: string;
  total: number;
};

function validationError(
  issues: { message: string }[],
): FinanceActionResult<never> {
  return { ok: false, error: issues[0]?.message ?? "Dữ liệu không hợp lệ." };
}

function invoicesPath(propertyId: string): string {
  return `/${propertyId}/finance/invoices`;
}

function invoiceDetailPath(propertyId: string, invoiceId: string): string {
  return `/${propertyId}/finance/invoices/${invoiceId}`;
}

function payablesPath(propertyId: string): string {
  return `/${propertyId}/finance/payables`;
}

function advancesPath(propertyId: string): string {
  return `/${propertyId}/finance/advances`;
}

function advanceDetailPath(propertyId: string, advanceId: string): string {
  return `/${propertyId}/finance/advances/${advanceId}`;
}

function paymentRequestsPath(propertyId: string): string {
  return `/${propertyId}/finance/payment-requests`;
}

function paymentRequestDetailPath(
  propertyId: string,
  requestId: string,
): string {
  return `/${propertyId}/finance/payment-requests/${requestId}`;
}

function listingsPath(propertyId: string): string {
  return `/${propertyId}/finance/no-invoice-listings`;
}

/** Nhập hóa đơn mới (RPC `invoice_save_draft`). */
export async function saveInvoiceDraftAction(
  input: InvoiceSaveDraftInput,
): Promise<FinanceActionResult<InvoiceSaveResult>> {
  const parsed = invoiceSaveDraftSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<InvoiceSaveResult>(
    supabase,
    "invoice_save_draft",
    {
      p_property_id: parsed.data.propertyId,
      p_supplier_id: parsed.data.supplierId,
      p_header: {
        invoice_symbol: parsed.data.header.invoiceSymbol,
        invoice_no: parsed.data.header.invoiceNo,
        invoice_date: parsed.data.header.invoiceDate,
        lookup_code: parsed.data.header.lookupCode ?? null,
        xml_path: parsed.data.header.xmlPath ?? null,
      },
      p_lines: parsed.data.lines.map((l) => ({
        po_line_id: l.poLineId,
        qty: l.qty,
        unit_price: l.unitPrice,
        vat_rate: l.vatRate ?? null,
        gr_line_id: l.grLineId ?? null,
      })),
    },
  );
  if (res.ok) {
    revalidatePath(invoicesPath(parsed.data.propertyId));
    revalidatePath(payablesPath(parsed.data.propertyId));
  }
  return res;
}

/** Khớp 3 chiều 1 hóa đơn (RPC `invoice_match`). */
export async function matchInvoiceAction(
  input: InvoiceMatchInput,
): Promise<FinanceActionResult<InvoiceMatchResult>> {
  const parsed = invoiceMatchSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<InvoiceMatchResult>(
    supabase,
    "invoice_match",
    { p_invoice_id: parsed.data.invoiceId },
  );
  if (res.ok) {
    revalidatePath(invoicesPath(parsed.data.propertyId));
    revalidatePath(
      invoiceDetailPath(parsed.data.propertyId, parsed.data.invoiceId),
    );
  }
  return res;
}

/** Duyệt hóa đơn đã khớp (RPC `invoice_approve`, SoD người tạo không tự duyệt). */
export async function approveInvoiceAction(
  input: InvoiceApproveInput,
): Promise<FinanceActionResult<InvoiceApproveResult>> {
  const parsed = invoiceApproveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<InvoiceApproveResult>(
    supabase,
    "invoice_approve",
    { p_invoice_id: parsed.data.invoiceId },
  );
  if (res.ok) {
    revalidatePath(invoicesPath(parsed.data.propertyId));
    revalidatePath(
      invoiceDetailPath(parsed.data.propertyId, parsed.data.invoiceId),
    );
    revalidatePath(payablesPath(parsed.data.propertyId));
    revalidatePath(paymentRequestsPath(parsed.data.propertyId));
  }
  return res;
}

/** Quyết toán tạm ứng theo số thực nhận (RPC `advance_settle`). */
export async function settleAdvanceAction(
  input: AdvanceSettleInput,
): Promise<FinanceActionResult<AdvanceSettleResult>> {
  const parsed = advanceSettleSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<AdvanceSettleResult>(
    supabase,
    "advance_settle",
    {
      p_id: parsed.data.advanceId,
      p_lines: parsed.data.lines.map((l) => ({
        amount: l.amount,
        gr_id: l.grId ?? null,
        receipt_photo_id: l.receiptPhotoId ?? null,
      })),
    },
  );
  if (res.ok) {
    revalidatePath(advancesPath(parsed.data.propertyId));
    revalidatePath(
      advanceDetailPath(parsed.data.propertyId, parsed.data.advanceId),
    );
  }
  return res;
}

/** Tạo đề nghị thanh toán (RPC `payment_request_create`). */
export async function createPaymentRequestAction(
  input: PaymentRequestCreateInput,
): Promise<FinanceActionResult<PaymentRequestCreateResult>> {
  const parsed = paymentRequestCreateSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<PaymentRequestCreateResult>(
    supabase,
    "payment_request_create",
    {
      p_property_id: parsed.data.propertyId,
      p_supplier_id: parsed.data.supplierId,
      p_lines: parsed.data.lines.map((l) => ({
        invoice_id: l.invoiceId,
        amount: l.amount,
      })),
      p_due_date: parsed.data.dueDate ?? null,
    },
  );
  if (res.ok) {
    revalidatePath(paymentRequestsPath(parsed.data.propertyId));
    revalidatePath(payablesPath(parsed.data.propertyId));
  }
  return res;
}

/** Duyệt/từ chối đề nghị thanh toán (RPC `payment_request_decide`). */
export async function decidePaymentRequestAction(
  input: PaymentRequestDecideInput,
): Promise<FinanceActionResult<PaymentRequestDecideResult>> {
  const parsed = paymentRequestDecideSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<PaymentRequestDecideResult>(
    supabase,
    "payment_request_decide",
    {
      p_property_id: parsed.data.propertyId,
      p_request_id: parsed.data.requestId,
      p_decision: parsed.data.decision,
      p_comment: parsed.data.comment ?? null,
    },
  );
  if (res.ok) {
    revalidatePath(paymentRequestsPath(parsed.data.propertyId));
    revalidatePath(
      paymentRequestDetailPath(parsed.data.propertyId, parsed.data.requestId),
    );
    revalidatePath(payablesPath(parsed.data.propertyId));
  }
  return res;
}

/** Ghi nhận đã thanh toán (RPC `payment_mark_paid`, ap_ledger (−)). */
export async function markPaymentPaidAction(
  input: PaymentMarkPaidInput,
): Promise<FinanceActionResult<PaymentMarkPaidResult>> {
  const parsed = paymentMarkPaidSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<PaymentMarkPaidResult>(
    supabase,
    "payment_mark_paid",
    {
      p_id: parsed.data.requestId,
      p_bank_ref: parsed.data.bankRef,
    },
  );
  if (res.ok) {
    revalidatePath(paymentRequestsPath(parsed.data.propertyId));
    revalidatePath(
      paymentRequestDetailPath(parsed.data.propertyId, parsed.data.requestId),
    );
    revalidatePath(payablesPath(parsed.data.propertyId));
    revalidatePath(invoicesPath(parsed.data.propertyId));
  }
  return res;
}

/** Nhập bảng kê mua hàng không hóa đơn (RPC `no_invoice_listing_save`). */
export async function saveNoInvoiceListingAction(
  input: NoInvoiceListingSaveInput,
): Promise<FinanceActionResult<NoInvoiceListingSaveResult>> {
  const parsed = noInvoiceListingSaveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<NoInvoiceListingSaveResult>(
    supabase,
    "no_invoice_listing_save",
    {
      p_property_id: parsed.data.propertyId,
      p_listing: {
        seller_name: parsed.data.listing.sellerName,
        purchase_date: parsed.data.listing.purchaseDate,
        po_id: parsed.data.listing.poId ?? null,
        gr_id: parsed.data.listing.grId ?? null,
        seller_address: parsed.data.listing.sellerAddress ?? null,
        seller_id_no: parsed.data.listing.sellerIdNo ?? null,
      },
      p_lines: parsed.data.lines.map((l) => ({
        item_desc: l.itemDesc,
        qty: l.qty,
        unit_price: l.unitPrice,
      })),
    },
  );
  if (res.ok) {
    revalidatePath(listingsPath(parsed.data.propertyId));
  }
  return res;
}

/** Duyệt bảng kê (RPC `no_invoice_listing_approve`, không ghi ap_ledger — Q71). */
export async function approveNoInvoiceListingAction(
  input: NoInvoiceListingApproveInput,
): Promise<
  FinanceActionResult<{
    ok: boolean;
    id: string;
    doc_no: string;
    status: string;
  }>
> {
  const parsed = noInvoiceListingApproveSchema.safeParse(input);
  if (!parsed.success) {
    return validationError(parsed.error.issues);
  }
  const supabase = await createClient();
  const res = await callFinanceRpc<{
    ok: boolean;
    id: string;
    doc_no: string;
    status: string;
  }>(supabase, "no_invoice_listing_approve", {
    p_listing_id: parsed.data.listingId,
  });
  if (res.ok) {
    revalidatePath(listingsPath(parsed.data.propertyId));
  }
  return res;
}

export type {
  AdvanceSettlementRow,
  ApLedgerRow,
  FinancePerms,
  InvoiceDetail,
  InvoiceLineRow,
  InvoiceMatchResult as InvoiceMatchDetail,
  InvoiceRow,
  InvoiceStatus,
  NoInvoiceListingDetail,
  NoInvoiceListingLineRow,
  NoInvoiceListingRow,
  NoInvoiceListingStatus,
  PayableInvoiceRow,
  PaymentRequestDetail,
  PaymentRequestLineRow,
  PaymentRequestRow,
  PaymentRequestStatus,
  SupplierAgingRow,
} from "./queries";
