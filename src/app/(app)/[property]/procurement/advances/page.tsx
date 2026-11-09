import { ErrorState } from "@/components/common/error-state";
import { AdvanceList } from "@/components/procurement/advance-list";
import { listAdvances } from "@/features/procurement/queries";

export default async function ProcurementAdvancesPage({
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

  const res = await listAdvances(propertyId, {
    status: status || undefined,
    search: search || undefined,
    page,
    pageSize,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  return (
    <AdvanceList
      propertyId={propertyId}
      initialAdvances={res.data.rows}
      total={res.data.total}
      currentSearch={search}
      currentStatus={status}
      currentPage={page}
      pageSize={pageSize}
    />
  );
}
