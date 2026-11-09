import { listItemGroups } from "@/features/master/queries";
import { ItemGroupsManager } from "@/components/master/item-groups-manager";

export default async function ItemGroupsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const groups = await listItemGroups(propertyId);

  return <ItemGroupsManager propertyId={propertyId} groups={groups} />;
}
