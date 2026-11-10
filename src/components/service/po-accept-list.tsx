"use client";

import { Button } from "@/components/ui/button";
import { MoneyText } from "@/components/common/money-text";
import type { ServicePoRow } from "@/features/service/queries";
import { vi } from "@/i18n/vi";

/**
 * Đơn mua dịch vụ lẻ chờ nghiệm thu (T-042, Q75/Q78): PO kind='service'
 * chưa có nghiệm thu trực tiếp theo PO và chưa có kỳ accepted nào của
 * hợp đồng nó trỏ tới. Nghiệm thu xong mới lập hóa đơn / thanh toán được.
 */
export function PoAcceptList({
  propertyId,
  pos,
  canAccept,
  onAcceptPo,
}: {
  propertyId: string;
  pos: ServicePoRow[];
  canAccept: boolean;
  onAcceptPo: (po: ServicePoRow) => void;
}) {
  return (
    <div className="rounded-lg border bg-card p-4">
      <h2 className="font-medium">{vi.service.pendingPosTitle}</h2>
      <p className="mt-1 text-sm text-muted-foreground">
        {vi.service.pendingPosHint}
      </p>
      {pos.length === 0 ? (
        <p className="mt-3 text-sm text-muted-foreground">
          {vi.service.noPendingPos}
        </p>
      ) : (
        <div className="mt-3 overflow-x-auto">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.service.poDocNo}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.finance.supplier}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.service.contractTitle}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.service.orderDate}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.finance.totalAmount}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.actions}
                </th>
              </tr>
            </thead>
            <tbody>
              {pos.map((po) => (
                <tr key={po.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 align-middle">
                    <a
                      href={`/${propertyId}/procurement/po/${po.id}`}
                      className="font-medium hover:underline"
                    >
                      {po.doc_no}
                    </a>
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {po.supplier_name ?? vi.common.noData}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {po.contract_title ?? vi.common.noData}
                  </td>
                  <td className="px-3 py-3 align-middle">{po.order_date}</td>
                  <td className="px-3 py-3 text-right align-middle">
                    <MoneyText amount={po.total_amount} />
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {canAccept ? (
                      <Button
                        type="button"
                        size="sm"
                        onClick={() => onAcceptPo(po)}
                      >
                        {vi.service.acceptButton}
                      </Button>
                    ) : (
                      <span className="text-xs text-muted-foreground">
                        {vi.service.noPermissionAccept}
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
