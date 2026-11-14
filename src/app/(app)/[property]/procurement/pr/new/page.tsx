import { EmptyState } from "@/components/common/empty-state";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";
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

  // Thiếu quyền tạo PR thì không hiện form (C7-N2); RPC vẫn kiểm lại.
  const { data: myPerms } = await (await createClient()).rpc("my_permissions", {
    p_property: propertyId,
  });
  if (!(myPerms ?? []).includes("pr.create")) {
    return <EmptyState title={vi.procurement.pr.noCreatePermission} />;
  }

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
