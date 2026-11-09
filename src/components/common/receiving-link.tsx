"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu vực nhận hàng / trả hàng NCC (T-026).
 * Kiểm tra quyền bằng `useCan` theo Rule 10 của AGENTS.md.
 */
export function ReceivingLink({ propertyId }: { propertyId: string }) {
  const canView = useCan("receiving.view");
  const canReturn = useCan("supplier_return.post");

  if (!canView && !canReturn) {
    return null;
  }
  return (
    <Link
      href={`/${propertyId}/receiving/returns`}
      className="text-sm font-medium text-foreground/80 hover:text-foreground hover:underline"
    >
      {vi.receiving.receivingTitle}
    </Link>
  );
}
