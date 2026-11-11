"use client";

import Link from "next/link";
import { DataTable } from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { MoneyText } from "@/components/common/money-text";
import {
  buildPoPdfUrl,
  formatDateTimeVn,
  formatDateVn,
} from "@/features/export/hub";
import type {
  ExportBatchKind,
  ExportBatchRow,
} from "@/features/export/queries";
import type { PoRow } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";

const KIND_LABEL_KEYS: Record<
  ExportBatchKind,
  keyof typeof vi.export.hub.kindLabels
> = {
  "po-pdf": "poPdf",
  "bank-transfer": "bankTransfer",
  "goods-receipts": "goodsReceipts",
  "stock-issues": "stockIssues",
  invoices: "invoices",
  payables: "payables",
  advances: "advances",
};

function kindLabel(kind: ExportBatchKind): string {
  return vi.export.hub.kindLabels[KIND_LABEL_KEYS[kind]];
}

/**
 * Bảng PO tải được + bảng lịch sử xuất (Q203): cột `cell` là hàm nên
 * phải định nghĩa ở phía client — trang server chỉ được truyền dữ liệu
 * thuần (rows) sang. Truyền hàm từ Server Component sang Client
 * Component làm React nổ lỗi serialize ("Functions cannot be passed
 * directly to Client Components") và trang /finance/export sập hoàn
 * toàn (hiện qua error boundary của (app) nên chỉ thấy ErrorState
 * chung chung, không thấy digest).
 */
export function PoDownloadTable({
  rows,
  propertyId,
}: {
  rows: PoRow[];
  propertyId: string;
}) {
  return (
    <DataTable<PoRow>
      columns={[
        {
          key: "doc_no",
          header: vi.export.columns.docNo,
          cell: (row) => (
            <Link
              href={`/${propertyId}/procurement/po/${row.id}`}
              className="font-medium hover:underline"
            >
              {row.doc_no}
            </Link>
          ),
        },
        {
          key: "supplier_name",
          header: vi.finance.supplier,
          cell: (row) => row.supplier_name ?? "—",
        },
        {
          key: "order_date",
          header: vi.procurement.po.orderDate,
          cell: (row) => formatDateVn(row.order_date) ?? "—",
        },
        {
          key: "total_amount",
          header: vi.export.columns.amount,
          align: "right",
          cell: (row) => <MoneyText amount={row.total_amount} />,
        },
        {
          key: "status",
          header: vi.common.status,
          cell: (row) => <DocStatusBadge status={row.status} />,
        },
        {
          key: "download",
          header: "",
          cell: (row) => (
            <a
              href={buildPoPdfUrl(row.id)}
              className="inline-flex h-8 items-center justify-center rounded-lg border border-border bg-background px-2.5 text-sm font-medium hover:bg-muted"
            >
              {vi.export.hub.poDownload}
            </a>
          ),
        },
      ]}
      rows={rows}
      emptyTitle={vi.export.hub.noDownloadablePos}
    />
  );
}

export function ExportHistoryTable({ rows }: { rows: ExportBatchRow[] }) {
  return (
    <DataTable<ExportBatchRow>
      columns={[
        {
          key: "kind",
          header: vi.export.hub.kindLabelColumn,
          cell: (row) => kindLabel(row.kind),
        },
        {
          key: "ref",
          header: vi.export.hub.refColumn,
          cell: (row) => row.ref_doc_no ?? `${row.ref_id.slice(0, 8)}…`,
        },
        {
          key: "exported_at",
          header: vi.export.hub.exportedAtColumn,
          cell: (row) => formatDateTimeVn(row.exported_at) ?? "—",
        },
        {
          key: "exported_by",
          header: vi.export.hub.exportedByColumn,
          cell: (row) => `${row.exported_by.slice(0, 8)}…`,
        },
        {
          key: "file_hash",
          header: vi.export.hub.fileHashColumn,
          cell: (row) =>
            row.file_hash ? `${row.file_hash.slice(0, 8)}…` : "—",
        },
      ]}
      rows={rows}
      emptyTitle={vi.export.hub.historyEmpty}
    />
  );
}
