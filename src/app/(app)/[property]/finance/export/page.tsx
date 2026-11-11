import Link from "next/link";
import { connection } from "next/server";
import { DataTable } from "@/components/common/data-table";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import { ErrorState } from "@/components/common/error-state";
import { MoneyText } from "@/components/common/money-text";
import {
  AccountingExportForm,
  BankTransferExportPanel,
} from "@/components/finance/export-hub";
import { PageHeader } from "@/components/shell/page-header";
import { listPaymentRequests } from "@/features/finance/queries";
import {
  getExportPerms,
  getPropertyLegalEntity,
  listBankTransferExportedAt,
  listExportHistory,
  type ExportBatchKind,
  type ExportBatchRow,
} from "@/features/export/queries";
import {
  PO_DOWNLOADABLE_STATUSES,
  buildPoPdfUrl,
  formatDateTimeVn,
  formatDateVn,
} from "@/features/export/hub";
import { listPos, type PoRow } from "@/features/procurement/queries";
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

/** Màn hub xuất file tài chính (C4): Excel kế toán T-043, PDF PO (C3), file chuyển khoản (C3), lịch sử xuất (C3). */
export default async function FinanceExportPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  // Chặn prerender (Q202): trang đọc session Supabase — không có dòng
  // này, Next 16 thử prerender và nổ lỗi `Date.now()` khi nạp session.
  await connection();
  const { property: propertyId } = await params;

  const [perms, entity, poResults, requestsRes, historyRes, exportedMapRes] =
    await Promise.all([
      getExportPerms(propertyId),
      getPropertyLegalEntity(propertyId),
      Promise.all(
        PO_DOWNLOADABLE_STATUSES.map((status) =>
          listPos(propertyId, { status, pageSize: 50 }),
        ),
      ),
      listPaymentRequests(propertyId, { status: "approved" }),
      listExportHistory(propertyId),
      listBankTransferExportedAt(propertyId),
    ]);

  if (
    !perms.canExportAccounting &&
    !perms.canExportPo &&
    !perms.canExportBankTransfer
  ) {
    return (
      <div className="space-y-4">
        <PageHeader title={vi.export.hub.title} />
        <ErrorState description={vi.export.hub.noPermission} />
      </div>
    );
  }
  if (!requestsRes.ok) {
    return <ErrorState description={requestsRes.error} />;
  }
  const failedPos = poResults.find((r) => !r.ok);
  if (failedPos && !failedPos.ok) {
    return <ErrorState description={failedPos.error} />;
  }

  const pos = poResults
    .flatMap((r) => (r.ok ? r.data.rows : []))
    .sort((a, b) => (a.created_at < b.created_at ? 1 : -1));

  return (
    <div className="space-y-6">
      <PageHeader title={vi.export.hub.title} />
      <p className="text-sm text-muted-foreground">{vi.export.hub.hint}</p>

      {perms.canExportAccounting && (
        <section
          aria-label={vi.export.hub.accountingTitle}
          className="rounded-lg border bg-card p-4"
        >
          <h2 className="mb-1 text-base font-semibold">
            {vi.export.hub.accountingTitle}
          </h2>
          <p className="mb-3 text-sm text-muted-foreground">
            {vi.export.hub.accountingHint}
          </p>
          {entity ? (
            <AccountingExportForm entity={entity} />
          ) : (
            <p className="text-sm text-muted-foreground">
              {vi.export.hub.noEntity}
            </p>
          )}
        </section>
      )}

      {perms.canExportBankTransfer && (
        <section
          aria-label={vi.export.hub.bankTransferTitle}
          className="rounded-lg border bg-card p-4"
        >
          <h2 className="mb-1 text-base font-semibold">
            {vi.export.hub.bankTransferTitle}
          </h2>
          <p className="mb-3 text-sm text-muted-foreground">
            {vi.export.hub.bankTransferHint}
          </p>
          <BankTransferExportPanel
            requests={requestsRes.data}
            previouslyExported={exportedMapRes.ok ? exportedMapRes.data : {}}
            historyAvailable={exportedMapRes.ok}
          />
        </section>
      )}

      {perms.canExportPo && (
        <section
          aria-label={vi.export.hub.poPdfTitle}
          className="rounded-lg border bg-card p-4"
        >
          <h2 className="mb-1 text-base font-semibold">
            {vi.export.hub.poPdfTitle}
          </h2>
          <p className="mb-3 text-sm text-muted-foreground">
            {vi.export.hub.poPdfHint}
          </p>
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
            rows={pos}
            emptyTitle={vi.export.hub.noDownloadablePos}
          />
        </section>
      )}

      {perms.canViewHistory && (
        <section
          aria-label={vi.export.hub.historyTitle}
          className="rounded-lg border bg-card p-4"
        >
          <h2 className="mb-1 text-base font-semibold">
            {vi.export.hub.historyTitle}
          </h2>
          {!historyRes.ok ? (
            <p className="text-sm text-muted-foreground">{historyRes.error}</p>
          ) : (
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
              rows={historyRes.data}
              emptyTitle={vi.export.hub.historyEmpty}
            />
          )}
        </section>
      )}
    </div>
  );
}
