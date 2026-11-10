"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Bell } from "lucide-react";
import { usePermissions } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link "Cảnh báo" trên header (T-045).
 * Hiện khi có bất kỳ quyền alert.receive.* nào.
 */
export function AlertsLink({ propertyId }: { propertyId: string }) {
  const pathname = usePathname();
  const { permissions } = usePermissions();
  const canAny = [...permissions].some((p) => p.startsWith("alert.receive."));

  if (!canAny) return null;

  const active = pathname.startsWith(`/${propertyId}/alerts`);
  return (
    <Link
      href={`/${propertyId}/alerts`}
      className={
        active
          ? "inline-flex items-center gap-1.5 rounded-md bg-primary/10 px-2 py-1 text-sm font-medium text-primary"
          : "inline-flex items-center gap-1.5 rounded-md px-2 py-1 text-sm text-muted-foreground hover:text-foreground"
      }
    >
      <Bell className="h-4 w-4" />
      {vi.alerts.title}
    </Link>
  );
}
