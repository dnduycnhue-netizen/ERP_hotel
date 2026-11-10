"use client";

import { useState, useTransition } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { ackAlert } from "@/features/alerts/actions";
import type {
  AlertRow,
  AlertSeverity,
  DeliveryRow,
  DeliveryStatus,
} from "@/features/alerts/queries";

function severityLabel(severity: AlertSeverity): string {
  if (severity === "red") return vi.alerts.severityRed;
  if (severity === "warn") return vi.alerts.severityWarn;
  return vi.alerts.severityInfo;
}

function statusLabel(status: DeliveryStatus): string {
  if (status === "queued") return vi.alerts.statusQueued;
  if (status === "sending") return vi.alerts.statusSending;
  if (status === "sent") return vi.alerts.statusSent;
  if (status === "failed") return vi.alerts.statusFailed;
  return vi.alerts.statusSkippedQuiet;
}

function formatTime(value: string | null): string {
  if (!value) return "—";
  return new Date(value).toLocaleString("vi-VN", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function AckButton({
  propertyId,
  alertId,
}: {
  propertyId: string;
  alertId: string;
}) {
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  return (
    <span className="inline-flex flex-col items-start gap-1">
      <Button
        type="button"
        disabled={pending}
        onClick={() =>
          startTransition(async () => {
            setError(null);
            const result = await ackAlert(propertyId, alertId);
            if (!result.ok) setError(result.error);
          })
        }
      >
        {vi.alerts.ackButton}
      </Button>
      {error ? <span className="text-xs text-destructive">{error}</span> : null}
    </span>
  );
}

/**
 * Lich su canh bao + lich su gui (T-045). Chi hien thi (doc qua RLS);
 * nut "Da xu ly" goi RPC `alert_ack`.
 */
export function AlertsHistory({
  propertyId,
  alerts,
  deliveries,
}: {
  propertyId: string;
  alerts: AlertRow[];
  deliveries: DeliveryRow[];
}) {
  return (
    <div className="space-y-8">
      <section className="space-y-3">
        <h2 className="text-base font-semibold">{vi.alerts.alertsTitle}</h2>
        {alerts.length === 0 ? (
          <p className="text-sm text-muted-foreground">{vi.alerts.noAlerts}</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-left">
                  <th className="px-3 py-2">{vi.alerts.createdAt}</th>
                  <th className="px-3 py-2">{vi.alerts.code}</th>
                  <th className="px-3 py-2">{vi.alerts.severity}</th>
                  <th className="px-3 py-2">Tiêu đề</th>
                  <th className="px-3 py-2">{vi.alerts.sentAt}</th>
                  <th className="px-3 py-2">{vi.alerts.ackAt}</th>
                </tr>
              </thead>
              <tbody>
                {alerts.map((alert) => (
                  <tr key={alert.id} className="border-b last:border-0">
                    <td className="px-3 py-2 whitespace-nowrap">
                      {formatTime(alert.created_at)}
                    </td>
                    <td className="px-3 py-2 font-mono text-xs">
                      {alert.code}
                    </td>
                    <td className="px-3 py-2">
                      {severityLabel(alert.severity)}
                    </td>
                    <td className="px-3 py-2">{alert.title}</td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      {alert.sent_at
                        ? formatTime(alert.sent_at)
                        : vi.alerts.notSent}
                    </td>
                    <td className="px-3 py-2 whitespace-nowrap">
                      {alert.ack_at ? (
                        vi.alerts.acked
                      ) : (
                        <AckButton propertyId={propertyId} alertId={alert.id} />
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">{vi.alerts.deliveriesTitle}</h2>
        {deliveries.length === 0 ? (
          <p className="text-sm text-muted-foreground">
            {vi.alerts.noDeliveries}
          </p>
        ) : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-left">
                  <th className="px-3 py-2">{vi.alerts.createdAt}</th>
                  <th className="px-3 py-2">{vi.alerts.channel}</th>
                  <th className="px-3 py-2">{vi.alerts.recipient}</th>
                  <th className="px-3 py-2">Tiêu đề</th>
                  <th className="px-3 py-2">{vi.alerts.status}</th>
                  <th className="px-3 py-2">{vi.alerts.attempts}</th>
                  <th className="px-3 py-2">{vi.alerts.errorMessage}</th>
                </tr>
              </thead>
              <tbody>
                {deliveries.map((delivery) => (
                  <tr key={delivery.id} className="border-b last:border-0">
                    <td className="px-3 py-2 whitespace-nowrap">
                      {formatTime(delivery.created_at)}
                    </td>
                    <td className="px-3 py-2">
                      {delivery.kind === "digest"
                        ? `${delivery.channel} (${vi.alerts.digest})`
                        : delivery.channel}
                    </td>
                    <td className="px-3 py-2 break-all">
                      {delivery.recipient_address}
                    </td>
                    <td className="px-3 py-2">{delivery.title}</td>
                    <td className="px-3 py-2">
                      {statusLabel(delivery.status)}
                    </td>
                    <td className="px-3 py-2">{delivery.attempts}</td>
                    <td className="px-3 py-2 break-all">
                      {delivery.error_message ?? "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
