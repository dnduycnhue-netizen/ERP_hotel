import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { MasterNav } from "@/components/master/master-nav";
import { createClient } from "@/lib/supabase/server";

export default async function MasterLayout({
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
    perms.has("item.view") ||
    perms.has("item.manage") ||
    perms.has("warehouse.manage") ||
    perms.has("room.manage");

  if (!canAccess) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <MasterNav propertyId={propertyId} />
      {children}
    </div>
  );
}
