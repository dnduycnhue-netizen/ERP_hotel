import { MarketOrderForm } from "@/components/procurement/market-order-form";
import {
  listCostCenters,
  listExpenseCategories,
} from "@/features/master/queries";

export default async function ProcurementMarketNewPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [expenseCategories, costCenters] = await Promise.all([
    listExpenseCategories(propertyId),
    listCostCenters(propertyId),
  ]);

  return (
    <MarketOrderForm
      propertyId={propertyId}
      expenseCategories={expenseCategories}
      costCenters={costCenters}
    />
  );
}
