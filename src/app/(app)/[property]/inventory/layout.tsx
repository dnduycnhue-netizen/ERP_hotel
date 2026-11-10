import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { InventoryNav } from "@/components/inventory/inventory-nav";
import { createClient } from "@/lib/supabase/server";

/**
 * Khu kho (T-031): chứng từ kho, tồn kho, thẻ kho.
 * Chặn người không có quyền kho nào ở tầng layout (RPC từng màn hình
 * kiểm tra lại quyền riêng của nó).
 */
export default async function InventoryLayout({
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
    perms.has("requisition.create") ||
    perms.has("requisition.approve") ||
    perms.has("requisition.issue") ||
    perms.has("requisition.receive") ||
    perms.has("transfer.send") ||
    perms.has("transfer.receive") ||
    perms.has("purpose_issue.post") ||
    perms.has("purpose_issue.reverse") ||
    perms.has("waste.propose") ||
    perms.has("waste.approve") ||
    perms.has("waste.approve.large") ||
    perms.has("count.open") ||
    perms.has("count.perform") ||
    perms.has("count.view_variance") ||
    perms.has("count.lock") ||
    perms.has("count.adjust.approve") ||
    perms.has("day.lock") ||
    perms.has("day.unlock") ||
    perms.has("period.close") ||
    perms.has("period.reopen") ||
    perms.has("stock.view_qty") ||
    perms.has("stock.view_value");

  if (!canAccess) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <InventoryNav propertyId={propertyId} />
      {children}
    </div>
  );
}
