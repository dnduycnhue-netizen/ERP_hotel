import Link from "next/link";
import { notFound } from "next/navigation";
import { EmptyState } from "@/components/common/empty-state";
import {
  getUserProfile,
  listUserAssignments,
  listUserOverrides,
} from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/**
 * Chi tiet tai khoan (C6): ho so + vai tro theo khach san + quyen rieng.
 * Chi xem — sua quyen lam o `/admin/users/[id]/access`.
 * Quyen vao khu admin da chan o `AdminLayout` (`admin.users.manage`).
 */
export default async function UserDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id: userId } = await params;
  const supabase = await createClient();

  const [profile, assignments, overrides] = await Promise.all([
    getUserProfile(supabase, userId),
    listUserAssignments(supabase, userId),
    listUserOverrides(supabase, userId),
  ]);
  if (!profile) {
    notFound();
  }

  return (
    <div className="space-y-8">
      <div>
        <Link
          href="/admin/users"
          className="text-sm text-muted-foreground hover:underline"
        >
          ← {vi.admin.users}
        </Link>
        <h1 className="mt-2 text-2xl font-bold tracking-tight">
          {profile.full_name}
        </h1>
        <dl className="mt-3 grid max-w-2xl grid-cols-2 gap-x-6 gap-y-2 rounded-lg border bg-card p-4 text-sm sm:grid-cols-3">
          <div>
            <dt className="text-muted-foreground">{vi.admin.employeeCode}</dt>
            <dd className="font-mono text-xs font-medium">
              {profile.employee_code ?? "—"}
            </dd>
          </div>
          <div>
            <dt className="text-muted-foreground">{vi.admin.phone}</dt>
            <dd className="font-medium">{profile.phone ?? "—"}</dd>
          </div>
          <div>
            <dt className="text-muted-foreground">{vi.admin.status}</dt>
            <dd className="font-medium">
              {profile.active ? vi.admin.active : vi.admin.locked}
            </dd>
          </div>
          <div>
            <dt className="text-muted-foreground">{vi.admin.userCreatedAt}</dt>
            <dd className="font-medium">
              {new Date(profile.created_at).toLocaleDateString("vi-VN")}
            </dd>
          </div>
        </dl>
        <div className="mt-4">
          <Link
            href={`/admin/users/${userId}/access`}
            className="inline-flex h-9 items-center rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            {vi.admin.manageAccess}
          </Link>
        </div>
      </div>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">{vi.admin.assignedRoles}</h2>
        {assignments.length === 0 ? (
          <EmptyState title={vi.admin.assignedRolesEmpty} />
        ) : (
          <div className="overflow-x-auto rounded-lg border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-4 py-3 font-medium">{vi.admin.roleName}</th>
                  <th className="px-4 py-3 font-medium">{vi.admin.property}</th>
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.validFrom}
                  </th>
                  <th className="px-4 py-3 font-medium">{vi.admin.validTo}</th>
                </tr>
              </thead>
              <tbody>
                {assignments.map((assignment) => (
                  <tr key={assignment.id} className="border-b last:border-0">
                    <td className="px-4 py-3">
                      <span className="font-medium">
                        {assignment.role_name}
                      </span>
                      <span className="block font-mono text-xs text-muted-foreground">
                        {assignment.role_code}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {assignment.property_name ?? vi.admin.chainWide}
                    </td>
                    <td className="px-4 py-3">{assignment.valid_from}</td>
                    <td className="px-4 py-3">{assignment.valid_to ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">
          {vi.admin.individualPermissions}
        </h2>
        {overrides.length === 0 ? (
          <EmptyState title={vi.admin.individualPermissionsEmpty} />
        ) : (
          <div className="overflow-x-auto rounded-lg border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.permission}
                  </th>
                  <th className="px-4 py-3 font-medium">{vi.admin.property}</th>
                  <th className="px-4 py-3 font-medium">{vi.admin.effect}</th>
                  <th className="px-4 py-3 font-medium">{vi.admin.validTo}</th>
                  <th className="px-4 py-3 font-medium">{vi.admin.reason}</th>
                </tr>
              </thead>
              <tbody>
                {overrides.map((override) => (
                  <tr key={override.id} className="border-b last:border-0">
                    <td className="px-4 py-3">
                      <span className="font-medium">
                        {override.permission_name}
                      </span>
                      <span className="block font-mono text-xs text-muted-foreground">
                        {override.permission_code}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      {override.property_name ?? vi.admin.chainWide}
                    </td>
                    <td className="px-4 py-3">
                      {override.effect === "allow"
                        ? vi.admin.effectAllow
                        : vi.admin.effectDeny}
                    </td>
                    <td className="px-4 py-3">{override.valid_to ?? "—"}</td>
                    <td className="px-4 py-3">{override.reason}</td>
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
