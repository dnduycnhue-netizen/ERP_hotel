"use client";

import { useMemo, useState } from "react";
import { Dialog } from "@base-ui/react/dialog";
import { Check, Minus } from "lucide-react";
import { ConfirmPostDialog } from "@/components/common/confirm-post-dialog";
import { EmptyState } from "@/components/common/empty-state";
import { Button } from "@/components/ui/button";
import {
  copyRoleAction,
  deactivateRoleAction,
  saveRoleAction,
} from "@/features/admin/actions";
import type { PermissionRow, RoleSummary } from "@/features/admin/data/queries";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

/**
 * Danh sách vai trò (docs/06-UI-UX.md mục 6.1): tạo mới, sao chép,
 * ngừng dùng và so sánh 2–3 vai trò đặt cạnh nhau.
 */
export function RoleList({
  roles,
  rolePermissions,
  permissions,
  orgId,
  canManage,
}: {
  roles: RoleSummary[];
  rolePermissions: Record<string, string[]>;
  permissions: PermissionRow[];
  orgId: string | null;
  canManage: boolean;
}) {
  const [code, setCode] = useState("");
  const [nameVi, setNameVi] = useState("");
  const [description, setDescription] = useState("");
  const [creating, setCreating] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [formNotice, setFormNotice] = useState<string | null>(null);

  const [copyTarget, setCopyTarget] = useState<RoleSummary | null>(null);
  const [copyName, setCopyName] = useState("");
  const [copying, setCopying] = useState(false);
  const [copyError, setCopyError] = useState<string | null>(null);

  const [deactivateTarget, setDeactivateTarget] = useState<RoleSummary | null>(
    null,
  );
  const [deactivating, setDeactivating] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  const [compareIds, setCompareIds] = useState<string[]>([]);
  const [differentOnly, setDifferentOnly] = useState(false);

  const permissionByCode = useMemo(
    () => new Map(permissions.map((p) => [p.code, p])),
    [permissions],
  );

  const compareRoles = useMemo(
    () => roles.filter((r) => compareIds.includes(r.id)),
    [roles, compareIds],
  );

  const compareRows = useMemo(() => {
    const codes = new Set<string>();
    for (const role of compareRoles) {
      for (const permissionCode of rolePermissions[role.id] ?? []) {
        codes.add(permissionCode);
      }
    }
    const rows = [...codes].map((permissionCode) => ({
      code: permissionCode,
      name: permissionByCode.get(permissionCode)?.name_vi ?? permissionCode,
      module: permissionByCode.get(permissionCode)?.module ?? "",
      granted: compareRoles.map((role) =>
        (rolePermissions[role.id] ?? []).includes(permissionCode),
      ),
    }));
    if (!differentOnly) return rows;
    return rows.filter(
      (row) => !row.granted.every(Boolean) && row.granted.some(Boolean),
    );
  }, [compareRoles, rolePermissions, permissionByCode, differentOnly]);

  function toggleCompare(roleId: string) {
    setCompareIds((prev) => {
      if (prev.includes(roleId)) {
        return prev.filter((id) => id !== roleId);
      }
      if (prev.length >= 3) {
        return prev;
      }
      return [...prev, roleId];
    });
  }

  async function handleCreate(event: React.FormEvent) {
    event.preventDefault();
    if (!orgId) return;
    setCreating(true);
    setFormError(null);
    setFormNotice(null);
    const result = await saveRoleAction({
      orgId,
      code,
      nameVi,
      description: description || undefined,
    });
    setCreating(false);
    if (!result.ok) {
      setFormError(result.error);
      return;
    }
    setCode("");
    setNameVi("");
    setDescription("");
    setFormNotice(vi.admin.roleCreated);
  }

  async function handleCopy() {
    if (!copyTarget) return;
    setCopying(true);
    setCopyError(null);
    const result = await copyRoleAction(copyTarget.id, copyName);
    setCopying(false);
    if (!result.ok) {
      setCopyError(result.error);
      return;
    }
    setCopyTarget(null);
    setCopyName("");
    setFormNotice(vi.admin.roleCopied);
  }

  async function handleDeactivate() {
    if (!deactivateTarget) return;
    setDeactivating(true);
    setActionError(null);
    const result = await deactivateRoleAction(deactivateTarget.id);
    setDeactivating(false);
    if (!result.ok) {
      setActionError(result.error);
      return;
    }
    setDeactivateTarget(null);
    setFormNotice(vi.admin.roleDeactivated);
  }

  if (roles.length === 0) {
    return <EmptyState title={vi.admin.noRoles} />;
  }

  return (
    <div className="space-y-6">
      {canManage && orgId ? (
        <form
          onSubmit={handleCreate}
          className="space-y-3 rounded-lg border bg-card p-4"
        >
          <h2 className="font-semibold">{vi.admin.createRole}</h2>
          <div className="grid gap-3 sm:grid-cols-3">
            <label className="space-y-1 text-sm">
              <span className="font-medium">{vi.admin.roleCode}</span>
              <input
                value={code}
                onChange={(event) => setCode(event.target.value)}
                required
                className="h-9 w-full rounded-md border bg-background px-3"
              />
            </label>
            <label className="space-y-1 text-sm">
              <span className="font-medium">{vi.admin.roleName}</span>
              <input
                value={nameVi}
                onChange={(event) => setNameVi(event.target.value)}
                required
                className="h-9 w-full rounded-md border bg-background px-3"
              />
            </label>
            <label className="space-y-1 text-sm">
              <span className="font-medium">{vi.admin.roleDescription}</span>
              <input
                value={description}
                onChange={(event) => setDescription(event.target.value)}
                className="h-9 w-full rounded-md border bg-background px-3"
              />
            </label>
          </div>
          <div className="flex items-center gap-3">
            <Button type="submit" disabled={creating}>
              {creating ? vi.common.loading : vi.admin.createRole}
            </Button>
            {formError ? (
              <p role="alert" className="text-sm text-destructive">
                {formError}
              </p>
            ) : null}
            {formNotice ? (
              <p
                role="status"
                className="text-sm text-green-700 dark:text-green-400"
              >
                {formNotice}
              </p>
            ) : null}
          </div>
        </form>
      ) : null}

      {actionError ? (
        <p role="alert" className="text-sm text-destructive">
          {actionError}
        </p>
      ) : null}

      <div className="overflow-x-auto rounded-lg border bg-card">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b text-left text-muted-foreground">
              <th className="px-4 py-3 font-medium">{vi.admin.compareRoles}</th>
              <th className="px-4 py-3 font-medium">{vi.admin.roleName}</th>
              <th className="px-4 py-3 font-medium">{vi.admin.roleCode}</th>
              <th className="px-4 py-3 font-medium">
                {vi.admin.permissionCount}
              </th>
              <th className="px-4 py-3 font-medium">{vi.admin.holderCount}</th>
              <th className="px-4 py-3 font-medium">{vi.admin.status}</th>
              <th className="px-4 py-3 font-medium">{vi.common.actions}</th>
            </tr>
          </thead>
          <tbody>
            {roles.map((role) => (
              <tr key={role.id} className="border-b last:border-0">
                <td className="px-4 py-3">
                  <input
                    type="checkbox"
                    checked={compareIds.includes(role.id)}
                    disabled={
                      !compareIds.includes(role.id) && compareIds.length >= 3
                    }
                    onChange={() => toggleCompare(role.id)}
                    aria-label={`${vi.admin.compareRoles}: ${role.name_vi}`}
                    className="size-4 accent-primary"
                  />
                </td>
                <td className="px-4 py-3">
                  <a
                    href={`/admin/roles/${role.id}`}
                    className="font-medium text-primary hover:underline"
                  >
                    {role.name_vi}
                  </a>
                  {role.is_system ? (
                    <span className="ml-2 rounded-full bg-muted px-2 py-0.5 text-xs text-muted-foreground">
                      {vi.admin.systemTemplate}
                    </span>
                  ) : null}
                  {role.description ? (
                    <span className="block text-xs text-muted-foreground">
                      {role.description}
                    </span>
                  ) : null}
                </td>
                <td className="px-4 py-3 font-mono text-xs">{role.code}</td>
                <td className="px-4 py-3">{role.permissionCount}</td>
                <td className="px-4 py-3">{role.holderCount}</td>
                <td className="px-4 py-3">
                  {role.active ? vi.admin.active : vi.admin.inactive}
                </td>
                <td className="px-4 py-3">
                  <div className="flex gap-2">
                    {canManage ? (
                      <>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => {
                            setCopyTarget(role);
                            setCopyName(`${role.name_vi} — bản sao`);
                            setCopyError(null);
                          }}
                        >
                          {vi.admin.copyRole}
                        </Button>
                        {role.active && !role.is_system ? (
                          <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setDeactivateTarget(role)}
                          >
                            {vi.admin.deactivateRole}
                          </Button>
                        ) : null}
                      </>
                    ) : null}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {compareRoles.length >= 2 ? (
        <section className="space-y-3 rounded-lg border bg-card p-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="font-semibold">{vi.admin.compareRoles}</h2>
            <label className="flex cursor-pointer items-center gap-2 text-sm">
              <input
                type="checkbox"
                checked={differentOnly}
                onChange={(event) => setDifferentOnly(event.target.checked)}
                className="size-4 accent-primary"
              />
              {vi.admin.compareDifferentOnly}
            </label>
          </div>
          {compareRows.length === 0 ? (
            <EmptyState title={vi.admin.compareEmpty} />
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left text-muted-foreground">
                    <th className="px-2 py-2 font-medium">
                      {vi.admin.permission}
                    </th>
                    {compareRoles.map((role) => (
                      <th key={role.id} className="px-2 py-2 font-medium">
                        {role.name_vi}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {compareRows.map((row) => (
                    <tr key={row.code} className="border-b last:border-0">
                      <td className="px-2 py-2">
                        <span className="font-medium">{row.name}</span>
                        <span className="block text-xs text-muted-foreground">
                          {row.module} — {row.code}
                        </span>
                      </td>
                      {row.granted.map((isGranted, index) => (
                        <td
                          key={compareRoles[index].id}
                          className={cn(
                            "px-2 py-2 text-center",
                            isGranted
                              ? "text-green-700 dark:text-green-400"
                              : "text-muted-foreground",
                          )}
                        >
                          {isGranted ? (
                            <Check
                              className="mx-auto size-4"
                              aria-label={vi.admin.granted}
                            />
                          ) : (
                            <Minus
                              className="mx-auto size-4"
                              aria-label={vi.admin.notGranted}
                            />
                          )}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      ) : null}

      <Dialog.Root
        open={copyTarget !== null}
        onOpenChange={(open) => {
          if (!open) setCopyTarget(null);
        }}
      >
        <Dialog.Portal>
          <Dialog.Backdrop className="fixed inset-0 bg-black/50" />
          <Dialog.Popup className="fixed top-1/2 left-1/2 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-card p-6 shadow-lg">
            <Dialog.Title className="text-lg font-semibold">
              {vi.admin.copyRoleTitle}
            </Dialog.Title>
            <Dialog.Description className="mt-1 text-sm text-muted-foreground">
              {vi.admin.newRoleNameHint}
            </Dialog.Description>
            <label className="mt-4 block space-y-1 text-sm">
              <span className="font-medium">{vi.admin.copyRoleNameLabel}</span>
              <input
                value={copyName}
                onChange={(event) => setCopyName(event.target.value)}
                className="h-9 w-full rounded-md border bg-background px-3"
              />
            </label>
            {copyError ? (
              <p role="alert" className="mt-2 text-sm text-destructive">
                {copyError}
              </p>
            ) : null}
            <div className="mt-6 flex justify-end gap-2">
              <Dialog.Close
                render={<Button variant="outline">{vi.common.cancel}</Button>}
              />
              <Button disabled={copying} onClick={handleCopy}>
                {copying ? vi.common.loading : vi.admin.copyRole}
              </Button>
            </div>
          </Dialog.Popup>
        </Dialog.Portal>
      </Dialog.Root>

      <ConfirmPostDialog
        open={deactivateTarget !== null}
        onOpenChange={(open) => {
          if (!open) setDeactivateTarget(null);
        }}
        title={vi.admin.deactivateRoleTitle}
        consequences={[vi.admin.deactivateRoleWarning]}
        confirmLabel={vi.admin.deactivateRole}
        confirming={deactivating}
        onConfirm={handleDeactivate}
      />
    </div>
  );
}
