import { readFileSync } from "node:fs";
import path from "node:path";
import PDFDocument from "pdfkit";
import { vi } from "@/i18n/vi";

/**
 * Sinh PDF don mua (C3, M03: `po_send` — MVP tai PDF va gui tay).
 * Du lieu lay tu RPC `export_po_data` (header + dong + lich su duyet),
 * khong them field moi. Font Noto Sans nhung san (ho tro tieng Viet co
 * dau) — xem ADR-009. Ham thuan: nhan du lieu, tra Buffer PDF.
 */

export interface PoPdfLine {
  item_code: string | null;
  item_name: string;
  qty: number;
  uom: string;
  unit_price: number;
  line_amount: number;
}

export interface PoPdfTimelineStep {
  step: number;
  approver_role_name: string | null;
  decision: string;
  decided_by_name: string | null;
  decided_at: string | null;
  comment: string | null;
}

export interface PoPdfData {
  po: {
    doc_no: string;
    supplier_code: string | null;
    supplier_name: string | null;
    supplier_tax_code: string | null;
    entity_code: string | null;
    entity_name: string | null;
    channel: string;
    kind: string;
    order_date: string;
    expected_date: string | null;
    status: string;
    total_amount: number;
    created_by_name: string | null;
    created_at: string;
  };
  lines: PoPdfLine[];
  timeline: PoPdfTimelineStep[];
}

/** Kiem tra hinh dang payload tra ve tu RPC `export_po_data`. */
export function isPoPdfData(value: unknown): value is PoPdfData {
  if (typeof value !== "object" || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    v.ok === true &&
    typeof v.po === "object" &&
    v.po !== null &&
    Array.isArray(v.lines) &&
    Array.isArray(v.timeline)
  );
}

const MARGIN = 48;
const PAGE_WIDTH = 595.28; // A4
const CONTENT_WIDTH = PAGE_WIDTH - MARGIN * 2;
/** Tim nhan ClickUp (#7B68EE) + nen xam nhat cho dong tieu de bang. */
const BRAND = "#7B68EE";
const HEADER_BG = "#F5F5F5";
const FONT_DIR = path.join(process.cwd(), "src/features/export/fonts");

let cachedFonts: { regular: Buffer; bold: Buffer } | null = null;

function loadFonts(): { regular: Buffer; bold: Buffer } {
  if (!cachedFonts) {
    cachedFonts = {
      regular: readFileSync(path.join(FONT_DIR, "NotoSans-Regular.ttf")),
      bold: readFileSync(path.join(FONT_DIR, "NotoSans-Bold.ttf")),
    };
  }
  return cachedFonts;
}

const moneyFmt = new Intl.NumberFormat("vi-VN", {
  maximumFractionDigits: 2,
});
const qtyFmt = new Intl.NumberFormat("vi-VN", { maximumFractionDigits: 4 });

function formatMoney(value: number): string {
  return moneyFmt.format(value);
}

function formatQty(value: number): string {
  return qtyFmt.format(value);
}

/** "2026-11-10" -> "10/11/2026". */
function formatDate(iso: string | null): string {
  if (!iso) return "";
  const [y, m, d] = iso.slice(0, 10).split("-");
  if (!y || !m || !d) return iso;
  return `${d}/${m}/${y}`;
}

/** Timestamptz ISO -> "dd/mm/yyyy HH:mm" gio Viet Nam. */
function formatDateTime(iso: string | null): string {
  if (!iso) return "";
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return iso;
  return date.toLocaleString("vi-VN", {
    timeZone: "Asia/Ho_Chi_Minh",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function poStatusLabel(status: string): string {
  const P = vi.procurement.po;
  switch (status) {
    case "draft":
      return P.statusDraft;
    case "submitted":
      return P.statusSubmitted;
    case "approved":
      return P.statusApproved;
    case "rejected":
      return P.statusRejected;
    case "sent":
      return P.statusSent;
    case "partially_received":
      return P.statusPartiallyReceived;
    case "received":
      return P.statusReceived;
    case "closed":
      return P.statusClosed;
    case "cancelled":
      return P.statusCancelled;
    default:
      return status;
  }
}

function channelLabel(channel: string): string {
  const P = vi.procurement.po;
  switch (channel) {
    case "contract":
      return P.channelContract;
    case "quote":
      return P.channelQuote;
    case "market":
      return P.channelMarket;
    default:
      return channel;
  }
}

function kindLabel(kind: string): string {
  if (kind === "service") return vi.procurement.pr.kindService;
  return vi.procurement.pr.kindStock;
}

function decisionLabel(decision: string): string {
  const T = vi.export.poPdf;
  switch (decision) {
    case "approved":
      return T.decisionApproved;
    case "rejected":
      return T.decisionRejected;
    default:
      return T.decisionPending;
  }
}

interface TableColumn {
  key: string;
  header: string;
  width: number;
  align: "left" | "right";
}

const LINE_COLUMNS: TableColumn[] = [
  { key: "no", header: "#", width: 22, align: "left" },
  { key: "item", header: vi.export.poPdf.item, width: 175, align: "left" },
  { key: "uom", header: vi.export.poPdf.uom, width: 40, align: "left" },
  { key: "qty", header: vi.export.poPdf.qty, width: 60, align: "right" },
  {
    key: "unitPrice",
    header: vi.export.poPdf.unitPrice,
    width: 92,
    align: "right",
  },
  {
    key: "amount",
    header: vi.export.poPdf.amount,
    width: 110,
    align: "right",
  },
];

export function buildPoPdf(data: PoPdfData): Promise<Buffer> {
  const fonts = loadFonts();
  const T = vi.export.poPdf;
  const P = vi.procurement.po;
  const doc = new PDFDocument({
    size: "A4",
    margin: MARGIN,
    info: { Title: `${T.title} ${data.po.doc_no}` },
  });
  doc.registerFont("NotoSans", fonts.regular);
  doc.registerFont("NotoSans-Bold", fonts.bold);

  const bottomLimit = doc.page.height - MARGIN;

  function ensureSpace(needed: number): void {
    if (doc.y + needed > bottomLimit) {
      doc.addPage();
    }
  }

  function sectionTitle(text: string): void {
    ensureSpace(28);
    doc.font("NotoSans-Bold").fontSize(12).text(text, MARGIN, doc.y, {
      width: CONTENT_WIDTH,
    });
    doc.moveDown(0.4);
  }

  // --- Tieu de + phap nhan (mau nhan #7B68EE, ten phap nhan dam) ---
  doc
    .font("NotoSans-Bold")
    .fontSize(18)
    .fillColor(BRAND)
    .text(T.title, MARGIN, doc.y, { align: "center", width: CONTENT_WIDTH });
  doc.moveDown(0.3);
  doc
    .font("NotoSans-Bold")
    .fontSize(10)
    .fillColor("#000000")
    .text(
      `${T.entity}: ${data.po.entity_name ?? ""} (${data.po.entity_code ?? ""})`,
      MARGIN,
      doc.y,
      { align: "center", width: CONTENT_WIDTH },
    );
  doc.moveDown(0.4);
  doc
    .moveTo(MARGIN, doc.y)
    .lineTo(MARGIN + CONTENT_WIDTH, doc.y)
    .strokeColor(BRAND)
    .lineWidth(2)
    .stroke()
    .strokeColor("#000000")
    .lineWidth(1);
  doc.moveDown(0.8);

  // --- Thong tin chung (2 cot nhan — gia tri) ---
  const meta: Array<[string, string]> = [
    [P.docNo, data.po.doc_no],
    [P.supplier, data.po.supplier_name ?? ""],
    [T.supplierTaxCode, data.po.supplier_tax_code ?? ""],
    [P.orderDate, formatDate(data.po.order_date)],
    [P.expectedDate, formatDate(data.po.expected_date)],
    [P.channel, channelLabel(data.po.channel)],
    [vi.procurement.pr.kind, kindLabel(data.po.kind)],
    [T.status, poStatusLabel(data.po.status)],
    [T.createdBy, data.po.created_by_name ?? ""],
    [T.createdAt, formatDateTime(data.po.created_at)],
  ];
  doc.fontSize(10);
  for (const [label, value] of meta) {
    doc.font("NotoSans-Bold");
    const labelH = doc.heightOfString(label, { width: 130 });
    doc.font("NotoSans");
    const valueH = doc.heightOfString(value, {
      width: CONTENT_WIDTH - 135,
    });
    const rowH = Math.max(labelH, valueH) + 3;
    ensureSpace(rowH);
    const rowY = doc.y;
    doc.font("NotoSans-Bold").text(label, MARGIN, rowY, { width: 130 });
    doc
      .font("NotoSans")
      .text(value, MARGIN + 135, rowY, { width: CONTENT_WIDTH - 135 });
    doc.y = rowY + rowH;
  }
  doc.moveDown(0.6);

  // --- Bang dong hang ---
  sectionTitle(T.linesTitle);
  const headerY = doc.y;
  doc.rect(MARGIN, headerY - 2, CONTENT_WIDTH, 16).fill(HEADER_BG);
  doc.fillColor("#000000");
  doc.font("NotoSans-Bold").fontSize(10);
  let x = MARGIN;
  for (const col of LINE_COLUMNS) {
    doc.text(col.header, x, headerY, {
      width: col.width,
      align: col.align,
    });
    x += col.width;
  }
  doc.y = headerY + 14;
  doc
    .moveTo(MARGIN, doc.y)
    .lineTo(MARGIN + CONTENT_WIDTH, doc.y)
    .stroke();

  doc.fontSize(10);
  data.lines.forEach((line, index) => {
    const itemText = line.item_code
      ? `${line.item_name} (${line.item_code})`
      : line.item_name;
    const cells: Array<{ text: string; col: TableColumn }> = [
      { text: String(index + 1), col: LINE_COLUMNS[0] },
      { text: itemText, col: LINE_COLUMNS[1] },
      { text: line.uom, col: LINE_COLUMNS[2] },
      { text: formatQty(line.qty), col: LINE_COLUMNS[3] },
      { text: formatMoney(line.unit_price), col: LINE_COLUMNS[4] },
      { text: formatMoney(line.line_amount), col: LINE_COLUMNS[5] },
    ];
    const rowHeight =
      Math.max(
        ...cells.map((c) => doc.heightOfString(c.text, { width: c.col.width })),
      ) + 6;
    ensureSpace(rowHeight + 4);
    const rowY = doc.y;
    let cx = MARGIN;
    for (const { text, col } of cells) {
      doc
        .font("NotoSans")
        .text(text, cx, rowY, { width: col.width, align: col.align });
      cx += col.width;
    }
    doc.y = rowY + rowHeight;
    doc
      .moveTo(MARGIN, doc.y)
      .lineTo(MARGIN + CONTENT_WIDTH, doc.y)
      .strokeColor("#cccccc")
      .stroke()
      .strokeColor("#000000");
  });

  // --- Tong tien ---
  ensureSpace(24);
  doc.moveDown(0.3);
  doc
    .font("NotoSans-Bold")
    .fontSize(11)
    .text(`${T.total}: ${formatMoney(data.po.total_amount)}`, MARGIN, doc.y, {
      align: "right",
      width: CONTENT_WIDTH,
    });
  doc.moveDown(0.8);

  // --- Lich su duyet ---
  if (data.timeline.length > 0) {
    sectionTitle(T.approvalsTitle);
    doc.font("NotoSans").fontSize(10);
    for (const step of data.timeline) {
      const head =
        `${T.step} ${step.step} — ${step.approver_role_name ?? ""}: ` +
        `${decisionLabel(step.decision)}` +
        (step.decided_by_name ? ` — ${step.decided_by_name}` : "") +
        (step.decided_at ? ` (${formatDateTime(step.decided_at)})` : "");
      const lines = [head];
      if (step.comment) lines.push(`${T.comment}: ${step.comment}`);
      const blockHeight =
        lines.reduce(
          (sum, l) => sum + doc.heightOfString(l, { width: CONTENT_WIDTH }),
          0,
        ) + 6;
      ensureSpace(blockHeight);
      for (const l of lines) {
        doc.text(l, MARGIN, doc.y, { width: CONTENT_WIDTH });
        doc.y += doc.heightOfString(l, { width: CONTENT_WIDTH }) + 2;
      }
      doc.moveDown(0.2);
    }
  }

  // --- Chan trang ---
  doc.moveDown(0.8);
  doc
    .font("NotoSans")
    .fontSize(9)
    .text(
      `${T.printedAt}: ${formatDateTime(new Date().toISOString())}`,
      MARGIN,
      doc.y,
      { width: CONTENT_WIDTH },
    );
  doc.text(T.note, MARGIN, doc.y, { width: CONTENT_WIDTH });

  return new Promise<Buffer>((resolve, reject) => {
    const chunks: Buffer[] = [];
    doc.on("data", (chunk: Buffer) => chunks.push(chunk));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);
    doc.end();
  });
}
