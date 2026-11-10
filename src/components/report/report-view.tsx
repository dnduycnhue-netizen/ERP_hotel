import Link from "next/link";
import {
  DataTable,
  type DataTableColumn,
} from "@/components/common/data-table";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import { vi } from "@/i18n/vi";
import type {
  ReportColumn,
  ReportColumnKind,
  ReportMeta,
} from "@/features/report/definitions";
import type { ReportPayload, ReportRow } from "@/features/report/queries";

function formatCell(value: unknown, kind: ReportColumnKind): string {
  if (value === null || value === undefined || value === "") {
    return vi.common.noData;
  }
  switch (kind) {
    case "money":
      return formatMoney(value as number | string);
    case "number":
    case "int":
      return formatNumber(value as number | string);
    case "pct":
      return `${formatNumber(value as number | string)} %`;
    case "date": {
      const s = String(value);
      const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
      return m ? `${m[3]}/${m[2]}/${m[1]}` : s;
    }
    default:
      return typeof value === "object" ? JSON.stringify(value) : String(value);
  }
}

function buildColumns(
  columns: ReportColumn[],
): DataTableColumn<ReportRow & { id: number }>[] {
  return columns.map((c) => ({
    key: c.key,
    header: c.label,
    align:
      c.kind === "money" ||
      c.kind === "number" ||
      c.kind === "int" ||
      c.kind === "pct"
        ? "right"
        : "left",
    cell: (row) => formatCell(row[c.key], c.kind),
  }));
}

/**
 * Màn hình báo cáo dạng bảng chung (T-044): tổng cộng + bảng + ghi chú
 * nguồn số liệu + (nếu có) bảng phụ + nút xuất Excel T-043.
 * Không tính lại tiền/số lượng bằng JS — chỉ hiển thị số Postgres trả về.
 */
export function ReportView({
  meta,
  payload,
  entityId,
}: {
  meta: ReportMeta;
  payload: ReportPayload;
  entityId: string | null;
}) {
  const rows = (payload.rows ?? []) as ReportRow[];
  const totals = (payload.totals ?? {}) as Record<string, unknown>;
  const notes = payload.notes ?? [];
  const params = payload.params as Record<string, unknown>;

  const from = String(params.from ?? "");
  const to = String(params.to ?? "");
  const asOf = String(params.as_of ?? "");
  const exportFrom = from || (asOf ? `${asOf.slice(0, 7)}-01` : "");
  const exportTo = to || asOf;
  const exportHref =
    meta.exportKind && entityId && exportFrom && exportTo
      ? `/api/export/${meta.exportKind}?entity=${entityId}&from=${exportFrom}&to=${exportTo}`
      : null;

  const onHold = (
    (payload.extra as Record<string, unknown> | undefined)?.on_hold_invoices as
      ReportRow[] | undefined
  )?.map((r, i) => ({ ...r, id: i }));

  return (
    <div className="space-y-4">
      {meta.totals.length > 0 && (
        <section aria-label={vi.reports.totalsTitle}>
          <h2 className="mb-2 text-sm font-medium text-muted-foreground">
            {vi.reports.totalsTitle}
          </h2>
          <dl className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
            {meta.totals.map((t) => (
              <div key={t.key} className="rounded-lg border p-3">
                <dt className="text-xs text-muted-foreground">{t.label}</dt>
                <dd className="mt-1 text-lg font-semibold">
                  {formatCell(totals[t.key], t.kind)}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      )}

      <DataTable<ReportRow & { id: number }>
        columns={buildColumns(meta.columns)}
        rows={rows.map((r, i) => ({ ...r, id: i }))}
        emptyTitle={vi.common.noData}
        emptyDescription={meta.description}
      />

      {onHold && onHold.length > 0 && (
        <section>
          <h2 className="mb-2 text-base font-semibold">
            {vi.reports.onHoldTitle}
          </h2>
          <DataTable<ReportRow & { id: number }>
            columns={[
              { key: "invoice_no", header: vi.reports.columns.invoiceNo },
              { key: "supplier_name", header: vi.reports.columns.supplier },
              {
                key: "invoice_date",
                header: vi.reports.columns.invoiceDate,
                cell: (row) => formatCell(row.invoice_date, "date"),
              },
              {
                key: "total",
                header: vi.reports.columns.total,
                align: "right",
                cell: (row) => formatCell(row.total, "money"),
              },
              {
                key: "match_result",
                header: vi.reports.columns.matchResult,
                cell: (row) =>
                  typeof row.match_result === "object"
                    ? JSON.stringify(row.match_result)
                    : formatCell(row.match_result, "text"),
              },
            ]}
            rows={onHold}
            emptyTitle={vi.common.noData}
          />
        </section>
      )}

      {exportHref && (
        <div className="flex items-center gap-2">
          <Link
            href={exportHref}
            className="inline-flex h-8 items-center justify-center rounded-lg border border-border bg-background px-2.5 text-sm font-medium hover:bg-muted"
          >
            {vi.reports.exportExcel}
          </Link>
          <p className="text-xs text-muted-foreground">
            {vi.reports.exportHint}
          </p>
        </div>
      )}

      {notes.length > 0 && (
        <section aria-label={vi.reports.notesTitle}>
          <h2 className="mb-1 text-sm font-medium text-muted-foreground">
            {vi.reports.notesTitle}
          </h2>
          <ul className="list-disc space-y-1 pl-5 text-sm text-muted-foreground">
            {notes.map((n, i) => (
              <li key={i}>{n}</li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}
