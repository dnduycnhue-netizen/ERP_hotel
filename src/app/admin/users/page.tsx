import Link from "next/link";
import { Search } from "lucide-react";
import { EmptyState } from "@/components/common/empty-state";
import { PageHeader } from "@/components/shell/page-header";
import { listUsers, hasChainPerm } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const { q } = await searchParams;
  const supabase = await createClient();
  const [users, canManage] = await Promise.all([
    listUsers(supabase, q?.trim() || undefined),
    hasChainPerm(supabase, "admin.users.manage"),
  ]);

  return (
    <div className="space-y-6">
      <PageHeader
        title={vi.admin.usersTitle}
        description={vi.admin.usersDescription}
        actions={
          canManage ? (
            <Link
              href="/admin/users/new"
              className="inline-flex h-9 items-center justify-center gap-1.5 rounded-lg bg-primary px-4 text-sm font-medium whitespace-nowrap text-primary-foreground"
            >
              {vi.admin.createUser}
            </Link>
          ) : null
        }
      />

      <form method="get" className="flex flex-wrap gap-2">
        <div className="relative w-full max-w-sm flex-1">
          <Search
            className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
            aria-hidden
          />
          <input
            type="search"
            name="q"
            defaultValue={q ?? ""}
            placeholder={vi.admin.searchUser}
            aria-label={vi.admin.searchUser}
            className="h-9 w-full rounded-md border bg-background pr-3 pl-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
          />
        </div>
        <button
          type="submit"
          className="h-9 shrink-0 rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.common.search}
        </button>
      </form>

      {users.length === 0 ? (
        <EmptyState title={vi.admin.noUsers} />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead className="bg-muted/40 text-left">
              <tr className="border-b">
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.admin.fullName}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.admin.employeeCode}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.admin.phone}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.admin.status}
                </th>
                <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                  {vi.common.actions}
                </th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id} className="border-t hover:bg-muted/40">
                  <td className="px-3 py-3 align-middle font-medium">
                    <Link
                      href={`/admin/users/${user.id}`}
                      className="text-primary hover:underline"
                    >
                      {user.full_name}
                    </Link>
                  </td>
                  <td className="px-3 py-3 align-middle font-mono text-xs">
                    {user.employee_code ?? "—"}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {user.phone ?? "—"}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    {user.active ? vi.admin.active : vi.admin.locked}
                  </td>
                  <td className="px-3 py-3 align-middle">
                    <a
                      href={`/admin/users/${user.id}/access`}
                      className="text-primary hover:underline"
                    >
                      {vi.admin.accessTitle}
                    </a>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
