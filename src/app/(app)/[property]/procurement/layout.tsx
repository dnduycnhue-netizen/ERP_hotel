import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { ProcurementNav } from "@/components/procurement/procurement-nav";
import { createClient } from "@/lib/supabase/server";

/** Khu thu mua (T-021): chặn người không có quyền PR/PO ở tầng layout. */
export default async function ProcurementLayout({
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
    perms.has("pr.create") ||
    perms.has("pr.approve") ||
    perms.has("po.create") ||
    perms.has("po.view") ||
    perms.has("market.order.create") ||
    perms.has("advance.request") ||
    perms.has("advance.approve") ||
    perms.has("advance.disburse") ||
    perms.has("advance.settle") ||
    perms.has("service.contract.manage") ||
    perms.has("service.accept");

  if (!canAccess) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <ProcurementNav propertyId={propertyId} />
      {children}
    </div>
  );
}
