import { listUoms } from "@/features/master/queries";
import { UomsManager } from "@/components/master/uoms-manager";

export default async function UomsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const uoms = await listUoms();

  return <UomsManager propertyId={propertyId} uoms={uoms} />;
}
