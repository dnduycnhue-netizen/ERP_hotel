import { ErrorState } from "@/components/common/error-state";
import { MobileCountWorkspace } from "@/components/count/mobile-count-workspace";
import {
  getCount,
  getCountPerms,
  getCountSheet,
  getCountSheetItems,
  listCounters,
} from "@/features/count/queries";
import { createClient, getAuthenticatedUser } from "@/lib/supabase/server";

/**
 * Màn đếm mù mobile (T-033): phiếu đếm từ view `v_count_sheet` — chỉ
 * người đếm trong `counter_ids` mới thấy dòng, và chỉ thấy số của chính
 * mình (my_counted_qty). Người không phải người đếm thấy danh sách rỗng
 * + thông báo.
 */
export default async function MobileCountWorkspacePage({
  params,
}: {
  params: Promise<{ p: string; countId: string }>;
}) {
  const { p: propertyId, countId } = await params;
  const supabase = await createClient();
  const user = await getAuthenticatedUser(supabase);

  const [countRes, sheetRes, perms] = await Promise.all([
    getCount(countId),
    getCountSheet(countId),
    getCountPerms(propertyId),
  ]);

  if (!countRes.ok) {
    return <ErrorState description={countRes.error} />;
  }
  if (!sheetRes.ok) {
    return <ErrorState description={sheetRes.error} />;
  }

  const count = countRes.data;
  const sheet = sheetRes.data;
  const itemsRes = await getCountSheetItems(
    count.org_id,
    sheet.map((line) => line.item_id),
  );
  const items = itemsRes.ok ? itemsRes.data : {};

  const countersRes = perms.canOpen
    ? await listCounters(propertyId, count.warehouse_id)
    : { ok: false as const, error: "" };
  const counters = countersRes.ok ? countersRes.data : [];

  return (
    <MobileCountWorkspace
      count={count}
      sheet={sheet}
      items={items}
      counters={counters}
      eligibleCounters={counters}
      isCounter={user ? count.counter_ids.includes(user.id) : false}
      canOpen={perms.canOpen}
      canPerform={perms.canPerform}
      canViewVariance={perms.canViewVariance}
      propertyId={propertyId}
    />
  );
}
