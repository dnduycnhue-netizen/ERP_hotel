import { notFound } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { ReportFilters } from "@/components/report/report-filters";
import { ReportView } from "@/components/report/report-view";
import { DailyBriefView } from "@/components/report/daily-brief-view";
import { getReportMetaBySlug } from "@/features/report/definitions";
import {
  getPropertyEntity,
  getReport,
  getReportPerms,
  type ReportPayload,
} from "@/features/report/queries";
import { listSuppliers, listWarehouses } from "@/features/master/queries";
import { getRpcErrorMessage } from "@/i18n/errors.vi";
import { vi } from "@/i18n/vi";

/**
 * Màn hình 1 báo cáo (T-044): /[property]/reports/<slug>.
 * Bộ lọc qua query string; số liệu qua report_get (Postgres tính).
 */
export default async function ReportDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string; code: string }>;
  searchParams: Promise<Record<string, string | undefined>>;
}) {
  const { property, code } = await params;
  const query = await searchParams;
  const meta = getReportMetaBySlug(code);
  if (!meta) notFound();

  const perms = await getReportPerms(property);
  if (!perms[meta.code]) {
    return (
      <div className="space-y-4">
        <h2 className="text-xl font-semibold">{meta.title}</h2>
        <ErrorState title={vi.reports.noPermission} />
      </div>
    );
  }

  let payload: ReportPayload;
  try {
    payload = await getReport(property, meta.code, query);
  } catch (error) {
    const code = error instanceof Error ? error.message : null;
    return (
      <div className="space-y-4">
        <h2 className="text-xl font-semibold">{meta.title}</h2>
        <ErrorState title={getRpcErrorMessage(code)} />
      </div>
    );
  }
  const entityId = meta.exportKind ? await getPropertyEntity(property) : null;

  const warehouses =
    meta.code === "RPT_STOCK_CARD"
      ? (await listWarehouses(property)).map((w) => ({
          id: w.id,
          label: `${w.code} — ${w.name}`,
        }))
      : undefined;
  const suppliers =
    meta.code === "RPT_RECEIVING_QUALITY"
      ? (await listSuppliers({ propertyId: property })).map((s) => ({
          id: s.id,
          label: `${s.code} — ${s.name}`,
        }))
      : undefined;

  const initial: Record<string, string | undefined> = {};
  for (const key of [
    "from",
    "to",
    "month",
    "as_of",
    "date",
    "warehouse_id",
    "supplier_id",
  ]) {
    const v = ((payload.params ?? {}) as Record<string, unknown>)[key];
    initial[key] = typeof v === "string" ? v : undefined;
  }

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-xl font-semibold">{meta.title}</h2>
        <p className="text-sm text-muted-foreground">{meta.description}</p>
      </div>
      <ReportFilters
        paramKind={meta.paramKind}
        initial={initial}
        warehouses={warehouses}
        suppliers={suppliers}
      />
      {meta.code === "RPT_DAILY_BRIEF" ? (
        <DailyBriefView propertyId={property} payload={payload} />
      ) : (
        <ReportView meta={meta} payload={payload} entityId={entityId} />
      )}
    </div>
  );
}
