"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu vực thu mua (PR/PO/duyệt).
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function ProcurementLink({ propertyId }: { propertyId: string }) {
  const canPrCreate = useCan("pr.create");
  const canPrApprove = useCan("pr.approve");
  const canPoCreate = useCan("po.create");
  const canPoView = useCan("po.view");

  if (!canPrCreate && !canPrApprove && !canPoCreate && !canPoView) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/procurement/pr`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.procurement.title}
    </Link>
  );
}
