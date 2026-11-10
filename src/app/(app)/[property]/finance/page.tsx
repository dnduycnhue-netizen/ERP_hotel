import Link from "next/link";
import { ErrorState } from "@/components/common/error-state";
import { MoneyText } from "@/components/common/money-text";
import {
  getApAging,
  getFinancePerms,
  listInvoices,
  listPaymentRequests,
} from "@/features/finance/queries";
import { listAdvances } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/** Tổng quan tài chính (T-041): còn phải trả, quá hạn, hóa đơn chờ xử lý. */
export default async function FinanceOverviewPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [agingRes, invoicesRes, requestsRes, advancesRes, perms] =
    await Promise.all([
      getApAging(propertyId),
      listInvoices(propertyId),
      listPaymentRequests(propertyId, { status: "submitted" }),
      listAdvances(propertyId, { pageSize: 100 }),
      getFinancePerms(propertyId),
    ]);

  if (!agingRes.ok) {
    return <ErrorState description={agingRes.error} />;
  }
  if (!invoicesRes.ok) {
    return <ErrorState description={invoicesRes.error} />;
  }
  if (!requestsRes.ok) {
    return <ErrorState description={requestsRes.error} />;
  }
  if (!advancesRes.ok) {
    return <ErrorState description={advancesRes.error} />;
  }

  const balance = agingRes.data.reduce((s, r) => s + r.balance, 0);
  const overdue = agingRes.data.reduce(
    (s, r) =>
      s + r.overdue1to30 + r.overdue31to60 + r.overdue61to90 + r.overdueOver90,
    0,
  );
  const waitingInvoices = invoicesRes.data.filter(
    (i) => i.status === "draft" || i.status === "on_hold",
  ).length;
  const unsettledAdvances = advancesRes.data.rows.filter((a) =>
    ["requested", "approved", "disbursed", "settling", "overdue"].includes(
      a.status,
    ),
  ).length;

  return (
    <div className="space-y-4">
      <PageHeader title={vi.finance.overviewTitle} />
      <p className="text-sm text-muted-foreground">{vi.finance.overviewHint}</p>
      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Link
          href={`/${propertyId}/finance/payables`}
          className="rounded-lg border bg-card p-4 hover:bg-muted/50"
        >
          <p className="text-sm text-muted-foreground">
            {vi.finance.totalPayable}
          </p>
          <p className="mt-1 text-xl font-semibold">
            <MoneyText amount={balance} />
          </p>
        </Link>
        <Link
          href={`/${propertyId}/finance/payables`}
          className="rounded-lg border bg-card p-4 hover:bg-muted/50"
        >
          <p className="text-sm text-muted-foreground">
            {vi.finance.totalOverdue}
          </p>
          <p
            className={`mt-1 text-xl font-semibold ${overdue > 0 ? "text-red-800" : ""}`}
          >
            <MoneyText amount={overdue} />
          </p>
        </Link>
        <Link
          href={`/${propertyId}/finance/payment-requests?status=submitted`}
          className="rounded-lg border bg-card p-4 hover:bg-muted/50"
        >
          <p className="text-sm text-muted-foreground">
            {vi.finance.pendingPaymentRequests}
          </p>
          <p className="mt-1 text-xl font-semibold">
            {requestsRes.data.length}
          </p>
        </Link>
        <Link
          href={`/${propertyId}/finance/advances`}
          className="rounded-lg border bg-card p-4 hover:bg-muted/50"
        >
          <p className="text-sm text-muted-foreground">
            {vi.finance.unsettledAdvances}
          </p>
          <p className="mt-1 text-xl font-semibold">{unsettledAdvances}</p>
        </Link>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Link
          href={`/${propertyId}/finance/invoices`}
          className="rounded-lg border bg-card p-4 hover:bg-muted/50"
        >
          <p className="font-medium">{vi.finance.navInvoices}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {waitingInvoices} {vi.finance.invoicesTitle.toLowerCase()} ·{" "}
            {vi.components.docStatus.draft}/{vi.components.docStatus.onHold}
          </p>
        </Link>
        <Link
          href={`/${propertyId}/finance/no-invoice-listings`}
          className="rounded-lg border bg-card p-4 hover:bg-muted/50"
        >
          <p className="font-medium">{vi.finance.navNoInvoiceListings}</p>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.finance.listingApproveNote}
          </p>
        </Link>
      </div>
      {!perms.canManageInvoice &&
      !perms.canApproveInvoice &&
      !perms.canViewAp &&
      !perms.canRequestPayment &&
      !perms.canApprovePayment &&
      !perms.canMarkPaid &&
      !perms.canSettleAdvance ? (
        <ErrorState description={vi.finance.noPermissionInvoice} />
      ) : null}
    </div>
  );
}
