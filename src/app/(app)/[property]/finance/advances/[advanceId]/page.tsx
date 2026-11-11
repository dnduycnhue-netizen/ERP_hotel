import { ErrorState } from "@/components/common/error-state";
import { AdvanceSettleForm } from "@/components/finance/advance-settle-form";
import { AttachmentGallery } from "@/components/common/attachment-gallery";
import { MoneyText } from "@/components/common/money-text";
import { DocStatusBadge } from "@/components/common/doc-status-badge";
import {
  getFinancePerms,
  listAdvanceSettlementLines,
  listAdvanceSettlements,
} from "@/features/finance/queries";
import { getAdvance } from "@/features/procurement/queries";
import { listReceipts } from "@/features/receiving/queries";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

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

  // Phiếu nhận đã chốt + dòng quyết toán: dữ liệu phụ cho form gắn GR
  // (C12/Q74). Tải lỗi thì coi như trống — form vẫn quyết toán được
  // bằng tiền (gắn chứng từ là tùy chọn), không chặn cả trang.
  const [receiptsRes, linesRes] = await Promise.all([
    listReceipts(propertyId, { status: "posted", limit: 100 }),
    listAdvanceSettlementLines(settlementsRes.data.map((s) => s.id)),
  ]);
  const postedReceipts = receiptsRes.ok ? receiptsRes.data.receipts : [];
  const settlementLines = linesRes.ok ? linesRes.data : [];

  /** Chuỗi chứng từ của 1 phiếu quyết toán: số phiếu nhận đã gắn + "Có ảnh". */
  function settlementAttachments(settlementId: string): string {
    const sLines = settlementLines.filter(
      (l) => l.settlement_id === settlementId,
    );
    if (sLines.length === 0) {
      return vi.common.noData;
    }
    const grNos = [
      ...new Set(
        sLines.map((l) => l.gr_doc_no).filter((v): v is string => Boolean(v)),
      ),
    ];
    const hasPhoto = sLines.some((l) => l.receipt_photo_id !== null);
    const parts: string[] = [];
    if (grNos.length > 0) {
      parts.push(grNos.join(", "));
    }
    if (hasPhoto) {
      parts.push(vi.finance.settleHasPhoto);
    }
    return parts.length > 0 ? parts.join(" · ") : vi.common.noData;
  }

  return (
    <div className="space-y-4">
      <PageHeader title={`${vi.finance.advancesTitle} · ${advance.doc_no}`} />
      <div className="rounded-lg border bg-card p-4 text-sm">
        <p>
          {vi.finance.employee}: {advance.employee_name ?? vi.common.noData}
        </p>
        <p>
          {vi.finance.purpose}: {advance.purpose}
        </p>
        <p>
          {vi.finance.totalAmount}: <MoneyText amount={advance.amount} />
        </p>
        <p className="flex items-center gap-2">
          {vi.common.status}: <DocStatusBadge status={advance.status} />
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
        <AdvanceSettleForm
          propertyId={propertyId}
          advance={advance}
          postedReceipts={postedReceipts}
        />
      ) : advance.status === "settled" ? (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.components.docStatus.settled}
        </p>
      ) : (
        <p className="rounded-lg border bg-card p-4 text-sm text-muted-foreground">
          {vi.finance.noPermissionSettle}
        </p>
      )}

      <div className="rounded-lg border bg-card p-4">
        <h2 className="font-medium">{vi.finance.settlementHistory}</h2>
        {settlementsRes.data.length === 0 ? (
          <p className="mt-2 text-sm text-muted-foreground">
            {vi.components.table.emptyDescription}
          </p>
        ) : (
          <div className="mt-3 overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.requestDocNo}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.spentTotal}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.refundAmount}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                    {vi.finance.extraPayAmount}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.settleGrColumn}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.finance.paidAt}
                  </th>
                </tr>
              </thead>
              <tbody>
                {settlementsRes.data.map((s) => (
                  <tr key={s.id} className="border-t hover:bg-muted/40">
                    <td className="px-3 py-3 align-middle">{s.doc_no}</td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={s.amount} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={s.refund_amount} />
                    </td>
                    <td className="px-3 py-3 text-right align-middle">
                      <MoneyText amount={s.extra_pay_amount} />
                    </td>
                    <td className="px-3 py-3 align-middle">
                      {settlementAttachments(s.id)}
                    </td>
                    <td className="px-3 py-3 align-middle">{s.settled_at}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      <div className="rounded-lg border bg-card p-4">
        <h2 className="font-medium">{vi.finance.settleAttachedDocs}</h2>
        <div className="mt-3">
          <AttachmentGallery
            propertyId={propertyId}
            docType="advance_settlement"
            docId={advance.id}
          />
        </div>
      </div>
    </div>
  );
}
