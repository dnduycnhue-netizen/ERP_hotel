import { ErrorState } from "@/components/common/error-state";
import { MobileNewReturnForm } from "@/components/receiving/mobile-new-return-form";
import { listReceiptsAction } from "@/features/receiving/actions";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/**
 * Tao phieu tra hang NCC tren mobile (T-026).
 * Chi nguoi co `supplier_return.post` moi mo duoc form; chi chon duoc
 * phieu nhan da ghi so (status=posted) de tra hang.
 */
export default async function MobileNewReturnPage({
  params,
}: {
  params: Promise<{ p: string }>;
}) {
  const { p: propertyId } = await params;
  const supabase = await createClient();
  const { data: myPermissions } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });
  if (!myPermissions?.includes("supplier_return.post")) {
    return <ErrorState description={vi.receiving.noReturnPermission} />;
  }

  const res = await listReceiptsAction({
    propertyId,
    status: "posted",
    limit: 50,
    offset: 0,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return (
    <MobileNewReturnForm
      propertyId={propertyId}
      postedReceipts={res.data.receipts}
    />
  );
}
