import { ErrorState } from "@/components/common/error-state";
import { ModuleDisabled } from "@/components/common/module-disabled";
import { getPropertyModules } from "@/lib/modules/server";
import { PosImportForm } from "@/components/inventory/pos-import-form";
import { PageHeader } from "@/components/shell/page-header";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/** Nạp file POS của ca (Q34, P2): điều kiện để mở kiểm kê theo ca. */
export default async function PosImportPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const supabase = await createClient();
  // Nạp POS thuộc module Nhà hàng: tắt module thì không hiện form (B-20).
  const modules = await getPropertyModules(supabase, propertyId);
  if (!modules.restaurant) {
    return <ModuleDisabled name={vi.admin.modules.restaurant} />;
  }
  const { data: allowed } = await supabase.rpc("has_perm", {
    p_property: propertyId,
    p_perm: "pos.import",
  });
  if (!allowed) {
    return <ErrorState description={vi.inventory.posImport.noPermission} />;
  }
  return (
    <div className="space-y-6">
      <PageHeader title={vi.inventory.posImport.title} />
      <PosImportForm propertyId={propertyId} />
    </div>
  );
}
