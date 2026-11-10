import { ErrorState } from "@/components/common/error-state";
import { HallManager } from "@/components/restaurant/hall-manager";
import {
  getRestaurantPerms,
  listBanquetHalls,
} from "@/features/restaurant/queries";
import { vi } from "@/i18n/vi";

/** Danh mục sảnh tiệc (C11, Q170b). */
export default async function HallsPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;

  const [res, perms] = await Promise.all([
    listBanquetHalls(propertyId),
    getRestaurantPerms(propertyId),
  ]);
  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return (
    <div className="space-y-4">
      <div>
        <h1 className="text-xl font-semibold">{vi.restaurant.hallsTitle}</h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.restaurant.hallsHint}
        </p>
      </div>
      <HallManager
        propertyId={propertyId}
        halls={res.data}
        canManage={perms.canManageBanquet}
      />
    </div>
  );
}
