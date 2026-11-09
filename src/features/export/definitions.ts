import { vi } from "@/i18n/vi";

/**
 * Dinh nghia 5 loai xuat Excel ke toan (T-043): RPC, tieu de, ten sheet,
 * ten file, cot (header tieng Viet lay tu vi.ts — AGENTS.md muc 11).
 * So tien/so luong xuat dang so Excel that (xem workbook.ts).
 */

export type ExportKind =
  "goods-receipts" | "stock-issues" | "invoices" | "payables" | "advances";

export type ExportColumnFormat = "text" | "money" | "qty" | "int" | "date";

/** Anh xa gia tri ma -> nhan tieng Viet (vi.export.*Labels). */
export type ExportColumnMap = "moveType" | "docType" | "advanceStatus" | null;

export interface ExportColumn {
  key: string;
  header: string;
  /** Do rong cot (ky tu) trong Excel. */
  width: number;
  format: ExportColumnFormat;
  map?: ExportColumnMap;
}

export interface ExportDefinition {
  kind: ExportKind;
  rpc: string;
  /** Tien to ten file: <loai>-<ma-phap-nhan>-<tu>-<den>.xlsx */
  filePrefix: string;
  title: string;
  sheetName: string;
  columns: ExportColumn[];
  /** Cac cot lay tong tu payload.totals (theo key cot). */
  totalKeys: string[];
}

const C = vi.export.columns;

const DEFINITIONS: Record<ExportKind, ExportDefinition> = {
  "goods-receipts": {
    kind: "goods-receipts",
    rpc: "export_goods_receipts",
    filePrefix: "nhap-kho",
    title: vi.export.titles.goodsReceipts,
    sheetName: vi.export.sheets.goodsReceipts,
    columns: [
      {
        key: "received_date",
        header: C.receivedDate,
        width: 12,
        format: "date",
      },
      { key: "doc_no", header: C.docNo, width: 14, format: "text" },
      {
        key: "supplier_code",
        header: C.supplierCode,
        width: 10,
        format: "text",
      },
      {
        key: "supplier_name",
        header: C.supplierName,
        width: 32,
        format: "text",
      },
      {
        key: "warehouse_code",
        header: C.warehouseCode,
        width: 10,
        format: "text",
      },
      { key: "item_code", header: C.itemCode, width: 12, format: "text" },
      { key: "item_name", header: C.itemName, width: 32, format: "text" },
      { key: "uom", header: C.uom, width: 8, format: "text" },
      { key: "qty", header: C.qty, width: 12, format: "qty" },
      { key: "unit_cost", header: C.unitCost, width: 16, format: "money" },
      { key: "amount", header: C.amount, width: 18, format: "money" },
    ],
    totalKeys: ["qty", "amount"],
  },
  "stock-issues": {
    kind: "stock-issues",
    rpc: "export_stock_issues",
    filePrefix: "xuat-kho",
    title: vi.export.titles.stockIssues,
    sheetName: vi.export.sheets.stockIssues,
    columns: [
      {
        key: "business_date",
        header: C.businessDate,
        width: 12,
        format: "date",
      },
      {
        key: "doc_type",
        header: C.docType,
        width: 16,
        format: "text",
        map: "docType",
      },
      { key: "doc_no", header: C.docNo, width: 14, format: "text" },
      {
        key: "move_type",
        header: C.moveType,
        width: 18,
        format: "text",
        map: "moveType",
      },
      {
        key: "warehouse_code",
        header: C.fromWarehouse,
        width: 10,
        format: "text",
      },
      {
        key: "to_warehouse_code",
        header: C.toWarehouse,
        width: 10,
        format: "text",
      },
      { key: "item_code", header: C.itemCode, width: 12, format: "text" },
      { key: "item_name", header: C.itemName, width: 32, format: "text" },
      { key: "uom", header: C.uom, width: 8, format: "text" },
      { key: "qty", header: C.qty, width: 12, format: "qty" },
      { key: "unit_cost", header: C.unitCost, width: 16, format: "money" },
      { key: "amount", header: C.amount, width: 18, format: "money" },
      {
        key: "cost_center_code",
        header: C.costCenter,
        width: 12,
        format: "text",
      },
      {
        key: "expense_category_code",
        header: C.expenseCategory,
        width: 12,
        format: "text",
      },
    ],
    totalKeys: ["qty", "amount"],
  },
  invoices: {
    kind: "invoices",
    rpc: "export_invoices",
    filePrefix: "hoa-don-mua",
    title: vi.export.titles.invoices,
    sheetName: vi.export.sheets.invoices,
    columns: [
      { key: "invoice_date", header: C.invoiceDate, width: 12, format: "date" },
      {
        key: "invoice_symbol",
        header: C.invoiceSymbol,
        width: 10,
        format: "text",
      },
      { key: "invoice_no", header: C.invoiceNo, width: 12, format: "text" },
      { key: "doc_no", header: C.docNo, width: 14, format: "text" },
      {
        key: "supplier_code",
        header: C.supplierCode,
        width: 10,
        format: "text",
      },
      {
        key: "supplier_name",
        header: C.supplierName,
        width: 32,
        format: "text",
      },
      { key: "po_doc_no", header: C.poDocNo, width: 14, format: "text" },
      { key: "item_code", header: C.itemCode, width: 12, format: "text" },
      { key: "item_name", header: C.itemName, width: 32, format: "text" },
      { key: "qty", header: C.qty, width: 12, format: "qty" },
      { key: "unit_price", header: C.unitPrice, width: 16, format: "money" },
      { key: "amount", header: C.amount, width: 18, format: "money" },
      { key: "vat_rate", header: C.vatRate, width: 10, format: "money" },
      { key: "vat_amount", header: C.vatAmount, width: 16, format: "money" },
      { key: "match_reason", header: C.matchReason, width: 28, format: "text" },
    ],
    totalKeys: ["qty", "amount", "vat_amount"],
  },
  payables: {
    kind: "payables",
    rpc: "export_payables",
    filePrefix: "cong-no",
    title: vi.export.titles.payables,
    sheetName: vi.export.sheets.payables,
    columns: [
      {
        key: "supplier_code",
        header: C.supplierCode,
        width: 10,
        format: "text",
      },
      {
        key: "supplier_name",
        header: C.supplierName,
        width: 32,
        format: "text",
      },
      { key: "payable", header: C.payable, width: 18, format: "money" },
      { key: "paid", header: C.paid, width: 18, format: "money" },
      { key: "balance", header: C.balance, width: 18, format: "money" },
      { key: "not_due", header: C.notDue, width: 18, format: "money" },
      {
        key: "overdue_1_30",
        header: C.overdue1to30,
        width: 18,
        format: "money",
      },
      {
        key: "overdue_31_60",
        header: C.overdue31to60,
        width: 18,
        format: "money",
      },
      {
        key: "overdue_61_90",
        header: C.overdue61to90,
        width: 18,
        format: "money",
      },
      {
        key: "overdue_over_90",
        header: C.overdueOver90,
        width: 18,
        format: "money",
      },
      {
        key: "oldest_overdue_days",
        header: C.oldestOverdueDays,
        width: 14,
        format: "int",
      },
    ],
    totalKeys: [
      "payable",
      "paid",
      "balance",
      "not_due",
      "overdue_1_30",
      "overdue_31_60",
      "overdue_61_90",
      "overdue_over_90",
    ],
  },
  advances: {
    kind: "advances",
    rpc: "export_advances",
    filePrefix: "tam-ung",
    title: vi.export.titles.advances,
    sheetName: vi.export.sheets.advances,
    columns: [
      { key: "doc_no", header: C.docNo, width: 14, format: "text" },
      {
        key: "employee_code",
        header: C.employeeCode,
        width: 10,
        format: "text",
      },
      {
        key: "employee_name",
        header: C.employeeName,
        width: 24,
        format: "text",
      },
      { key: "amount", header: C.amount, width: 18, format: "money" },
      { key: "purpose", header: C.purpose, width: 28, format: "text" },
      {
        key: "requested_date",
        header: C.requestedDate,
        width: 12,
        format: "date",
      },
      {
        key: "disbursed_date",
        header: C.disbursedDate,
        width: 12,
        format: "date",
      },
      {
        key: "due_settle_date",
        header: C.dueSettleDate,
        width: 12,
        format: "date",
      },
      {
        key: "settled_amount",
        header: C.settledAmount,
        width: 18,
        format: "money",
      },
      {
        key: "refund_amount",
        header: C.refundAmount,
        width: 16,
        format: "money",
      },
      {
        key: "extra_pay_amount",
        header: C.extraPayAmount,
        width: 16,
        format: "money",
      },
      { key: "settled_date", header: C.settledDate, width: 12, format: "date" },
      {
        key: "status",
        header: C.status,
        width: 16,
        format: "text",
        map: "advanceStatus",
      },
    ],
    totalKeys: [
      "amount",
      "settled_amount",
      "refund_amount",
      "extra_pay_amount",
    ],
  },
};

export function getExportDefinition(kind: string): ExportDefinition | null {
  if (kind in DEFINITIONS) {
    return DEFINITIONS[kind as ExportKind];
  }
  return null;
}

export const EXPORT_KINDS: ExportKind[] = [
  "goods-receipts",
  "stock-issues",
  "invoices",
  "payables",
  "advances",
];
