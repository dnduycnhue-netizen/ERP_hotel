import { ErrorState } from "@/components/common/error-state";
import { MarketList } from "@/components/procurement/market-list";
import { listPos } from "@/features/procurement/queries";

/** Danh sach lenh mua cho (C6): PO co `channel = 'market'`, loc o RPC. */
export default async function ProcurementMarketPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{
    search?: string;
    status?: string;
    page?: string;
  }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;

  const search = sp.search || "";
  const status = sp.status || "";
  const page = Math.max(1, parseInt(sp.page || "1", 10) || 1);
  const pageSize = 20;

  const res = await listPos(propertyId, {
    channel: "market",
    status: status || undefined,
    search: search || undefined,
    page,
    pageSize,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return (
    <MarketList
      propertyId={propertyId}
      initialPos={res.data.rows}
      total={res.data.total}
      currentSearch={search}
      currentStatus={status}
      currentPage={page}
      pageSize={pageSize}
    />
  );
}
