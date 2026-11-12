import Link from "next/link";
import { notFound } from "next/navigation";
import { RoleMatrix } from "@/components/admin/role-matrix";
import { EmptyState } from "@/components/common/empty-state";
import { PageHeader } from "@/components/shell/page-header";
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
        <div className="mt-2">
          <PageHeader
            title={role.name_vi}
            description={
              <>
                {role.code}
                {role.description ? ` — ${role.description}` : ""}
                {!role.active ? ` · ${vi.admin.inactive}` : ""}
                {role.is_system ? ` · ${vi.admin.systemTemplate}` : ""}
              </>
            }
          />
        </div>
      </div>

      {!canManage ? (
        <p role="alert" className="text-sm text-muted-foreground">
          {vi.admin.noAccessDescription}
        </p>
      ) : null}

      <section className="space-y-3">
        <h2 className="text-base font-semibold">{vi.admin.matrixTitle}</h2>
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
        <h2 className="text-base font-semibold">{vi.admin.historyTitle}</h2>
        {history.length === 0 ? (
          <EmptyState title={vi.admin.historyEmpty} />
        ) : (
          <div className="overflow-x-auto rounded-lg border bg-card">
            <table className="w-full text-sm">
              <thead className="bg-muted/40 text-left">
                <tr>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.admin.historyAt}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.admin.historyAction}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.admin.historyRow}
                  </th>
                  <th className="px-3 py-2.5 text-[11px] font-semibold tracking-wider whitespace-nowrap text-muted-foreground uppercase">
                    {vi.admin.historyActor}
                  </th>
                </tr>
              </thead>
              <tbody>
                {history.map((entry) => (
                  <tr key={entry.id} className="border-t hover:bg-muted/40">
                    <td className="px-3 py-3 whitespace-nowrap align-middle">
                      {new Date(entry.at).toLocaleString("vi-VN", {
                        timeZone: "Asia/Ho_Chi_Minh",
                      })}
                    </td>
                    <td className="px-3 py-3 align-middle">{entry.action}</td>
                    <td className="px-3 py-3 align-middle font-mono text-xs">
                      {entry.table_name}:{entry.row_id}
                    </td>
                    <td className="px-3 py-3 align-middle font-mono text-xs">
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
