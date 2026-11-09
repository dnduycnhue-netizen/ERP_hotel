"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu vực buồng phòng — minibar văn phòng (T-035).
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function HousekeepingLink({ propertyId }: { propertyId: string }) {
  const canCheck = useCan("minibar.check");
  const canRefill = useCan("minibar.refill");
  const canPriceManage = useCan("minibar.price.manage");
  const canReconcile = useCan("minibar.reconcile");
  const canViewReport = useCan("report.view.rpt_minibar");

  if (
    !canCheck &&
    !canRefill &&
    !canPriceManage &&
    !canReconcile &&
    !canViewReport
  ) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/housekeeping/minibar`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.minibar.housekeepingTitle}
    </Link>
  );
}
