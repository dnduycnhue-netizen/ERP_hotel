import { StockDocForm } from "@/components/inventory/stock-doc-form";
import {
  listCostCenters,
  listExpenseCategories,
  listOutlets,
  listWarehouses,
} from "@/features/master/queries";

/** Lập chứng từ kho: phiếu lĩnh (B-4). */
export default async function RequisitionNewPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const [warehouses, outlets, costCenters, expenseCategories] =
    await Promise.all([
      listWarehouses(propertyId),
      listOutlets(propertyId),
      listCostCenters(propertyId),
      listExpenseCategories(propertyId),
    ]);

  return (
    <StockDocForm
      kind="requisition"
      propertyId={propertyId}
      warehouses={warehouses}
      outlets={outlets}
      costCenters={costCenters}
      expenseCategories={expenseCategories}
    />
  );
}
