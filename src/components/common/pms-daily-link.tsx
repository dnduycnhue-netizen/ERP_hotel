"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới form số liệu PMS ngày (T-036).
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function PmsDailyLink({ propertyId }: { propertyId: string }) {
  const canEnter = useCan("pms.input");

  if (!canEnter) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/frontdesk/pms-daily`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.pmsDaily.title}
    </Link>
  );
}
