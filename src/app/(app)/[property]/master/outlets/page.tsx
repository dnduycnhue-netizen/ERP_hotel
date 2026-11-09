import {
  listOutlets,
  listOutletTypes,
  listCostCenters,
} from "@/features/master/queries";
import { OutletsManager } from "@/components/master/outlets-manager";

export default async function OutletsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const [outlets, outletTypes, costCenters] = await Promise.all([
    listOutlets(propertyId),
    listOutletTypes(propertyId),
    listCostCenters(propertyId),
  ]);

  return (
    <OutletsManager
      propertyId={propertyId}
      outlets={outlets}
      outletTypes={outletTypes}
      costCenters={costCenters}
    />
  );
}
