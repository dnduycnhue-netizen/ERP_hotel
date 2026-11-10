"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu vực lễ tân — minibar (T-035).
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function FrontdeskLink({ propertyId }: { propertyId: string }) {
  const canRequestCheck = useCan("minibar.request_check");
  const canConfirmCharge = useCan("minibar.charge.confirm");
  const canWaiveRequest = useCan("minibar.waive.request");
  const canWaiveApprove = useCan("minibar.waive.approve");

  if (
    !canRequestCheck &&
    !canConfirmCharge &&
    !canWaiveRequest &&
    !canWaiveApprove
  ) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/frontdesk/minibar`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.minibar.frontdeskTitle}
    </Link>
  );
}
