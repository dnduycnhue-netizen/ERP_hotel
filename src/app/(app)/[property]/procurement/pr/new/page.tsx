import { PrForm } from "@/components/procurement/pr-form";
import {
  listCostCenters,
  listExpenseCategories,
  listOutlets,
} from "@/features/master/queries";

export default async function ProcurementPrNewPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [outlets, expenseCategories, costCenters] = await Promise.all([
    listOutlets(propertyId),
    listExpenseCategories(propertyId),
    listCostCenters(propertyId),
  ]);

  return (
    <PrForm
      propertyId={propertyId}
      outlets={outlets}
      expenseCategories={expenseCategories}
      costCenters={costCenters}
    />
  );
}
