import { vi } from "@/i18n/vi";

/** 10 báo cáo MVP (docs/08-REPORTS-ALERTS.md §1) + doanh thu F&B (M06). Slug dùng trên URL. */
export const REPORT_CODES = [
  "RPT_STOCK_CARD",
  "RPT_RECEIVING_QUALITY",
  "RPT_OPEN_PO_INVOICE",
  "RPT_AP_AGING",
  "RPT_ADVANCES",
  "RPT_WASTE",
  "RPT_OPEX",
  "RPT_MINIBAR",
  "RPT_AMENITY_CPOR",
  "RPT_DAILY_BRIEF",
  "RPT_FNB_REVENUE",
] as const;

export type ReportCode = (typeof REPORT_CODES)[number];

export type ReportParamKind = "range" | "as_of" | "month" | "date";

export type ReportColumnKind =
  "text" | "number" | "money" | "date" | "pct" | "int";

export type ReportColumn = {
  key: string;
  label: string;
  kind: ReportColumnKind;
};

export type ReportTotal = {
  key: string;
  label: string;
  kind: ReportColumnKind;
};

export type ExportKind =
  "goods-receipts" | "stock-issues" | "invoices" | "payables" | "advances";

export type ReportMeta = {
  code: ReportCode;
  /** Slug trên URL: /[property]/reports/<slug>. */
  slug: string;
  title: string;
  description: string;
  permission: string;
  paramKind: ReportParamKind;
  /** Cột bảng chính (rỗng với bản tin 8h — render riêng). */
  columns: ReportColumn[];
  totals: ReportTotal[];
  /** Loại xuất Excel T-043 tương ứng (nếu có). */
  exportKind?: ExportKind;
};

const t = vi.reports;

export const REPORT_META: ReportMeta[] = [
  {
    code: "RPT_STOCK_CARD",
    slug: "stock-card",
    title: t.titles.stockCard,
    description: t.descriptions.stockCard,
    permission: "report.view.rpt_stock_card",
    paramKind: "range",
    columns: [
      { key: "warehouse_name", label: t.columns.warehouse, kind: "text" },
      { key: "item_code", label: t.columns.itemCode, kind: "text" },
      { key: "item_name", label: t.columns.itemName, kind: "text" },
      { key: "lot_no", label: t.columns.lotNo, kind: "text" },
      { key: "expiry_date", label: t.columns.expiryDate, kind: "date" },
      { key: "opening_qty", label: t.columns.openingQty, kind: "number" },
      { key: "in_qty", label: t.columns.inQty, kind: "number" },
      { key: "out_qty", label: t.columns.outQty, kind: "number" },
      { key: "closing_qty", label: t.columns.closingQty, kind: "number" },
      { key: "opening_value", label: t.columns.openingValue, kind: "money" },
      { key: "in_value", label: t.columns.inValue, kind: "money" },
      { key: "out_value", label: t.columns.outValue, kind: "money" },
      { key: "closing_value", label: t.columns.closingValue, kind: "money" },
    ],
    totals: [
      { key: "row_count", label: t.totals.rowCount, kind: "int" },
      { key: "closing_value", label: t.totals.closingValue, kind: "money" },
    ],
  },
  {
    code: "RPT_RECEIVING_QUALITY",
    slug: "receiving-quality",
    title: t.titles.receivingQuality,
    description: t.descriptions.receivingQuality,
    permission: "report.view.rpt_receiving_quality",
    paramKind: "range",
    columns: [
      { key: "supplier_name", label: t.columns.supplier, kind: "text" },
      { key: "gr_count", label: t.columns.grCount, kind: "int" },
      { key: "line_count", label: t.columns.lineCount, kind: "int" },
      { key: "ordered_qty", label: t.columns.orderedQty, kind: "number" },
      { key: "received_qty", label: t.columns.receivedQty, kind: "number" },
      { key: "short_qty", label: t.columns.shortQty, kind: "number" },
      { key: "short_pct", label: t.columns.shortPct, kind: "pct" },
      { key: "reweigh_count", label: t.columns.reweighCount, kind: "int" },
      { key: "qc_fail_count", label: t.columns.qcFailCount, kind: "int" },
      { key: "return_count", label: t.columns.returnCount, kind: "int" },
      { key: "return_qty", label: t.columns.returnQty, kind: "number" },
    ],
    totals: [
      { key: "gr_count", label: t.totals.grCount, kind: "int" },
      { key: "short_qty", label: t.totals.shortQty, kind: "number" },
      { key: "reweigh_count", label: t.totals.reweighCount, kind: "int" },
      { key: "qc_fail_count", label: t.totals.qcFailCount, kind: "int" },
      { key: "return_count", label: t.totals.returnCount, kind: "int" },
    ],
    exportKind: "goods-receipts",
  },
  {
    code: "RPT_OPEN_PO_INVOICE",
    slug: "open-po-invoice",
    title: t.titles.openPoInvoice,
    description: t.descriptions.openPoInvoice,
    permission: "report.view.rpt_open_po_invoice",
    paramKind: "as_of",
    columns: [
      { key: "doc_no", label: t.columns.docNo, kind: "text" },
      { key: "supplier_name", label: t.columns.supplier, kind: "text" },
      { key: "order_date", label: t.columns.orderDate, kind: "date" },
      { key: "expected_date", label: t.columns.expectedDate, kind: "date" },
      { key: "status", label: t.columns.status, kind: "text" },
      { key: "ordered_amount", label: t.columns.orderedAmount, kind: "money" },
      {
        key: "received_amount",
        label: t.columns.receivedAmount,
        kind: "money",
      },
      {
        key: "remaining_amount",
        label: t.columns.remainingAmount,
        kind: "money",
      },
      { key: "overdue_days", label: t.columns.overdueDays, kind: "int" },
    ],
    totals: [
      { key: "open_po_count", label: t.totals.openPoCount, kind: "int" },
      {
        key: "open_po_remaining_amount",
        label: t.totals.openPoRemainingAmount,
        kind: "money",
      },
      { key: "on_hold_count", label: t.totals.onHoldCount, kind: "int" },
      { key: "on_hold_amount", label: t.totals.onHoldAmount, kind: "money" },
    ],
    exportKind: "invoices",
  },
  {
    code: "RPT_AP_AGING",
    slug: "ap-aging",
    title: t.titles.apAging,
    description: t.descriptions.apAging,
    permission: "report.view.rpt_ap_aging",
    paramKind: "as_of",
    columns: [
      { key: "supplier_name", label: t.columns.supplier, kind: "text" },
      { key: "not_due", label: t.columns.notDue, kind: "money" },
      { key: "overdue_1_30", label: t.columns.overdue1to30, kind: "money" },
      { key: "overdue_31_60", label: t.columns.overdue31to60, kind: "money" },
      { key: "overdue_61_90", label: t.columns.overdue61to90, kind: "money" },
      { key: "overdue_over_90", label: t.columns.overdueOver90, kind: "money" },
      { key: "forecast_14d", label: t.columns.forecast14d, kind: "money" },
      { key: "total", label: t.columns.total, kind: "money" },
    ],
    totals: [
      { key: "total", label: t.totals.totalPayable, kind: "money" },
      { key: "not_due", label: t.totals.notDue, kind: "money" },
      { key: "overdue_1_30", label: t.totals.overdue1to30, kind: "money" },
      { key: "overdue_31_60", label: t.totals.overdue31to60, kind: "money" },
      { key: "overdue_61_90", label: t.totals.overdue61to90, kind: "money" },
      { key: "overdue_over_90", label: t.totals.overdueOver90, kind: "money" },
      { key: "forecast_14d", label: t.totals.forecast14d, kind: "money" },
    ],
    exportKind: "payables",
  },
  {
    code: "RPT_ADVANCES",
    slug: "advances",
    title: t.titles.advances,
    description: t.descriptions.advances,
    permission: "report.view.rpt_advances",
    paramKind: "as_of",
    columns: [
      { key: "doc_no", label: t.columns.docNo, kind: "text" },
      { key: "employee_name", label: t.columns.employee, kind: "text" },
      { key: "purpose", label: t.columns.purpose, kind: "text" },
      { key: "amount", label: t.columns.amount, kind: "money" },
      { key: "settled_amount", label: t.columns.settledAmount, kind: "money" },
      {
        key: "remaining_amount",
        label: t.columns.remainingAmount,
        kind: "money",
      },
      { key: "due_settle_at", label: t.columns.dueSettleAt, kind: "date" },
      { key: "overdue_hours", label: t.columns.overdueHours, kind: "int" },
      { key: "status", label: t.columns.status, kind: "text" },
    ],
    totals: [
      { key: "count", label: t.totals.advanceCount, kind: "int" },
      {
        key: "remaining_amount",
        label: t.totals.remainingAmount,
        kind: "money",
      },
      { key: "overdue_count", label: t.totals.overdueCount, kind: "int" },
    ],
    exportKind: "advances",
  },
  {
    code: "RPT_WASTE",
    slug: "waste",
    title: t.titles.waste,
    description: t.descriptions.waste,
    permission: "report.view.rpt_waste",
    paramKind: "range",
    columns: [
      { key: "reason_code", label: t.columns.reasonCode, kind: "text" },
      { key: "warehouse_name", label: t.columns.warehouse, kind: "text" },
      { key: "outlet_name", label: t.columns.outlet, kind: "text" },
      { key: "proposer_name", label: t.columns.proposer, kind: "text" },
      { key: "doc_count", label: t.columns.docCount, kind: "int" },
      { key: "qty", label: t.columns.qty, kind: "number" },
      { key: "value", label: t.columns.value, kind: "money" },
      { key: "value_share_pct", label: t.columns.valueSharePct, kind: "pct" },
    ],
    totals: [
      { key: "doc_count", label: t.totals.docCount, kind: "int" },
      { key: "total_value", label: t.totals.totalValue, kind: "money" },
      { key: "received_value", label: t.totals.receivedValue, kind: "money" },
      {
        key: "waste_pct_of_received",
        label: t.totals.wastePctOfReceived,
        kind: "pct",
      },
    ],
    exportKind: "stock-issues",
  },
  {
    code: "RPT_OPEX",
    slug: "opex",
    title: t.titles.opex,
    description: t.descriptions.opex,
    permission: "report.view.rpt_opex",
    paramKind: "month",
    columns: [
      {
        key: "expense_category_name",
        label: t.columns.expenseCategory,
        kind: "text",
      },
      { key: "cost_center_name", label: t.columns.costCenter, kind: "text" },
      { key: "moves_cost", label: t.columns.movesCost, kind: "money" },
      { key: "service_cost", label: t.columns.serviceCost, kind: "money" },
      { key: "invoice_cost", label: t.columns.invoiceCost, kind: "money" },
      { key: "total_cost", label: t.columns.totalCost, kind: "money" },
      { key: "cpor", label: t.columns.cpor, kind: "money" },
    ],
    totals: [
      { key: "total_cost", label: t.totals.totalCost, kind: "money" },
      { key: "rooms_sold", label: t.totals.roomsSold, kind: "int" },
      { key: "cpor", label: t.totals.cpor, kind: "money" },
    ],
  },
  {
    code: "RPT_MINIBAR",
    slug: "minibar",
    title: t.titles.minibar,
    description: t.descriptions.minibar,
    permission: "report.view.rpt_minibar",
    paramKind: "range",
    columns: [
      { key: "item_code", label: t.columns.itemCode, kind: "text" },
      { key: "item_name", label: t.columns.itemName, kind: "text" },
      { key: "units_sold", label: t.columns.unitsSold, kind: "number" },
      { key: "revenue", label: t.columns.revenue, kind: "money" },
      { key: "cogs", label: t.columns.cogs, kind: "money" },
      { key: "gross_profit", label: t.columns.grossProfit, kind: "money" },
      { key: "waived", label: t.columns.waived, kind: "money" },
      { key: "late_charge", label: t.columns.lateCharge, kind: "money" },
    ],
    totals: [
      { key: "revenue", label: t.totals.revenue, kind: "money" },
      { key: "cogs", label: t.totals.cogs, kind: "money" },
      { key: "gross_profit", label: t.totals.grossProfit, kind: "money" },
      { key: "recorded", label: t.totals.recorded, kind: "money" },
      { key: "charged", label: t.totals.charged, kind: "money" },
      { key: "waived", label: t.totals.waived, kind: "money" },
      { key: "late_charge", label: t.totals.lateCharge, kind: "money" },
      { key: "pending", label: t.totals.pending, kind: "money" },
      { key: "pending_stale", label: t.totals.pendingStale, kind: "money" },
      { key: "diff", label: t.totals.diff, kind: "money" },
      { key: "lavie_units", label: t.totals.lavieUnits, kind: "number" },
      { key: "lavie_revenue", label: t.totals.lavieRevenue, kind: "money" },
      { key: "dasani_units", label: t.totals.dasaniUnits, kind: "number" },
      { key: "room_nights", label: t.totals.roomNights, kind: "int" },
      {
        key: "lavie_per_roomnight",
        label: t.totals.laviePerRoomnight,
        kind: "number",
      },
      {
        key: "dasani_per_roomnight",
        label: t.totals.dasaniPerRoomnight,
        kind: "number",
      },
    ],
  },
  {
    code: "RPT_AMENITY_CPOR",
    slug: "amenity-cpor",
    title: t.titles.amenityCpor,
    description: t.descriptions.amenityCpor,
    permission: "report.view.rpt_amenity_cpor",
    paramKind: "month",
    columns: [
      { key: "group_name", label: t.columns.groupName, kind: "text" },
      { key: "qty", label: t.columns.qty, kind: "number" },
      { key: "cost", label: t.columns.cost, kind: "money" },
      {
        key: "cost_per_roomnight",
        label: t.columns.costPerRoomnight,
        kind: "money",
      },
    ],
    totals: [
      { key: "total_cost", label: t.totals.totalCost, kind: "money" },
      { key: "rooms_sold", label: t.totals.roomsSold, kind: "int" },
      {
        key: "cost_per_roomnight",
        label: t.totals.costPerRoomnight,
        kind: "money",
      },
    ],
  },
  {
    code: "RPT_FNB_REVENUE",
    slug: "fnb-revenue",
    title: t.titles.fnbRevenue,
    description: t.descriptions.fnbRevenue,
    permission: "report.view.rpt_fnb_revenue",
    paramKind: "range",
    columns: [
      { key: "dish_code", label: t.columns.dishCode, kind: "text" },
      { key: "dish_name", label: t.columns.dishName, kind: "text" },
      { key: "qty", label: t.columns.qty, kind: "number" },
      { key: "revenue", label: t.columns.revenue, kind: "money" },
      { key: "foodcost", label: t.columns.foodcost, kind: "money" },
      { key: "gross_profit", label: t.columns.grossProfit, kind: "money" },
      { key: "margin_pct", label: t.columns.marginPct, kind: "pct" },
    ],
    totals: [
      { key: "revenue", label: t.totals.revenue, kind: "money" },
      { key: "foodcost", label: t.totals.cogs, kind: "money" },
      { key: "gross_profit", label: t.totals.grossProfit, kind: "money" },
    ],
  },
  {
    code: "RPT_DAILY_BRIEF",
    slug: "daily-brief",
    title: t.titles.dailyBrief,
    description: t.descriptions.dailyBrief,
    permission: "report.view.rpt_daily_brief",
    paramKind: "date",
    columns: [],
    totals: [],
  },
];

export function getReportMeta(code: ReportCode): ReportMeta {
  const meta = REPORT_META.find((m) => m.code === code);
  if (!meta) throw new Error(`Unknown report code: ${code}`);
  return meta;
}

export function getReportMetaBySlug(slug: string): ReportMeta | null {
  return REPORT_META.find((m) => m.slug === slug) ?? null;
}
