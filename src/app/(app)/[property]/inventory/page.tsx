import { redirect } from "next/navigation";
import { inventoryLandingPath } from "@/components/shell/nav-items";
import { getModuleAwarePermissions } from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";

/** Khu kho mở màn đầu tiên người dùng có quyền xem (R5-N5), mặc định phiếu lĩnh. */
export default async function InventoryPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const supabase = await createClient();
  const permissions = await getModuleAwarePermissions(supabase, propertyId);
  redirect(inventoryLandingPath(propertyId, new Set(permissions)));
}
