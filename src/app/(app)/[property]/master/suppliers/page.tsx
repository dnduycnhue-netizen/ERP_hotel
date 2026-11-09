import { listSuppliers } from "@/features/master/queries";
import { SuppliersManager } from "@/components/master/suppliers-manager";

export default async function SuppliersPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const suppliers = await listSuppliers({ propertyId });

  return <SuppliersManager propertyId={propertyId} suppliers={suppliers} />;
}
