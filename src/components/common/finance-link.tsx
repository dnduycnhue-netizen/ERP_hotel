"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu Tài chính (T-041).
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function FinanceLink({ propertyId }: { propertyId: string }) {
  const canManageInvoice = useCan("invoice.manage");
  const canApproveInvoice = useCan("invoice.approve");
  const canViewAp = useCan("ap.view");
  const canRequestPayment = useCan("payment.request");
  const canApprovePayment = useCan("payment.approve");
  const canMarkPaid = useCan("payment.mark_paid");
  const canSettleAdvance = useCan("advance.settle");

  if (
    !canManageInvoice &&
    !canApproveInvoice &&
    !canViewAp &&
    !canRequestPayment &&
    !canApprovePayment &&
    !canMarkPaid &&
    !canSettleAdvance
  ) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/finance`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.finance.title}
    </Link>
  );
}
