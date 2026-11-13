import Link from "next/link";
import { connection } from "next/server";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { PageHeader } from "@/components/shell/page-header";
import { hasChainPerm } from "@/features/admin";
import {
  listAuditLog,
  type AuditFilters,
  type AuditPage,
} from "@/features/admin/data/audit";
import { vi } from "@/i18n/vi";
import { diffAuditRow } from "@/lib/admin/audit-diff";
import { createClient } from "@/lib/supabase/server";

type Params = {
  table?: string;
  action?: string;
  from?: string;
  to?: string;
  page?: string;
};

const dateTime = new Intl.DateTimeFormat("vi-VN", {
  timeZone: "Asia/Ho_Chi_Minh",
  dateStyle: "short",
  timeStyle: "medium",
});
const YMD = /^\d{4}-\d{2}-\d{2}$/;
const TABLE = /^[a-z0-9_]{1,63}$/;

function parseFilters(p: Params): AuditFilters {
  const page = Number.parseInt(p.page ?? "1", 10);
  return {
    table: p.table && TABLE.test(p.table) ? p.table : undefined,
    action:
      p.action === "INSERT" || p.action === "UPDATE" || p.action === "DELETE"
        ? p.action
        : undefined,
    from: p.from && YMD.test(p.from) ? p.from : undefined,
    to: p.to && YMD.test(p.to) ? p.to : undefined,
    page: Number.isFinite(page) && page >= 1 ? page : 1,
  };
}

function pageHref(f: AuditFilters, page: number): string {
  const q = new URLSearchParams();
  if (f.table) q.set("table", f.table);
  if (f.action) q.set("action", f.action);
  if (f.from) q.set("from", f.from);
  if (f.to) q.set("to", f.to);
  q.set("page", String(page));
  return `/admin/audit?${q.toString()}`;
}

export default async function AuditLogPage({
  searchParams,
}: {
  searchParams: Promise<Params>;
}) {
  await connection();
  const t = vi.admin.audit;
  const filters = parseFilters(await searchParams);
  const supabase = await createClient();

  if (!(await hasChainPerm(supabase, "audit.view_all"))) {
    return (
      <div className="space-y-6">
        <PageHeader title={t.title} />
        <ErrorState
          title={vi.admin.noAccessTitle}
          description={vi.admin.noAccessDescription}
        />
      </div>
    );
  }

  let result: AuditPage;
  try {
    result = await listAuditLog(supabase, filters);
  } catch {
    return (
      <div className="space-y-6">
        <PageHeader title={t.title} />
        <ErrorState title={t.loadError} />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <PageHeader title={t.title} />
      <p className="text-sm text-muted-foreground">{t.description}</p>

      <form method="get" className="flex flex-wrap items-end gap-3">
        <label className="space-y-1 text-sm">
          <span className="block text-muted-foreground">{t.filterTable}</span>
          <input
            name="table"
            defaultValue={filters.table ?? ""}
            placeholder="stock_moves"
            className="h-9 rounded-md border bg-background px-2 font-mono text-xs"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block text-muted-foreground">{t.filterAction}</span>
          <select
            name="action"
            defaultValue={filters.action ?? ""}
            className="h-9 rounded-md border bg-background px-2"
          >
            <option value="">{t.actionAll}</option>
            <option value="INSERT">{t.action.INSERT}</option>
            <option value="UPDATE">{t.action.UPDATE}</option>
            <option value="DELETE">{t.action.DELETE}</option>
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="block text-muted-foreground">{t.filterFrom}</span>
          <input
            type="date"
            name="from"
            defaultValue={filters.from ?? ""}
            className="h-9 rounded-md border bg-background px-2"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="block text-muted-foreground">{t.filterTo}</span>
          <input
            type="date"
            name="to"
            defaultValue={filters.to ?? ""}
            className="h-9 rounded-md border bg-background px-2"
          />
        </label>
        <button
          type="submit"
          className="h-9 rounded-md bg-primary px-4 text-sm text-primary-foreground"
        >
          {t.apply}
        </button>
        <Link
          href="/admin/audit"
          className="h-9 content-center text-sm text-primary hover:underline"
        >
          {t.reset}
        </Link>
      </form>

      {result.rows.length === 0 ? (
        <EmptyState title={t.empty} />
      ) : (
        <div className="overflow-x-auto rounded-lg border">
          <table className="w-full min-w-[720px] text-sm">
            <thead className="bg-muted/50 text-left">
              <tr>
                <th className="p-2">{t.colTime}</th>
                <th className="p-2">{t.colActor}</th>
                <th className="p-2">{t.colAction}</th>
                <th className="p-2">{t.colTable}</th>
                <th className="p-2">{t.colChanges}</th>
              </tr>
            </thead>
            <tbody>
              {result.rows.map((row) => {
                const changes = diffAuditRow(row.old_data, row.new_data);
                return (
                  <tr key={row.id} className="border-t align-top">
                    <td className="whitespace-nowrap p-2">
                      {dateTime.format(new Date(row.at))}
                    </td>
                    <td className="p-2">
                      {row.actor_name ?? (row.actor ? row.actor.slice(0, 8) : t.system)}
                    </td>
                    <td className="p-2">
                      {t.action[row.action as keyof typeof t.action] ?? row.action}
                    </td>
                    <td className="p-2">
                      <span className="font-mono text-xs">{row.table_name}</span>
                      <span className="block font-mono text-xs text-muted-foreground">
                        {row.row_id.slice(0, 36)}
                      </span>
                    </td>
                    <td className="p-2">
                      {changes.length === 0 ? (
                        "—"
                      ) : (
                        <details>
                          <summary className="cursor-pointer text-primary">
                            {t.changeCount.replace("{n}", String(changes.length))}
                          </summary>
                          <ul className="mt-1 space-y-1 text-xs">
                            {changes.map((c) => (
                              <li key={c.field} className="break-all">
                                <span className="font-mono font-medium">{c.field}</span>
                                {": "}
                                <span className="text-muted-foreground">
                                  {c.before ?? "∅"}
                                </span>
                                {" → "}
                                <span>{c.after ?? "∅"}</span>
                              </li>
                            ))}
                          </ul>
                        </details>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      <nav className="flex items-center justify-between text-sm">
        {filters.page > 1 ? (
          <Link
            href={pageHref(filters, filters.page - 1)}
            className="text-primary hover:underline"
          >
            {t.prev}
          </Link>
        ) : (
          <span />
        )}
        <span className="text-muted-foreground">
          {t.pageLabel.replace("{n}", String(filters.page))}
        </span>
        {result.hasMore ? (
          <Link
            href={pageHref(filters, filters.page + 1)}
            className="text-primary hover:underline"
          >
            {t.next}
          </Link>
        ) : (
          <span />
        )}
      </nav>
    </div>
  );
}
