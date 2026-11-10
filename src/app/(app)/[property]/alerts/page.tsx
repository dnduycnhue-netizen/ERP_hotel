import { ErrorState } from "@/components/common/error-state";
import { AlertsHistory } from "@/components/alerts/alerts-history";
import {
  canViewAlerts,
  listAlerts,
  listDeliveries,
} from "@/features/alerts/queries";
import { vi } from "@/i18n/vi";

/** Lich su canh bao + lich su gui thong bao (T-045, man toi thieu). */
export default async function AlertsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [canView, alertsRes, deliveriesRes] = await Promise.all([
    canViewAlerts(propertyId),
    listAlerts(propertyId),
    listDeliveries(propertyId),
  ]);

  if (!alertsRes.ok) {
    return <ErrorState description={alertsRes.error} />;
  }
  if (!deliveriesRes.ok) {
    return <ErrorState description={deliveriesRes.error} />;
  }

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">{vi.alerts.indexTitle}</h1>
      <p className="text-sm text-muted-foreground">{vi.alerts.indexHint}</p>
      {!canView ? (
        <p className="text-sm text-muted-foreground">
          {vi.alerts.noPermission}
        </p>
      ) : (
        <AlertsHistory
          propertyId={propertyId}
          alerts={alertsRes.data}
          deliveries={deliveriesRes.data}
        />
      )}
    </div>
  );
}
