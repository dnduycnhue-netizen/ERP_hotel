import { connection } from "next/server";
import { ErrorState } from "@/components/common/error-state";
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
} from "@/features/export/queries";
import { PO_DOWNLOADABLE_STATUSES } from "@/features/export/hub";
import { listPos } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";
import { ExportHistoryTable, PoDownloadTable } from "./export-tables";

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
      <PageHeader
        title={vi.export.hub.title}
        description={vi.export.hub.hint}
      />

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
          <PoDownloadTable rows={pos} propertyId={propertyId} />
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
            <ExportHistoryTable rows={historyRes.data} />
          )}
        </section>
      )}
    </div>
  );
}
