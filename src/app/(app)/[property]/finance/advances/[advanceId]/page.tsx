import { ErrorState } from "@/components/common/error-state";
import { AdvanceSettleForm } from "@/components/finance/advance-settle-form";
import { MoneyText } from "@/components/common/money-text";
import {
  getFinancePerms,
  listAdvanceSettlements,
} from "@/features/finance/queries";
import { getAdvance } from "@/features/procurement/queries";
import { vi } from "@/i18n/vi";

const SETTLEABLE = new Set(["disbursed", "settling", "overdue"]);

/** Chi tiết tạm ứng (T-041): thông tin + lịch sử quyết toán + form quyết toán. */
export default async function AdvanceDetailPage({
  params,
}: {
  params: Promise<{ property: string; advanceId: string }>;
}) {
  const { property: propertyId, advanceId } = await params;

  const [advanceRes, settlementsRes, perms] = await Promise.all([
    getAdvance(propertyId, advanceId),
    listAdvanceSettlements(propertyId, advanceId),
    getFinancePerms(propertyId),
  ]);

  if (!advanceRes.ok) {
    return <ErrorState description={advanceRes.error} />;
  }
  if (!settlementsRes.ok) {
    return <ErrorState description={settlementsRes.error} />;
  }

  const { advance, po } = advanceRes.data;
  const canSettle = perms.canSettleAdvance && SETTLEABLE.has(advance.status);

  return (
    <div className="space-y-6">
      <h1 className="text-xl font-semibold">
        {vi.finance.advancesTitle} · {advance.doc_no}
      </h1>
      <div className="rounded-xl border bg-card p-4 text-sm">
        <p>
          {vi.finance.employee}: {advance.employee_name ?? vi.common.noData}
        </p>
        <p>
          {vi.finance.purpose}: {advance.purpose}
        </p>
        <p>
          {vi.finance.totalAmount}: <MoneyText amount={advance.amount} />
        </p>
        <p>
          {vi.common.status}: {advance.status}
        </p>
        <p>
          {vi.finance.dueSettle}: {advance.due_settle_at ?? vi.common.noData}
        </p>
        {po ? (
          <p>
            {vi.finance.poDocNo}: {po.doc_no} ({po.status})
          </p>
        ) : null}
      </div>

      {canSettle ? (
        <AdvanceSettleForm propertyId={propertyId} advance={advance} />
      ) : advance.status === "settled" ? (
        <p className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">
          {vi.components.docStatus.settled}
        </p>
      ) : (
        <p className="rounded-xl border bg-card p-4 text-sm text-muted-foreground">
          {vi.finance.noPermissionSettle}
        </p>
      )}

      <div className="rounded-xl border bg-card p-4">
        <h2 className="font-medium">{vi.finance.settlementHistory}</h2>
        {settlementsRes.data.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.components.table.emptyDescription}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-3 py-2">{vi.finance.requestDocNo}</th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.spentTotal}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.refundAmount}
                  </th>
                  <th className="px-3 py-2 text-right">
                    {vi.finance.extraPayAmount}
                  </th>
                  <th className="px-3 py-2">{vi.finance.paidAt}</th>
                </tr>
              </thead>
              <tbody>
                {settlementsRes.data.map((s) => (
                  <tr key={s.id} className="border-b last:border-0">
                    <td className="px-3 py-2">{s.doc_no}</td>
                    <td className="px-3 py-2 text-right">
                      <MoneyText amount={s.amount} />
                    </td>
                    <td className="px-3 py-2 text-right">
                      <MoneyText amount={s.refund_amount} />
                    </td>
                    <td className="px-3 py-2 text-right">
                      <MoneyText amount={s.extra_pay_amount} />
                    </td>
                    <td className="px-3 py-2">{s.settled_at}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
