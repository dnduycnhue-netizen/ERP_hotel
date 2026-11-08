"use client";

import { useMemo, useState } from "react";
import { TriangleAlert } from "lucide-react";
import { ConfirmPostDialog } from "@/components/common/confirm-post-dialog";
import { EmptyState } from "@/components/common/empty-state";
import { Button } from "@/components/ui/button";
import { setRolePermissionsAction } from "@/features/admin/actions";
import type { PermissionRow } from "@/features/admin/data/queries";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

function riskBadgeClass(risk: PermissionRow["risk_level"]): string {
  switch (risk) {
    case "critical":
      return "bg-destructive/10 text-destructive";
    case "sensitive":
      return "bg-amber-500/10 text-amber-700 dark:text-amber-400";
    default:
      return "bg-muted text-muted-foreground";
  }
}

function riskLabel(risk: PermissionRow["risk_level"]): string {
  switch (risk) {
    case "critical":
      return vi.admin.riskCritical;
    case "sensitive":
      return vi.admin.riskSensitive;
    default:
      return vi.admin.riskNormal;
  }
}

/**
 * Ma trận quyền tích chọn theo nhóm (docs/06-UI-UX.md mục 6.2):
 * tìm kiếm, thu gọn theo nhóm, chọn tất cả trong nhóm, cảnh báo xung đột
 * tách biệt nhiệm vụ, xác nhận khi đụng quyền mức quan trọng.
 */
export function RoleMatrix({
  roleId,
  permissions,
  initialCodes,
  sodPairs,
  canManage,
}: {
  roleId: string;
  permissions: PermissionRow[];
  initialCodes: string[];
  sodPairs: [string, string][];
  canManage: boolean;
}) {
  const [selected, setSelected] = useState<ReadonlySet<string>>(
    () => new Set(initialCodes),
  );
  const [baseline, setBaseline] = useState<ReadonlySet<string>>(
    () => new Set(initialCodes),
  );
  const [query, setQuery] = useState("");
  const [saving, setSaving] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [savedConflicts, setSavedConflicts] = useState<
    { permission_a: string; permission_b: string }[]
  >([]);

  const permissionByCode = useMemo(
    () => new Map(permissions.map((p) => [p.code, p])),
    [permissions],
  );

  const groups = useMemo(() => {
    const needle = query.trim().toLowerCase();
    const filtered = permissions.filter(
      (p) =>
        needle === "" ||
        p.name_vi.toLowerCase().includes(needle) ||
        p.code.toLowerCase().includes(needle),
    );
    const byModule = new Map<string, PermissionRow[]>();
    for (const permission of filtered) {
      const list = byModule.get(permission.module) ?? [];
      list.push(permission);
      byModule.set(permission.module, list);
    }
    return [...byModule.entries()];
  }, [permissions, query]);

  const conflicts = useMemo(
    () => sodPairs.filter(([a, b]) => selected.has(a) && selected.has(b)),
    [selected, sodPairs],
  );

  const dirty = useMemo(() => {
    if (selected.size !== baseline.size) return true;
    for (const code of selected) {
      if (!baseline.has(code)) return true;
    }
    return false;
  }, [selected, baseline]);

  const touchesCritical = useMemo(() => {
    for (const code of selected) {
      if (
        !baseline.has(code) &&
        permissionByCode.get(code)?.risk_level === "critical"
      ) {
        return true;
      }
    }
    for (const code of baseline) {
      if (
        !selected.has(code) &&
        permissionByCode.get(code)?.risk_level === "critical"
      ) {
        return true;
      }
    }
    return false;
  }, [selected, baseline, permissionByCode]);

  function toggle(code: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(code)) {
        next.delete(code);
      } else {
        next.add(code);
      }
      return next;
    });
    setNotice(null);
  }

  function toggleModule(codes: string[], checked: boolean) {
    setSelected((prev) => {
      const next = new Set(prev);
      for (const code of codes) {
        if (checked) {
          next.add(code);
        } else {
          next.delete(code);
        }
      }
      return next;
    });
    setNotice(null);
  }

  async function save() {
    setSaving(true);
    setError(null);
    setNotice(null);
    const result = await setRolePermissionsAction(roleId, [...selected]);
    setSaving(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setBaseline(new Set(selected));
    setSavedConflicts(result.data.conflicts);
    setNotice(vi.admin.permissionsSaved);
  }

  function handleSaveClick() {
    if (touchesCritical) {
      setConfirmOpen(true);
      return;
    }
    void save();
  }

  return (
    <div className="space-y-4">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <input
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={vi.admin.searchPermission}
          aria-label={vi.admin.searchPermission}
          className="h-9 w-full max-w-sm rounded-md border bg-background px-3 text-sm"
        />
        <Button
          disabled={!dirty || saving || !canManage}
          onClick={handleSaveClick}
        >
          {saving ? vi.common.loading : vi.admin.savePermissions}
        </Button>
      </div>

      {conflicts.length > 0 ? (
        <div
          role="alert"
          className="flex items-start gap-3 rounded-lg border border-amber-500/40 bg-amber-500/10 p-4"
        >
          <TriangleAlert
            className="mt-0.5 size-5 shrink-0 text-amber-600"
            aria-hidden
          />
          <div className="text-sm">
            <p className="font-semibold">{vi.admin.conflictWarningTitle}</p>
            <p className="mt-1 text-muted-foreground">
              {vi.admin.conflictWarningDescription}
            </p>
            <ul className="mt-2 list-disc pl-5">
              {conflicts.map(([a, b]) => (
                <li key={`${a}+${b}`}>
                  {permissionByCode.get(a)?.name_vi ?? a} +{" "}
                  {permissionByCode.get(b)?.name_vi ?? b}
                </li>
              ))}
            </ul>
          </div>
        </div>
      ) : null}

      {groups.length === 0 ? (
        <EmptyState title={vi.admin.matrixEmpty} />
      ) : (
        groups.map(([moduleName, modulePermissions]) => {
          const allChecked = modulePermissions.every((p) =>
            selected.has(p.code),
          );
          const someChecked = modulePermissions.some((p) =>
            selected.has(p.code),
          );
          return (
            <details
              key={moduleName}
              open
              className="rounded-lg border bg-card"
            >
              <summary className="flex cursor-pointer items-center gap-3 px-4 py-3">
                <input
                  type="checkbox"
                  checked={allChecked}
                  ref={(element) => {
                    if (element) {
                      element.indeterminate = !allChecked && someChecked;
                    }
                  }}
                  onChange={(event) => {
                    event.stopPropagation();
                    toggleModule(
                      modulePermissions.map((p) => p.code),
                      event.target.checked,
                    );
                  }}
                  onClick={(event) => event.stopPropagation()}
                  aria-label={`${vi.admin.module} ${moduleName}`}
                  className="size-4 accent-primary"
                />
                <span className="font-semibold">{moduleName}</span>
                <span className="text-sm text-muted-foreground">
                  {modulePermissions.filter((p) => selected.has(p.code)).length}
                  /{modulePermissions.length}
                </span>
              </summary>
              <ul className="divide-y border-t">
                {modulePermissions.map((permission) => (
                  <li key={permission.code} className="px-4 py-2">
                    <label className="flex cursor-pointer items-start gap-3">
                      <input
                        type="checkbox"
                        checked={selected.has(permission.code)}
                        onChange={() => toggle(permission.code)}
                        className="mt-1 size-4 accent-primary"
                      />
                      <span className="min-w-0 flex-1">
                        <span className="block text-sm font-medium">
                          {permission.name_vi}
                        </span>
                        <span className="block truncate text-xs text-muted-foreground">
                          {permission.code}
                          {permission.description_vi
                            ? ` — ${permission.description_vi}`
                            : ""}
                        </span>
                      </span>
                      <span
                        className={cn(
                          "shrink-0 rounded-full px-2 py-0.5 text-xs font-medium",
                          riskBadgeClass(permission.risk_level),
                        )}
                      >
                        {riskLabel(permission.risk_level)}
                      </span>
                    </label>
                  </li>
                ))}
              </ul>
            </details>
          );
        })
      )}

      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      {notice ? (
        <p role="status" className="text-sm text-green-700 dark:text-green-400">
          {notice}
        </p>
      ) : null}
      {savedConflicts.length > 0 ? (
        <p role="alert" className="text-sm text-amber-700 dark:text-amber-400">
          {vi.admin.conflictWarningTitle}:{" "}
          {savedConflicts
            .map((c) => `${c.permission_a} + ${c.permission_b}`)
            .join("; ")}
        </p>
      ) : null}

      <ConfirmPostDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title={vi.admin.criticalChangeTitle}
        consequences={[vi.admin.criticalChangeWarning]}
        confirmLabel={vi.admin.savePermissions}
        confirming={saving}
        onConfirm={() => {
          setConfirmOpen(false);
          void save();
        }}
      />
    </div>
  );
}
