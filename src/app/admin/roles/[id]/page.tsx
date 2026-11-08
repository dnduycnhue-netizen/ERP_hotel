import Link from "next/link";
import { notFound } from "next/navigation";
import { RoleMatrix } from "@/components/admin/role-matrix";
import { EmptyState } from "@/components/common/empty-state";
import {
  getRoleDetail,
  getRoleHistory,
  hasChainPerm,
  listPermissions,
  listSodPairs,
} from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

export default async function RoleDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: roleId } = await params;
  const supabase = await createClient();
  const [detail, permissions, sodPairs, history, canManage] = await Promise.all(
    [
      getRoleDetail(supabase, roleId),
      listPermissions(supabase),
      listSodPairs(supabase),
      getRoleHistory(supabase, roleId),
      hasChainPerm(supabase, "admin.roles.manage"),
    ],
  );
  if (!detail) {
    notFound();
  }
  const { role, permissionCodes } = detail;

  return (
    <div className="space-y-6">
      <div>
        <Link
          href="/admin/roles"
          className="text-sm text-muted-foreground hover:underline"
        >
          ← {vi.admin.roles}
        </Link>
        <h1 className="mt-2 text-2xl font-bold tracking-tight">
          {role.name_vi}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {role.code}
          {role.description ? ` — ${role.description}` : ""}
          {!role.active ? ` · ${vi.admin.inactive}` : ""}
          {role.is_system ? ` · ${vi.admin.systemTemplate}` : ""}
        </p>
      </div>

      {!canManage ? (
        <p role="alert" className="text-sm text-muted-foreground">
          {vi.admin.noAccessDescription}
        </p>
      ) : null}

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{vi.admin.matrixTitle}</h2>
        <p className="text-sm text-muted-foreground">
          {vi.admin.matrixDescription}
        </p>
        <RoleMatrix
          roleId={role.id}
          permissions={permissions}
          initialCodes={permissionCodes}
          sodPairs={sodPairs}
          canManage={canManage}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{vi.admin.historyTitle}</h2>
        {history.length === 0 ? (
          <EmptyState title={vi.admin.historyEmpty} />
        ) : (
          <div className="overflow-x-auto rounded-lg border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.historyAt}
                  </th>
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.historyAction}
                  </th>
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.historyRow}
                  </th>
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.historyActor}
                  </th>
                </tr>
              </thead>
              <tbody>
                {history.map((entry) => (
                  <tr key={entry.id} className="border-b last:border-0">
                    <td className="px-4 py-3 whitespace-nowrap">
                      {new Date(entry.at).toLocaleString("vi-VN", {
                        timeZone: "Asia/Ho_Chi_Minh",
                      })}
                    </td>
                    <td className="px-4 py-3">{entry.action}</td>
                    <td className="px-4 py-3 font-mono text-xs">
                      {entry.table_name}:{entry.row_id}
                    </td>
                    <td className="px-4 py-3 font-mono text-xs">
                      {entry.actor ?? "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
