"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { assignRoleAction } from "@/features/admin/actions";
import type { QuickAssignRole } from "@/features/admin/org";
import type { UserRow } from "@/features/admin/data/queries";
import { vi } from "@/i18n/vi";

/**
 * Gán nhanh khi tạo khách sạn (docs/06-UI-UX.md §6.4): một màn hình, mỗi
 * vai trò mẫu một dòng — chọn người rồi bấm Gán. Vai trò nào chưa có
 * người thì cứ để trống, gán sau ở /admin/users. Gán qua
 * assignRoleAction có sẵn (RPC admin_user_assign_role, kiểm tra quyền
 * admin.users.manage + SoD ở tầng RPC).
 */
export function QuickAssignWizard({
  propertyId,
  sodProfile,
  roles,
  users,
}: {
  propertyId: string;
  sodProfile: "with_cc" | "without_cc";
  roles: QuickAssignRole[];
  users: UserRow[];
}) {
  const [selected, setSelected] = useState<Record<string, string>>({});
  const [assigned, setAssigned] = useState<Record<string, string>>({});
  const [savingRoleId, setSavingRoleId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  async function handleAssign(roleId: string) {
    const userId = selected[roleId];
    if (!userId) {
      return;
    }
    setSavingRoleId(roleId);
    setError(null);
    const result = await assignRoleAction({
      userId,
      roleId,
      propertyId,
      outletIds: null,
      warehouseIds: null,
      validFrom: null,
      validTo: null,
    });
    setSavingRoleId(null);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    const user = users.find((candidate) => candidate.id === userId);
    setAssigned((prev) => ({
      ...prev,
      [roleId]: user?.full_name ?? userId,
    }));
  }

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-semibold">{vi.admin.quickAssignTitle}</h2>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.admin.quickAssignDescription}
        </p>
        {sodProfile === "without_cc" ? (
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.admin.quickAssignNoCostController}
          </p>
        ) : null}
      </div>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      <ul className="divide-y rounded-lg border bg-card">
        {roles.map((role) => (
          <li
            key={role.id}
            className="flex flex-wrap items-center gap-3 px-4 py-3"
          >
            <div className="min-w-40 flex-1">
              <p className="text-sm font-medium">{role.name_vi}</p>
              <p className="font-mono text-xs text-muted-foreground">
                {role.code}
              </p>
              {role.description ? (
                <p className="text-xs text-muted-foreground">
                  {role.description}
                </p>
              ) : null}
            </div>
            {assigned[role.id] ? (
              <p className="text-sm text-green-700 dark:text-green-400">
                {vi.admin.quickAssignAssigned}: {assigned[role.id]}
              </p>
            ) : (
              <>
                <select
                  value={selected[role.id] ?? ""}
                  onChange={(event) =>
                    setSelected((prev) => ({
                      ...prev,
                      [role.id]: event.target.value,
                    }))
                  }
                  aria-label={`${role.name_vi} — ${vi.admin.quickAssignSelectUser}`}
                  className="h-9 min-w-52 rounded-md border bg-background px-3 text-sm"
                >
                  <option value="">{vi.admin.quickAssignSelectUser}</option>
                  {users.map((user) => (
                    <option key={user.id} value={user.id}>
                      {user.full_name}
                      {user.employee_code ? ` (${user.employee_code})` : ""}
                    </option>
                  ))}
                </select>
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  disabled={!selected[role.id] || savingRoleId === role.id}
                  onClick={() => handleAssign(role.id)}
                >
                  {savingRoleId === role.id
                    ? vi.common.loading
                    : vi.admin.quickAssignAssign}
                </Button>
              </>
            )}
          </li>
        ))}
      </ul>
      <p className="text-xs text-muted-foreground">
        {vi.admin.quickAssignSkipHint}
      </p>
    </div>
  );
}
