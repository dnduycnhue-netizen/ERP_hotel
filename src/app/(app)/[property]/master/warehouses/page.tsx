import { listWarehouses, listOutlets } from "@/features/master/queries";
import { WarehousesManager } from "@/components/master/warehouses-manager";

export default async function WarehousesPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const [warehouses, outlets] = await Promise.all([
    listWarehouses(propertyId),
    listOutlets(propertyId),
  ]);

  return (
    <WarehousesManager
      propertyId={propertyId}
      warehouses={warehouses}
      outlets={outlets}
    />
  );
}
