import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { RestaurantNav } from "@/components/restaurant/restaurant-nav";
import { createClient } from "@/lib/supabase/server";

/**
 * Khu Nhà hàng (M06): món ăn, bếp, bán hàng, buffet, đặt tiệc.
 * Chặn người không có quyền nhà hàng nào ở tầng layout (RPC từng màn
 * hình kiểm tra lại quyền riêng của nó).
 */
export default async function RestaurantLayout({
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
    perms.has("restaurant.view") ||
    perms.has("restaurant.dish.manage") ||
    perms.has("restaurant.sale.record") ||
    perms.has("restaurant.buffet.manage") ||
    perms.has("restaurant.banquet.manage");

  if (!canAccess) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <RestaurantNav propertyId={propertyId} />
      {children}
    </div>
  );
}
