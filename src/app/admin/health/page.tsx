import { connection } from "next/server";
import { HealthRefreshButton } from "@/components/admin/health-refresh-button";
import { ErrorState } from "@/components/common/error-state";
import { PageHeader } from "@/components/shell/page-header";
import { callAdminRpc } from "@/features/admin/rpc";
import { vi } from "@/i18n/vi";
import { summarizeHealth, type HealthIssue } from "@/lib/admin/health-status";
import { createClient } from "@/lib/supabase/server";

type SystemHealth = {
  generated_at: string;
  cron: {
    jobname: string;
    schedule: string;
    active: boolean;
    last_status: string | null;
    last_run_at: string | null;
    failed_7d: number;
    runs_7d: number;
  }[];
  notifications: {
    queued: number;
    sending: number;
    sent: number;
    failed: number;
    skipped_quiet: number;
    stuck: number;
  };
  alerts: {
    red: number;
    warn: number;
    info: number;
    oldest_at: string | null;
  };
  database: {
    db_bytes: number;
    audit_log_bytes: number;
    audit_log_rows_estimate: number;
    stock_moves_rows_estimate: number;
  };
};

const dateTime = new Intl.DateTimeFormat("vi-VN", {
  timeZone: "Asia/Ho_Chi_Minh",
  dateStyle: "short",
  timeStyle: "medium",
});
const number = new Intl.NumberFormat("vi-VN");

function formatBytes(bytes: number): string {
  const mb = bytes / (1024 * 1024);
  return mb >= 1024
    ? `${number.format(Math.round((mb / 1024) * 10) / 10)} GB`
    : `${number.format(Math.round(mb * 10) / 10)} MB`;
}

function Stat({
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

const ISSUE_LABEL: Record<HealthIssue, (t: typeof vi.admin.health) => string> = {
  cron: (t) => t.cronFailed7d,
  notifications: (t) => t.notifStuck,
  alerts: (t) => t.alertsRed,
};

export default async function SystemHealthPage() {
  await connection();
  const supabase = await createClient();
  const result = await callAdminRpc<SystemHealth>(
    supabase,
    "admin_system_health",
    {},
  );
  const t = vi.admin.health;

  if (!result.ok) {
    return (
      <div className="space-y-6">
        <PageHeader title={t.title} />
        <ErrorState title={t.loadError} description={result.error} />
      </div>
    );
  }

  const h = result.data;
  const cronFailedTotal = h.cron.reduce((sum, job) => sum + job.failed_7d, 0);
  const summary = summarizeHealth({
    cronFailed7dTotal: cronFailedTotal,
    notificationsStuck: h.notifications.stuck,
    alertsRed: h.alerts.red,
  });
  const issueValues: Record<HealthIssue, number> = {
    cron: cronFailedTotal,
    notifications: h.notifications.stuck,
    alerts: h.alerts.red,
  };
  return (
    <div className="space-y-8">
      <PageHeader
        title={t.title}
        actions={<HealthRefreshButton label={t.refresh} />}
      />
      <div
        role="status"
        className={
          summary.ok
            ? "rounded-lg border border-emerald-200 bg-emerald-50 p-4 dark:border-emerald-900 dark:bg-emerald-950"
            : "rounded-lg border border-amber-200 bg-amber-50 p-4 dark:border-amber-900 dark:bg-amber-950"
        }
      >
        <p className="text-base font-semibold">
          {summary.ok ? t.statusOk : t.statusWarn}
        </p>
        <p className="mt-1 text-sm text-muted-foreground">
          {summary.ok ? t.statusOkDetail : t.statusWarnDetail}
        </p>
        {summary.issues.length > 0 ? (
          <ul className="mt-2 list-disc space-y-1 pl-5 text-sm">
            {summary.issues.map((issue) => (
              <li key={issue}>
                {ISSUE_LABEL[issue](t)}: {number.format(issueValues[issue])}
              </li>
            ))}
          </ul>
        ) : null}
      </div>
      <p className="text-sm text-muted-foreground">
        {t.description} {t.generatedAt}: {dateTime.format(new Date(h.generated_at))}
      </p>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">{t.cronTitle}</h2>
        {h.cron.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t.cronEmpty}</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full min-w-[560px] text-sm">
              <thead className="bg-muted/50 text-left">
                <tr>
                  <th className="p-2">{t.cronJob}</th>
                  <th className="p-2">{t.cronSchedule}</th>
                  <th className="p-2">{t.cronLastRun}</th>
                  <th className="p-2">{t.cronLastStatus}</th>
                  <th className="p-2 text-right">{t.cronFailed7d}</th>
                </tr>
              </thead>
              <tbody>
                {h.cron.map((job) => (
                  <tr key={job.jobname} className="border-t">
                    <td className="p-2 font-medium">
                      {job.jobname}
                      {job.active ? "" : ` (${t.cronInactive})`}
                    </td>
                    <td className="p-2 font-mono text-xs">{job.schedule}</td>
                    <td className="p-2">
                      {job.last_run_at
                        ? dateTime.format(new Date(job.last_run_at))
                        : t.cronNeverRun}
                    </td>
                    <td className="p-2">{job.last_status ?? "—"}</td>
                    <td
                      className={
                        job.failed_7d > 0
                          ? "p-2 text-right font-semibold text-destructive"
                          : "p-2 text-right"
                      }
                    >
                      {number.format(job.failed_7d)}/{number.format(job.runs_7d)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">{t.notifTitle}</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-6">
          <Stat label={t.notifQueued} value={number.format(h.notifications.queued)} />
          <Stat label={t.notifSending} value={number.format(h.notifications.sending)} />
          <Stat label={t.notifSent} value={number.format(h.notifications.sent)} />
          <Stat
            label={t.notifFailed}
            value={number.format(h.notifications.failed)}
            warn={h.notifications.failed > 0}
          />
          <Stat label={t.notifQuiet} value={number.format(h.notifications.skipped_quiet)} />
          <Stat
            label={t.notifStuck}
            value={number.format(h.notifications.stuck)}
            warn={h.notifications.stuck > 0}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">{t.alertsTitle}</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Stat
            label={t.alertsRed}
            value={number.format(h.alerts.red)}
            warn={h.alerts.red > 0}
          />
          <Stat label={t.alertsWarn} value={number.format(h.alerts.warn)} />
          <Stat label={t.alertsInfo} value={number.format(h.alerts.info)} />
          <Stat
            label={t.alertsOldest}
            value={
              h.alerts.oldest_at
                ? dateTime.format(new Date(h.alerts.oldest_at))
                : t.alertsNone
            }
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">{t.dbTitle}</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Stat label={t.dbSize} value={formatBytes(h.database.db_bytes)} />
          <Stat label={t.dbAuditSize} value={formatBytes(h.database.audit_log_bytes)} />
          <Stat
            label={t.dbAuditRows}
            value={number.format(h.database.audit_log_rows_estimate)}
          />
          <Stat
            label={t.dbMovesRows}
            value={number.format(h.database.stock_moves_rows_estimate)}
          />
        </div>
        <p className="text-sm text-muted-foreground">{t.dbLimitNote}</p>
      </section>
    </div>
  );
}
