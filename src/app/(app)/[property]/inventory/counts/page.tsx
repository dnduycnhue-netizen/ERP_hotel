import Link from "next/link";
import {
  DocStatusBadge,
  getDocStatusLabel,
} from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import {
  DocPagination,
  StatusFilter,
} from "@/components/inventory/doc-list-controls";
import { listCounts } from "@/features/count/queries";
import { vi } from "@/i18n/vi";

const STATUSES = [
  "open",
  "counting",
  "recount",
  "submitted",
  "locked",
  "adjusted",
  "cancelled",
] as const;

/** Danh sách đợt kiểm kê (T-033) — chỉ số chứng từ, kho, ngày, loại, trạng thái. */
export default async function CountsPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ status?: string; page?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const status = (STATUSES as readonly string[]).includes(sp.status ?? "")
    ? (sp.status as string)
    : "";
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const pageSize = 20;

  const res = await listCounts({
    propertyId,
    status: status === "" ? null : (status as (typeof STATUSES)[number]),
    warehouseId: null,
    limit: pageSize,
    offset: (page - 1) * pageSize,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const { items, total } = res.data;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  function hrefWith(params: Record<string, string | undefined>): string {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") {
        query.set(key, value);
      }
    }
    const qs = query.toString();
    return `/${propertyId}/inventory/counts${qs ? `?${qs}` : ""}`;
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-3">
        <h1 className="text-2xl font-semibold">{vi.count.countsTitle}</h1>
        <Link
          href={`/${propertyId}/inventory/counts/new`}
          className="rounded-lg border bg-card px-3 py-1.5 text-sm font-medium hover:border-ring"
        >
          {vi.count.openButton}
        </Link>
      </div>

      <StatusFilter
        status={status}
        options={[
          { value: "", label: vi.common.all },
          ...STATUSES.map((value) => ({
            value,
            label: getDocStatusLabel(value),
          })),
        ]}
        hrefForStatus={(nextStatus) =>
          hrefWith({ status: nextStatus, page: "1" })
        }
      />

      {items.length === 0 ? (
        <EmptyState title={vi.count.countsEmpty} />
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-3 py-2 font-medium">{vi.count.docNo}</th>
                <th className="px-3 py-2 font-medium">{vi.count.warehouse}</th>
                <th className="px-3 py-2 font-medium">
                  {vi.count.businessDate}
                </th>
                <th className="px-3 py-2 font-medium">{vi.count.kind}</th>
                <th className="px-3 py-2 font-medium">{vi.count.status}</th>
              </tr>
            </thead>
            <tbody>
              {items.map((count) => (
                <tr key={count.id} className="border-b last:border-0">
                  <td className="px-3 py-2">
                    <Link
                      href={`/${propertyId}/inventory/counts/${count.id}`}
                      className="font-medium text-primary underline"
                    >
                      {count.doc_no}
                    </Link>
                  </td>
                  <td className="px-3 py-2">
                    {count.warehouse_name ?? vi.common.noData}
                  </td>
                  <td className="px-3 py-2">{count.business_date}</td>
                  <td className="px-3 py-2">
                    {count.kind === "monthly_full"
                      ? vi.count.kindMonthlyFull
                      : count.kind === "cycle"
                        ? vi.count.kindCycle
                        : count.kind === "shift_key"
                          ? vi.count.kindShiftKey
                          : count.kind === "trolley"
                            ? vi.count.kindTrolley
                            : vi.count.kindMinibarAudit}
                  </td>
                  <td className="px-3 py-2">
                    <DocStatusBadge status={count.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      <DocPagination
        page={page}
        totalPages={totalPages}
        hrefForPage={(nextPage) => hrefWith({ status, page: String(nextPage) })}
      />
    </div>
  );
}
