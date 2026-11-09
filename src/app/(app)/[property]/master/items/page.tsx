import { listItems, listItemGroups, listUoms } from "@/features/master/queries";
import { ItemsList } from "@/components/master/items-list";

export default async function MasterItemsPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{
    search?: string;
    group?: string;
    filter?: "all" | "key" | "temp" | "missing_conv";
    page?: string;
  }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;

  const search = sp.search || "";
  const groupId = sp.group || "";
  const filter = sp.filter || "all";
  const page = Math.max(1, parseInt(sp.page || "1", 10) || 1);
  const pageSize = 20;

  const isTemp = filter === "temp" ? true : undefined;
  const isKeyItem = filter === "key" ? true : undefined;
  const missingConversion = filter === "missing_conv" ? true : undefined;

  const [itemsData, groups, uoms] = await Promise.all([
    listItems({
      propertyId,
      search,
      groupId: groupId || undefined,
      isTemp,
      isKeyItem,
      missingConversion,
      page,
      pageSize,
    }),
    listItemGroups(propertyId),
    listUoms(),
  ]);

  return (
    <ItemsList
      propertyId={propertyId}
      initialItems={itemsData.items}
      total={itemsData.total}
      groups={groups}
      uoms={uoms}
      currentSearch={search}
      currentGroupId={groupId}
      currentFilter={filter}
      currentPage={page}
      pageSize={pageSize}
    />
  );
}
