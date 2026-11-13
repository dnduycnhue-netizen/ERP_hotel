import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { formatMoney } from "@/components/common/money-text";
import { getReport } from "@/features/report/queries";
import { vi } from "@/i18n/vi";
import { briefNeedsAttention, parseDailyBrief } from "@/lib/report/daily-brief";

const dateTime = new Intl.DateTimeFormat("vi-VN", {
  timeZone: "Asia/Ho_Chi_Minh",
  dateStyle: "short",
  timeStyle: "short",
});

function Figure({
  label,
  value,
  warn = false,
}: {
  label: string;
  value: string;
  warn?: boolean;
}) {
  return (
    <div className="rounded-lg border bg-card p-4">
      <p className="text-sm text-muted-foreground">{label}</p>
      <p
        className={
          warn
            ? "mt-1 text-xl font-semibold text-destructive sm:text-2xl"
            : "mt-1 text-xl font-semibold sm:text-2xl"
        }
      >
        {value}
      </p>
    </div>
  );
}

/**
 * Khối "Sáng nay" ở trang tổng quan (Q255): 5 con số của bản tin 8h
 * (RPT_DAILY_BRIEF) + cảnh báo đỏ 24 giờ. Chỉ hiện khi có quyền xem bản
 * tin; dữ liệu do RPC `report_get` tính sẵn.
 */
export async function MorningBrief({ propertyId }: { propertyId: string }) {
  const t = vi.property.brief;
  let brief;
  try {
    const payload = await getReport(propertyId, "RPT_DAILY_BRIEF", {});
    brief = parseDailyBrief(payload);
  } catch {
    return <ErrorState title={t.loadError} />;
  }
  const attention = briefNeedsAttention(brief);

  return (
    <section className="space-y-4" aria-labelledby="morning-brief-title">
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h2 id="morning-brief-title" className="text-base font-semibold">
          {t.title}
        </h2>
        <Link
          href={`/${propertyId}/reports/daily-brief`}
          className="text-sm text-primary hover:underline"
        >
          {t.viewFull}
        </Link>
      </div>
      <div
        role="status"
        className={
          attention
            ? "rounded-lg border border-amber-200 bg-amber-50 p-3 text-sm dark:border-amber-900 dark:bg-amber-950"
            : "rounded-lg border border-emerald-200 bg-emerald-50 p-3 text-sm dark:border-emerald-900 dark:bg-emerald-950"
        }
      >
        {attention ? t.attention : t.allClear}
      </div>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        <Figure label={t.purchaseYesterday} value={formatMoney(brief.purchaseYesterday)} />
        <Figure label={t.wasteYesterday} value={formatMoney(brief.wasteYesterday)} />
        <Figure
          label={t.redAlerts}
          value={String(brief.redAlertsUnacked)}
          warn={brief.redAlertsUnacked > 0}
        />
        <Figure label={t.apDue7d} value={formatMoney(brief.apDue7d)} />
        <Figure
          label={t.advancesOverdue}
          value={
            brief.advancesOverdueCount > 0
              ? `${brief.advancesOverdueCount} (${formatMoney(brief.advancesOverdueAmount)})`
              : "0"
          }
          warn={brief.advancesOverdueCount > 0}
        />
      </div>
      {brief.redAlerts24h.length > 0 ? (
        <div className="rounded-lg border">
          <p className="border-b bg-muted/50 p-2 text-sm font-medium">
            {t.redAlerts24h}
          </p>
          <ul className="divide-y text-sm">
            {brief.redAlerts24h.slice(0, 5).map((alert) => (
              <li key={alert.id} className="flex flex-wrap justify-between gap-2 p-2">
                <span>{alert.title}</span>
                {alert.createdAt ? (
                  <span className="text-muted-foreground">
                    {dateTime.format(new Date(alert.createdAt))}
                  </span>
                ) : null}
              </li>
            ))}
          </ul>
          <p className="p-2 text-right text-sm">
            <Link href={`/${propertyId}/alerts`} className="text-primary hover:underline">
              {t.allAlerts}
            </Link>
          </p>
        </div>
      ) : null}
      {brief.contractsExpiring + brief.schedulesUnaccepted > 0 ? (
        <p className="text-sm text-muted-foreground">
          {t.contractsNote
            .replace("{expiring}", String(brief.contractsExpiring))
            .replace("{unaccepted}", String(brief.schedulesUnaccepted))}
        </p>
      ) : null}
    </section>
  );
}
