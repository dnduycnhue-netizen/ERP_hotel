import { notFound, redirect } from "next/navigation";
import { ErrorState } from "@/components/common/error-state";
import { PrForm } from "@/components/procurement/pr-form";
import { getPr } from "@/features/procurement/queries";
import {
  listCostCenters,
  listExpenseCategories,
  listOutlets,
} from "@/features/master/queries";

export default async function ProcurementPrEditPage({
  params,
}: {
  params: Promise<{ property: string; id: string }>;
}) {
  const { property: propertyId, id: prId } = await params;

  const prRes = await getPr(propertyId, prId);
  if (!prRes.ok) {
    return <ErrorState description={prRes.error} />;
  }
  if (!prRes.data.pr) {
    notFound();
  }
  // Chỉ sửa được nháp (kể cả nháp bị từ chối trả về); các trạng thái
  // khác quay về trang chi tiết.
  if (prRes.data.pr.status !== "draft" && prRes.data.pr.status !== "rejected") {
    redirect(`/${propertyId}/procurement/pr/${prId}`);
  }

  const [outlets, expenseCategories, costCenters] = await Promise.all([
    listOutlets(propertyId),
    listExpenseCategories(propertyId),
    listCostCenters(propertyId),
  ]);

  return (
    <PrForm
      propertyId={propertyId}
      initial={{ pr: prRes.data.pr, lines: prRes.data.lines }}
      outlets={outlets}
      expenseCategories={expenseCategories}
      costCenters={costCenters}
    />
  );
}
