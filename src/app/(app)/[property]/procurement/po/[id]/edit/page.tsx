import { notFound, redirect } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { PoForm } from "@/components/procurement/po-form";
import { getPo } from "@/features/procurement/queries";
import {
  listCostCenters,
  listExpenseCategories,
} from "@/features/master/queries";

export default async function ProcurementPoEditPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: poId } = await params;

  const poRes = await getPo(propertyId, poId);
  if (!poRes.ok) {
    return <ErrorState description={poRes.error} />;
  }
  if (!poRes.data.po) {
    notFound();
  }
  // Chỉ sửa được nháp (kể cả nháp bị từ chối trả về); các trạng thái
  // khác quay về trang chi tiết.
  if (poRes.data.po.status !== "draft" && poRes.data.po.status !== "rejected") {
    redirect(`/${propertyId}/procurement/po/${poId}`);
  }

  const [expenseCategories, costCenters] = await Promise.all([
    listExpenseCategories(propertyId),
    listCostCenters(propertyId),
  ]);

  return (
    <PoForm
      propertyId={propertyId}
      po={poRes.data.po}
      lines={poRes.data.lines}
      expenseCategories={expenseCategories}
      costCenters={costCenters}
    />
  );
}
