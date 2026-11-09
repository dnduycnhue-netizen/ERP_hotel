import {
  listSuppliers,
  listItems,
  listUoms,
  listPriceAgreements,
  listCeilingPrices,
} from "@/features/master/queries";
import { PricesManager } from "@/components/master/prices-manager";

export default async function PricesPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const [suppliers, itemsResult, uoms, agreements, ceilings] =
    await Promise.all([
      listSuppliers({ propertyId }),
      listItems({ propertyId, pageSize: 500 }),
      listUoms(),
      listPriceAgreements(propertyId),
      listCeilingPrices(propertyId),
    ]);

  return (
    <PricesManager
      propertyId={propertyId}
      suppliers={suppliers}
      items={itemsResult.items}
      uoms={uoms}
      agreements={agreements}
      ceilings={ceilings}
    />
  );
}
