import { redirect } from "next/navigation";

/** Mặc định khu kho mở danh sách phiếu lĩnh. */
export default async function InventoryPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  redirect(`/${propertyId}/inventory/requisitions`);
}
