import { listItemGroups, listUoms } from "@/features/master/queries";
import {
  getImportBatch,
  listImportBatches,
  listImportMappings,
} from "@/features/master/import-queries";
import { ImportWizard } from "@/components/master/import-wizard";

export default async function MasterImportPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ batch?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const batchId = sp.batch || "";

  const [groups, uoms, mappings, batches, batch] = await Promise.all([
    listItemGroups(propertyId),
    listUoms(),
    listImportMappings(propertyId),
    listImportBatches(propertyId),
    batchId ? getImportBatch(batchId) : Promise.resolve(null),
  ]);

  return (
    <ImportWizard
      propertyId={propertyId}
      groups={groups}
      uoms={uoms}
      mappings={mappings}
      batches={batches}
      initialBatch={batch}
    />
  );
}
