import Link from "next/link";
import {
  DocStatusBadge,
  getDocStatusLabel,
} from "@/components/common/doc-status-badge";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import {
  DocPagination,
  DocSearchForm,
  StatusFilter,
} from "@/components/inventory/doc-list-controls";
import { formatNumber } from "@/components/common/money-text";
import { listRequisitionsAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";

const STATUSES = [
  "draft",
  "submitted",
  "approved",
  "issued",
  "partially_received",
  "received",
  "cancelled",
] as const;

/** Danh sách phiếu lĩnh (T-031) — chỉ số lượng, không giá vốn. */
export default async function RequisitionsPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ status?: string; search?: string; page?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const status = (STATUSES as readonly string[]).includes(sp.status ?? "")
    ? (sp.status as string)
    : "";
  const search = sp.search ?? "";
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const pageSize = 20;

  const res = await listRequisitionsAction({
    propertyId,
    status: status === "" ? null : status,
    search: search === "" ? null : search,
    limit: pageSize,
    offset: (page - 1) * pageSize,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const { rows, total } = res.data;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  function hrefWith(params: Record<string, string | undefined>): string {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") {
        query.set(key, value);
      }
    }
    const qs = query.toString();
    return `/${propertyId}/inventory/requisitions${qs ? `?${qs}` : ""}`;
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold">
        {vi.inventory.requisitionsTitle}
      </h1>

      <StatusFilter
        status={status}
        options={[
          { value: "", label: vi.common.all },
          ...STATUSES.map((value) => ({
            value,
            label: getDocStatusLabel(value),
          })),
        ]}
        hrefForStatus={(value) =>
          hrefWith({ status: value, search: search || undefined })
        }
      />

      <DocSearchForm
        placeholder={vi.inventory.searchDocPlaceholder}
        defaultValue={search}
        status={status}
      />

      <p className="text-sm text-muted-foreground">
        {total} {vi.inventory.requisitionsTitle.toLowerCase()}
      </p>

      {rows.length === 0 ? (
        <EmptyState
          title={vi.inventory.requisitionsTitle}
          description={vi.inventory.requisitionsEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-xl border bg-card shadow-sm">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-4 py-3 font-medium">{vi.inventory.docNo}</th>
                <th className="px-4 py-3 font-medium">{vi.common.status}</th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.businessDate}
                </th>
                <th className="px-4 py-3 font-medium">{vi.inventory.outlet}</th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.fromWarehouse}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.toWarehouse}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.lineCount}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.totalQty}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.totalIssued}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.totalReceived}
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id} className="border-b last:border-b-0">
                  <td className="px-4 py-3">
                    <Link
                      href={`/${propertyId}/inventory/requisitions/${row.id}`}
                      className="font-medium hover:underline"
                    >
                      {row.doc_no}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    <DocStatusBadge status={row.status} />
                  </td>
                  <td className="px-4 py-3 whitespace-nowrap">
                    {row.business_date}
                  </td>
                  <td className="px-4 py-3">{row.outlet_name ?? "—"}</td>
                  <td className="px-4 py-3">
                    {row.from_warehouse_name ?? "—"}
                  </td>
                  <td className="px-4 py-3">{row.to_warehouse_name ?? "—"}</td>
                  <td className="px-4 py-3 text-right">{row.line_count}</td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(row.total_qty_stock)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(row.total_issued_qty_stock)}
                  </td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(row.total_received_qty_stock)}
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
        hrefForPage={(next) =>
          hrefWith({
            status: status || undefined,
            search: search || undefined,
            page: String(next),
          })
        }
      />
    </div>
  );
}
