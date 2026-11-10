import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

/**
 * Khu buồng phòng — minibar văn phòng (T-035).
 * Chặn người không có quyền minibar/văn phòng nào ở tầng layout.
 */
export default async function HousekeepingLayout({
  children,
  params,
}: Readonly<{
  children: ReactNode;
  params: Promise<{ property: string }>;
}>) {
  const { property: propertyId } = await params;
  const supabase = await createClient();

  const { data: myPerms } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });

  const perms = new Set(myPerms ?? []);
  const canAccess =
    perms.has("minibar.check") ||
    perms.has("minibar.refill") ||
    perms.has("minibar.price.manage") ||
    perms.has("minibar.reconcile") ||
    perms.has("report.view.rpt_minibar");

  if (!canAccess) {
    notFound();
  }

  return <div className="space-y-6">{children}</div>;
}
