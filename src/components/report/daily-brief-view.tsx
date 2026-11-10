import Link from "next/link";
import { formatMoney, formatNumber } from "@/components/common/money-text";
import { vi } from "@/i18n/vi";
import type { ReportPayload } from "@/features/report/queries";

type RedAlert = {
  id: string;
  code: string;
  title: string;
  doc_type: string | null;
  doc_id: string | null;
  created_at: string;
  acked: boolean;
};

type ContractExpiring = {
  contract_id: string;
  title: string;
  supplier_name: string;
  end_date: string;
  days_left: number;
};

type ScheduleUnaccepted = {
  schedule_id: string;
  contract_title: string;
  period_start: string;
  period_end: string;
  due_date: string | null;
  status: string;
};

/** Đường dẫn chi tiết chứng từ theo doc_type của alerts (đã kiểm chứng route). */
function docHref(
  propertyId: string,
  docType: string | null,
  docId: string | null,
): string | null {
  if (!docType || !docId) return null;
  switch (docType) {
    case "po":
      return `/${propertyId}/procurement/po/${docId}`;
    case "pr":
      return `/${propertyId}/procurement/pr/${docId}`;
    case "waste":
      return `/${propertyId}/inventory/waste/${docId}`;
    case "advance":
      return `/${propertyId}/finance/advances/${docId}`;
    case "requisition":
      return `/${propertyId}/inventory/requisitions/${docId}`;
    default:
      return null;
  }
}

function formatDate(value: string | null): string {
  if (!value) return vi.common.noData;
  const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(value);
  return m ? `${m[3]}/${m[2]}/${m[1]}` : value;
}

/**
 * Bản tin 8h (T-044): 5 con số + cảnh báo đỏ 24h + hợp đồng sắp hết hạn
 * + kỳ dịch vụ chưa nghiệm thu. Ảnh của cảnh báo nằm ở chứng từ được link
 * (payload alerts không mang tham chiếu ảnh — xem Q89).
 */
export function DailyBriefView({
  propertyId,
  payload,
}: {
  propertyId: string;
  payload: ReportPayload;
}) {
  const b = vi.reports.brief;
  const advances = (payload.advances_overdue ?? {}) as {
    count?: number;
    amount?: number | string;
  };
  const redAlerts = (payload.red_alerts_24h ?? []) as RedAlert[];
  const contracts = (payload.contracts_expiring ?? []) as ContractExpiring[];
  const schedules = (payload.schedules_unaccepted ??
    []) as ScheduleUnaccepted[];
  const notes = payload.notes ?? [];

  const stats: Array<{ label: string; value: string }> = [
    {
      label: b.purchaseYesterday,
      value: formatMoney(payload.purchase_yesterday as number | string),
    },
    {
      label: b.wasteYesterday,
      value: formatMoney(payload.waste_yesterday as number | string),
    },
    {
      label: b.redAlertsUnacked,
      value: formatNumber(payload.red_alerts_unacked as number | string),
    },
    {
      label: b.apDue7d,
      value: formatMoney(payload.ap_due_7d as number | string),
    },
    {
      label: b.advancesOverdue,
      value: `${formatNumber(advances.count ?? 0)} ${b.advancesOverdueCount} · ${formatMoney(advances.amount)}`,
    },
  ];

  return (
    <div className="space-y-6">
      <dl className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        {stats.map((s) => (
          <div key={s.label} className="rounded-lg border p-3">
            <dt className="text-xs text-muted-foreground">{s.label}</dt>
            <dd className="mt-1 text-lg font-semibold">{s.value}</dd>
          </div>
        ))}
      </dl>

      <section>
        <h2 className="mb-2 text-base font-semibold">
          {vi.reports.redAlertsTitle}
        </h2>
        {redAlerts.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.reports.noRedAlerts}
          </p>
        ) : (
          <ul className="space-y-2">
            {redAlerts.map((a) => {
              const href = docHref(propertyId, a.doc_type, a.doc_id);
              return (
                <li
                  key={a.id}
                  className="flex flex-wrap items-center gap-2 rounded-lg border p-3 text-sm"
                >
                  <span className="font-medium">{a.title}</span>
                  <span className="text-muted-foreground">({a.code})</span>
                  <span className="text-muted-foreground">
                    {formatDate(a.created_at)}
                  </span>
                  {a.acked && (
                    <span className="text-muted-foreground">· {b.acked}</span>
                  )}
                  {href ? (
                    <Link
                      href={href}
                      className="ml-auto text-primary underline"
                    >
                      {vi.reports.viewDocument}
                    </Link>
                  ) : (
                    <span className="ml-auto text-muted-foreground">
                      {a.doc_type ?? ""} {a.doc_id ?? ""}
                    </span>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      <section>
        <h2 className="mb-2 text-base font-semibold">
          {vi.reports.contractsExpiringTitle}
        </h2>
        {contracts.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.reports.noContractsExpiring}
          </p>
        ) : (
          <ul className="space-y-2">
            {contracts.map((c) => (
              <li
                key={c.contract_id}
                className="flex flex-wrap items-center gap-2 rounded-lg border p-3 text-sm"
              >
                <Link
                  href={`/${propertyId}/procurement/service-contracts/${c.contract_id}`}
                  className="font-medium text-primary underline"
                >
                  {c.title}
                </Link>
                <span className="text-muted-foreground">{c.supplier_name}</span>
                <span className="ml-auto text-muted-foreground">
                  {b.contractEndDate}: {formatDate(c.end_date)} ·{" "}
                  {c.days_left >= 0
                    ? vi.reports.daysLeft.replace("{days}", String(c.days_left))
                    : vi.reports.overdue}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

      <section>
        <h2 className="mb-2 text-base font-semibold">
          {vi.reports.schedulesUnacceptedTitle}
        </h2>
        {schedules.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.reports.noSchedulesUnaccepted}
          </p>
        ) : (
          <ul className="space-y-2">
            {schedules.map((s) => (
              <li
                key={s.schedule_id}
                className="flex flex-wrap items-center gap-2 rounded-lg border p-3 text-sm"
              >
                <span className="font-medium">{s.contract_title}</span>
                <span className="text-muted-foreground">
                  {b.schedulePeriod}: {formatDate(s.period_start)} –{" "}
                  {formatDate(s.period_end)}
                </span>
                <span className="ml-auto text-muted-foreground">
                  {b.scheduleDueDate}: {formatDate(s.due_date)} · {s.status}
                </span>
              </li>
            ))}
          </ul>
        )}
      </section>

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
