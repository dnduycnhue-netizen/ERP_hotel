import Link from "next/link";
import { notFound } from "next/navigation";
import { Check, Minus } from "lucide-react";
import { AssignRoleForm } from "@/components/admin/assign-role-form";
import { LockAccountButton } from "@/components/admin/lock-account-button";
import { OverrideForm } from "@/components/admin/override-form";
import { PinResetButton } from "@/components/admin/pin-reset-button";
import { RevokeAssignmentButton } from "@/components/admin/revoke-assignment-button";
import { EmptyState } from "@/components/common/empty-state";
import { Button } from "@/components/ui/button";
import {
  getEffectivePermissions,
  getUserProfile,
  listPermissions,
  listRoles,
  listUserAssignments,
  listUserOverrides,
} from "@/features/admin";
import { vi } from "@/i18n/vi";
import { listAccessibleProperties } from "@/lib/supabase/access";
import { createClient } from "@/lib/supabase/server";

export default async function UserAccessPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ property?: string }>;
}) {
  const { id: userId } = await params;
  const { property: propertyParam } = await searchParams;
  const supabase = await createClient();
  const { data: callerData } = await supabase.auth.getUser();
  const isSelf = callerData.user?.id === userId;

  const [profile, assignments, overrides, roles, permissions, properties] =
    await Promise.all([
      getUserProfile(supabase, userId),
      listUserAssignments(supabase, userId),
      listUserOverrides(supabase, userId),
      listRoles(supabase),
      listPermissions(supabase),
      listAccessibleProperties(supabase),
    ]);
  if (!profile) {
    notFound();
  }

  const selectedPropertyId =
    propertyParam && properties.some((p) => p.id === propertyParam)
      ? propertyParam
      : (properties[0]?.id ?? null);
  let effective: Awaited<ReturnType<typeof getEffectivePermissions>> = [];
  let effectiveError: string | null = null;
  try {
    effective = await getEffectivePermissions(
      supabase,
      userId,
      selectedPropertyId,
    );
  } catch (error) {
    effectiveError =
      error instanceof Error
        ? error.message
        : vi.components.errorState.defaultDescription;
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
        <p className="mt-1 text-sm text-muted-foreground">
          {profile.employee_code ?? "—"}
          {profile.phone ? ` · ${profile.phone}` : ""} ·{" "}
          {profile.active ? vi.admin.active : vi.admin.locked}
        </p>
        <div className="mt-4 flex flex-wrap items-start gap-4">
          <PinResetButton userId={userId} disabled={isSelf} />
          <LockAccountButton
            userId={userId}
            active={profile.active}
            disabled={isSelf}
          />
        </div>
        {isSelf ? (
          <p role="alert" className="mt-3 text-sm text-muted-foreground">
            {vi.admin.selfEditBlocked}
          </p>
        ) : null}
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
                  <th className="px-4 py-3 font-medium">{vi.common.actions}</th>
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
                    <td className="px-4 py-3">
                      <RevokeAssignmentButton
                        assignmentId={assignment.id}
                        userId={userId}
                        disabled={isSelf}
                      />
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className="rounded-lg border bg-card p-4">
          <AssignRoleForm
            userId={userId}
            roles={roles.filter((role) => role.active)}
            properties={properties}
            isSelf={isSelf}
          />
        </div>
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
        <div className="rounded-lg border bg-card p-4">
          <OverrideForm
            userId={userId}
            permissions={permissions}
            properties={properties}
            isSelf={isSelf}
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">
          {vi.admin.effectivePermissions}
        </h2>
        <p className="text-sm text-muted-foreground">
          {vi.admin.effectivePermissionsDescription}
        </p>
        <form method="get" className="flex flex-wrap items-end gap-2">
          <label className="space-y-1 text-sm">
            <span className="font-medium">{vi.admin.property}</span>
            <select
              name="property"
              defaultValue={selectedPropertyId ?? ""}
              className="h-9 rounded-md border bg-background px-3"
            >
              {properties.map((property) => (
                <option key={property.id} value={property.id}>
                  {property.name}
                </option>
              ))}
            </select>
          </label>
          <Button type="submit" variant="outline">
            {vi.common.search}
          </Button>
        </form>
        {effectiveError ? (
          <p role="alert" className="text-sm text-destructive">
            {effectiveError}
          </p>
        ) : effective.length === 0 ? (
          <EmptyState title={vi.admin.effectiveEmpty} />
        ) : (
          <div className="overflow-x-auto rounded-lg border bg-card">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-left text-muted-foreground">
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.permission}
                  </th>
                  <th className="px-4 py-3 font-medium">{vi.admin.module}</th>
                  <th className="px-4 py-3 font-medium">{vi.admin.granted}</th>
                  <th className="px-4 py-3 font-medium">
                    {vi.admin.effectiveSource}
                  </th>
                  <th className="px-4 py-3 font-medium">{vi.admin.validTo}</th>
                </tr>
              </thead>
              <tbody>
                {effective.map((permission) => (
                  <tr key={permission.code} className="border-b last:border-0">
                    <td className="px-4 py-3">
                      <span className="font-medium">{permission.name_vi}</span>
                      <span className="block font-mono text-xs text-muted-foreground">
                        {permission.code}
                      </span>
                    </td>
                    <td className="px-4 py-3">{permission.module}</td>
                    <td className="px-4 py-3 text-center">
                      {permission.granted ? (
                        <Check
                          className="mx-auto size-4 text-green-700 dark:text-green-400"
                          aria-label={vi.admin.granted}
                        />
                      ) : (
                        <Minus
                          className="mx-auto size-4 text-muted-foreground"
                          aria-label={vi.admin.notGranted}
                        />
                      )}
                    </td>
                    <td className="px-4 py-3">{permission.source ?? "—"}</td>
                    <td className="px-4 py-3">{permission.valid_to ?? "—"}</td>
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
