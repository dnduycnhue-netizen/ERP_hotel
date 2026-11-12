import { connection } from "next/server";
import { ErrorState } from "@/components/common/error-state";
import { PageHeader } from "@/components/shell/page-header";
import { callAdminRpc } from "@/features/admin/rpc";
import { vi } from "@/i18n/vi";
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
            ? "mt-1 text-2xl font-semibold text-destructive"
            : "mt-1 text-2xl font-semibold"
        }
      >
        {value}
      </p>
    </div>
  );
}

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
  return (
    <div className="space-y-8">
      <PageHeader title={t.title} />
      <p className="text-sm text-muted-foreground">
        {t.description} {t.generatedAt}: {dateTime.format(new Date(h.generated_at))}
      </p>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">{t.cronTitle}</h2>
        {h.cron.length === 0 ? (
          <p className="text-sm text-muted-foreground">{t.cronEmpty}</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
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
      </section>
    </div>
  );
}
