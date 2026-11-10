import Link from "next/link";
import { EmptyState } from "@/components/common/empty-state";
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
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">
            {vi.admin.usersTitle}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.admin.usersDescription}
          </p>
        </div>
        {canManage ? (
          <Link
            href="/admin/users/new"
            className="inline-flex h-9 items-center justify-center gap-1.5 rounded-lg bg-primary px-4 text-sm font-medium whitespace-nowrap text-primary-foreground"
          >
            {vi.admin.createUser}
          </Link>
        ) : null}
      </div>

      <form method="get" className="flex gap-2">
        <input
          type="search"
          name="q"
          defaultValue={q ?? ""}
          placeholder={vi.admin.searchUser}
          aria-label={vi.admin.searchUser}
          className="h-9 w-full max-w-sm rounded-md border bg-background px-3 text-sm"
        />
        <button
          type="submit"
          className="h-9 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground"
        >
          {vi.common.search}
        </button>
      </form>

      {users.length === 0 ? (
        <EmptyState title={vi.admin.noUsers} />
      ) : (
        <div className="overflow-x-auto rounded-lg border bg-card">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-left text-muted-foreground">
                <th className="px-4 py-3 font-medium">{vi.admin.fullName}</th>
                <th className="px-4 py-3 font-medium">
                  {vi.admin.employeeCode}
                </th>
                <th className="px-4 py-3 font-medium">{vi.admin.phone}</th>
                <th className="px-4 py-3 font-medium">{vi.admin.status}</th>
                <th className="px-4 py-3 font-medium">{vi.common.actions}</th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr key={user.id} className="border-b last:border-0">
                  <td className="px-4 py-3 font-medium">
                    <Link
                      href={`/admin/users/${user.id}`}
                      className="text-primary hover:underline"
                    >
                      {user.full_name}
                    </Link>
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">
                    {user.employee_code ?? "—"}
                  </td>
                  <td className="px-4 py-3">{user.phone ?? "—"}</td>
                  <td className="px-4 py-3">
                    {user.active ? vi.admin.active : vi.admin.locked}
                  </td>
                  <td className="px-4 py-3">
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
