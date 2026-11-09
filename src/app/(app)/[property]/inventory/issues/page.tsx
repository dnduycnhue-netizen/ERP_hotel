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
import { listPurposeIssuesAction } from "@/features/inventory/actions";
import { vi } from "@/i18n/vi";

const STATUSES = ["draft", "posted", "reversed", "cancelled"] as const;

/** Danh sách xuất mục đích (T-031). Không hiện giá vốn ở danh sách. */
export default async function PurposeIssuesPage({
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

  const res = await listPurposeIssuesAction({
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
    return `/${propertyId}/inventory/issues${qs ? `?${qs}` : ""}`;
  }

  function purposeLabel(code: string): string {
    return (
      vi.inventory.purposeCodes[
        code as keyof typeof vi.inventory.purposeCodes
      ] ?? code
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-2xl font-semibold">{vi.inventory.issuesTitle}</h1>

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
        {total} {vi.inventory.issuesTitle.toLowerCase()}
      </p>

      {rows.length === 0 ? (
        <EmptyState
          title={vi.inventory.issuesTitle}
          description={vi.inventory.issuesEmpty}
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
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.purpose}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.warehouse}
                </th>
                <th className="px-4 py-3 font-medium">
                  {vi.inventory.costCenter}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.lineCount}
                </th>
                <th className="px-4 py-3 text-right font-medium">
                  {vi.inventory.totalQty}
                </th>
              </tr>
            </thead>
            <tbody>
              {rows.map((row) => (
                <tr key={row.id} className="border-b last:border-b-0">
                  <td className="px-4 py-3">
                    <Link
                      href={`/${propertyId}/inventory/issues/${row.id}`}
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
                  <td className="px-4 py-3">
                    {purposeLabel(row.purpose_code)}
                  </td>
                  <td className="px-4 py-3">{row.warehouse_name ?? "—"}</td>
                  <td className="px-4 py-3">{row.cost_center_name ?? "—"}</td>
                  <td className="px-4 py-3 text-right">{row.line_count}</td>
                  <td className="px-4 py-3 text-right">
                    {formatNumber(row.total_qty_stock)}
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
