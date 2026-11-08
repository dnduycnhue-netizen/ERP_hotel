"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { assignRoleAction } from "@/features/admin/actions";
import type { RoleSummary } from "@/features/admin/data/queries";
import { vi } from "@/i18n/vi";

function todayVn(): string {
  return new Date().toLocaleDateString("en-CA", {
    timeZone: "Asia/Ho_Chi_Minh",
  });
}

/**
 * Gán vai trò cho người dùng theo khách sạn, có thời hạn
 * (docs/06-UI-UX.md mục 6.3). Quyền tự sửa bị chặn ở server (ERR_SELF_GRANT).
 */
export function AssignRoleForm({
  userId,
  roles,
  properties,
  isSelf,
}: {
  userId: string;
  roles: RoleSummary[];
  properties: { id: string; name: string }[];
  isSelf: boolean;
}) {
  const [roleId, setRoleId] = useState("");
  const [propertyId, setPropertyId] = useState("");
  const [validFrom, setValidFrom] = useState(todayVn());
  const [validTo, setValidTo] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setNotice(null);
    const result = await assignRoleAction({
      userId,
      roleId,
      propertyId: propertyId === "" ? null : propertyId,
      outletIds: null,
      warehouseIds: null,
      validFrom: validFrom === "" ? null : validFrom,
      validTo: validTo === "" ? null : validTo,
    });
    setSaving(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setRoleId("");
    setPropertyId("");
    setValidTo("");
    setNotice(vi.admin.roleAssigned);
  }

  if (isSelf) {
    return (
      <p role="alert" className="text-sm text-muted-foreground">
        {vi.admin.selfEditBlocked}
      </p>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.admin.selectRole}</span>
          <select
            value={roleId}
            onChange={(event) => setRoleId(event.target.value)}
            required
            className="h-9 w-full rounded-md border bg-background px-3"
          >
            <option value="">—</option>
            {roles.map((role) => (
              <option key={role.id} value={role.id}>
                {role.name_vi} ({role.code})
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.admin.property}</span>
          <select
            value={propertyId}
            onChange={(event) => setPropertyId(event.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3"
          >
            <option value="">{vi.admin.chainWide}</option>
            {properties.map((property) => (
              <option key={property.id} value={property.id}>
                {property.name}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.admin.validFrom}</span>
          <input
            type="date"
            value={validFrom}
            onChange={(event) => setValidFrom(event.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3"
          />
        </label>
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.admin.validTo}</span>
          <input
            type="date"
            value={validTo}
            onChange={(event) => setValidTo(event.target.value)}
            className="h-9 w-full rounded-md border bg-background px-3"
          />
          <span className="block text-xs text-muted-foreground">
            {vi.admin.validToOptional}
          </span>
        </label>
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" disabled={saving}>
          {saving ? vi.common.loading : vi.admin.addAssignment}
        </Button>
        {error ? (
          <p role="alert" className="text-sm text-destructive">
            {error}
          </p>
        ) : null}
        {notice ? (
          <p
            role="status"
            className="text-sm text-green-700 dark:text-green-400"
          >
            {notice}
          </p>
        ) : null}
      </div>
    </form>
  );
}
