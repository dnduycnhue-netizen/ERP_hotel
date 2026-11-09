"use client";

import Link from "next/link";
import { ApprovalTimeline } from "@/components/procurement/approval-timeline";
import { MoneyText } from "@/components/common/money-text";
import { vi } from "@/i18n/vi";
import {
  decideApprovalAction,
  decidePrAction,
} from "@/features/procurement/actions";
import type { ApprovalStepRow } from "@/features/procurement/queries";

export type PendingApprovalItem = {
  docType: "pr" | "po";
  docId: string;
  docNo: string;
  kind: string;
  supplierName: string | null;
  totalAmount: number | null;
  createdAt: string;
  step: ApprovalStepRow;
};

/**
 * Hộp thư chờ tôi duyệt (T-021, "duyệt nhanh trên mobile"): mỗi thẻ là
 * một chứng từ đang ở bước duyệt của người dùng hiện tại, duyệt/từ
 * chối ngay tại chỗ không cần mở chi tiết. Server đã lọc sẵn: chỉ bước
 * pending mà người dùng có quyền duyệt, và loại chứng từ do chính mình
 * tạo (SoD). Lỗi SoD/ủy quyền còn lại do RPC kiểm tra và hiện ở timeline.
 */
export function ApprovalInbox({
  propertyId,
  items,
}: {
  propertyId: string;
  items: PendingApprovalItem[];
}) {
  if (items.length === 0) {
    return (
      <div className="rounded-xl border p-8 text-center">
        <h2 className="text-lg font-semibold">{vi.procurement.inbox.title}</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.procurement.inbox.emptyTitle}
        </p>
        <p className="mt-1 text-xs text-muted-foreground">
          {vi.procurement.inbox.emptyDescription}
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold">{vi.procurement.inbox.title}</h2>
        <p className="text-xs text-muted-foreground mt-0.5">
          {vi.procurement.inbox.description}
        </p>
      </div>

      {items.map((item) => (
        <div
          key={`${item.docType}-${item.docId}`}
          className="rounded-xl border p-4 space-y-3"
        >
          <div className="flex items-start justify-between gap-4 flex-wrap">
            <div>
              <Link
                href={`/${propertyId}/procurement/${item.docType}/${item.docId}`}
                className="font-mono text-sm font-bold text-primary hover:underline"
              >
                {item.docNo}
              </Link>
              <p className="mt-0.5 text-sm text-muted-foreground">
                {item.docType === "pr"
                  ? vi.procurement.nav.pr
                  : vi.procurement.nav.po}
                {item.supplierName ? ` · ${item.supplierName}` : ""}
                {item.totalAmount !== null ? (
                  <>
                    {" · "}
                    <MoneyText amount={item.totalAmount} />
                  </>
                ) : null}
                {` · ${new Date(item.createdAt).toLocaleDateString("vi-VN")}`}
              </p>
              <p className="text-xs text-muted-foreground">
                {vi.procurement.inbox.stepRole}:{" "}
                {item.step.approver_role_name ?? item.step.required_perm}
              </p>
            </div>
            <Link
              href={`/${propertyId}/procurement/${item.docType}/${item.docId}`}
              className="text-sm text-primary hover:underline"
            >
              {vi.procurement.inbox.openDetail}
            </Link>
          </div>

          <ApprovalTimeline
            steps={[item.step]}
            onDecide={async (decision, comment) =>
              item.docType === "pr"
                ? decidePrAction({
                    propertyId,
                    prId: item.docId,
                    decision,
                    comment,
                  })
                : decideApprovalAction({
                    propertyId,
                    docType: "po",
                    docId: item.docId,
                    decision,
                    comment,
                  })
            }
          />
        </div>
      ))}
    </div>
  );
}
