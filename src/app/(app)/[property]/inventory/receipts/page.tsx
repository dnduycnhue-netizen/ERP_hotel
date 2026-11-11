import Link from "next/link";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { listReceiptsAction } from "@/features/receiving/actions";
import { vi } from "@/i18n/vi";
import { PageHeader } from "@/components/shell/page-header";

/**
 * Danh sach phieu nhan tren desktop (C6) — chi xem de soat.
 * RPC `receiving_list_receipts` (T-023): nguoi nhan chi thay phieu cua
 * chinh minh, khong thay phieu da post; tong tien chi tra khi co
 * `po.view_price` nen bang nay khong hien cot tien.
 * Ghi/dao phieu lam tren mobile hien truong (`/m/[p]/receive/[grId]`);
 * so phieu mo sang chi tiet don mua (chua co trang chi tiet GRN desktop).
 */
export default async function InventoryReceiptsPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ status?: string; search?: string; page?: string }>;
}) {
  const { property: propertyId } = await params;
  const sp = await searchParams;
  const status = sp.status ?? "";
  const search = sp.search ?? "";
  const page = Math.max(1, parseInt(sp.page ?? "1", 10) || 1);
  const pageSize = 20;

  const res = await listReceiptsAction({
    propertyId,
    status:
      status === "draft" ||
      status === "needs_recount" ||
      status === "posted" ||
      status === "reversed"
        ? status
        : null,
    search: search === "" ? null : search,
    limit: pageSize,
    offset: (page - 1) * pageSize,
  });

  if (!res.ok) {
    return <ErrorState description={res.error} />;
  }

  const { receipts, total } = res.data;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));

  function statusLabel(value: string): string {
    switch (value) {
      case "needs_recount":
        return vi.receiving.statusNeedsRecount;
      case "posted":
        return vi.receiving.statusPosted;
      case "reversed":
        return vi.receiving.statusReversed;
      default:
        return vi.receiving.statusDraft;
    }
  }

  function hrefWith(params: Record<string, string | undefined>): string {
    const query = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined && value !== "") {
        query.set(key, value);
      }
    }
    const qs = query.toString();
    return `/${propertyId}/inventory/receipts${qs ? `?${qs}` : ""}`;
  }

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={vi.receiving.listTitle} />

      <form method="get" className="flex flex-wrap gap-2">
        <input
          type="search"
          name="search"
          defaultValue={search}
          placeholder={vi.receiving.receiptsSearchPlaceholder}
          aria-label={vi.receiving.receiptsSearchPlaceholder}
          className="h-9 w-full max-w-sm flex-1 rounded-md border bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
        />
        {status !== "" ? (
          <input type="hidden" name="status" value={status} />
        ) : null}
        <button
          type="submit"
          className="h-9 shrink-0 rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.common.search}
        </button>
      </form>

      <div className="flex flex-wrap gap-1.5">
        {(
          [
            ["", vi.common.all],
            ["draft", vi.receiving.statusDraft],
            ["needs_recount", vi.receiving.statusNeedsRecount],
            ["posted", vi.receiving.statusPosted],
            ["reversed", vi.receiving.statusReversed],
          ] as const
        ).map(([value, label]) => (
          <Link
            key={value}
            href={hrefWith({
              status: value || undefined,
              search: search || undefined,
            })}
            aria-current={status === value ? "page" : undefined}
            className={`rounded-full border px-3 py-1.5 text-sm font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-brand/40 ${
              status === value
                ? "border-brand/40 bg-brand/10 text-brand"
                : "bg-background text-muted-foreground hover:text-foreground"
            }`}
          >
            {label}
          </Link>
        ))}
      </div>

      <p className="text-sm text-muted-foreground">
        {total} {vi.receiving.listTitle.toLowerCase()}
      </p>

      {receipts.length === 0 ? (
        <EmptyState
          title={vi.receiving.listTitle}
          description={vi.receiving.receiptsEmpty}
        />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.docNo}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.returnPoDocNo}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.supplier}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.status}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.receiving.receivedAt}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase text-right">
                  {vi.procurement.list.lines}
                </th>
              </tr>
            </thead>
            <tbody>
              {receipts.map((receipt) => (
                <tr key={receipt.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 align-middle">
                    {receipt.po_id ? (
                      <Link
                        href={`/${propertyId}/procurement/po/${receipt.po_id}`}
                        className="font-mono text-xs font-bold text-primary hover:underline"
                      >
                        {receipt.doc_no}
                      </Link>
                    ) : (
                      <span className="font-mono text-xs font-bold">
                        {receipt.doc_no}
                      </span>
                    )}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {receipt.po_doc_no ?? "—"}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {receipt.supplier_name}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {statusLabel(receipt.status)}
                  </td>
                  <td className="px-3 py-3 whitespace-nowrap align-middle">
                    {new Date(receipt.received_at).toLocaleDateString("vi-VN")}
                  </td>
                  <td className="px-3 py-3 text-right align-middle">
                    {receipt.line_count}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {totalPages > 1 ? (
        <div className="flex items-center gap-2 text-sm">
          {page > 1 ? (
            <Link
              href={hrefWith({
                status: status || undefined,
                search: search || undefined,
                page: String(page - 1),
              })}
              className="flex h-9 items-center rounded-md border bg-background px-3 font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
            >
              ← {vi.common.back}
            </Link>
          ) : null}
          <span className="text-muted-foreground">
            {page} / {totalPages}
          </span>
          {page < totalPages ? (
            <Link
              href={hrefWith({
                status: status || undefined,
                search: search || undefined,
                page: String(page + 1),
              })}
              className="flex h-9 items-center rounded-md border bg-background px-3 font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
            >
              {vi.common.next} →
            </Link>
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
