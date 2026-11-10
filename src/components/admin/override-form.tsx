"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { setOverrideAction } from "@/features/admin/actions";
import type { PermissionRow } from "@/features/admin/data/queries";
import { vi } from "@/i18n/vi";

/**
 * Thêm quyền riêng cho/chặn (docs/06-UI-UX.md mục 6.3). Từ admin-relax:
 * quản trị được tự cấp quyền riêng cho chính mình (ERR_SELF_GRANT ở
 * admin_permission_override_set đã gỡ).
 */
export function OverrideForm({
  userId,
  permissions,
  properties,
}: {
  userId: string;
  permissions: PermissionRow[];
  properties: { id: string; name: string }[];
}) {
  const [permissionCode, setPermissionCode] = useState("");
  const [propertyId, setPropertyId] = useState("");
  const [effect, setEffect] = useState<"allow" | "deny">("allow");
  const [validTo, setValidTo] = useState("");
  const [reason, setReason] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setNotice(null);
    const result = await setOverrideAction({
      userId,
      propertyId: propertyId === "" ? null : propertyId,
      permissionCode,
      effect,
      validTo: validTo === "" ? null : validTo,
      reason,
    });
    setSaving(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setPermissionCode("");
    setPropertyId("");
    setValidTo("");
    setReason("");
    setNotice(vi.admin.overrideAdded);
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="space-y-1 text-sm">
          <span className="font-medium">{vi.admin.selectPermission}</span>
          <select
            value={permissionCode}
            onChange={(event) => setPermissionCode(event.target.value)}
            required
            className="h-9 w-full rounded-md border bg-background px-3"
          >
            <option value="">—</option>
            {permissions.map((permission) => (
              <option key={permission.code} value={permission.code}>
                {permission.module} — {permission.name_vi}
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
        <fieldset className="space-y-1 text-sm">
          <legend className="font-medium">{vi.admin.effect}</legend>
          <div className="flex gap-4 pt-1">
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="effect"
                checked={effect === "allow"}
                onChange={() => setEffect("allow")}
                className="size-4 accent-primary"
              />
              {vi.admin.effectAllow}
            </label>
            <label className="flex items-center gap-2">
              <input
                type="radio"
                name="effect"
                checked={effect === "deny"}
                onChange={() => setEffect("deny")}
                className="size-4 accent-primary"
              />
              {vi.admin.effectDeny}
            </label>
          </div>
        </fieldset>
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
        <label className="space-y-1 text-sm sm:col-span-2">
          <span className="font-medium">{vi.admin.reason}</span>
          <input
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            required
            className="h-9 w-full rounded-md border bg-background px-3"
          />
        </label>
      </div>
      <div className="flex items-center gap-3">
        <Button type="submit" disabled={saving}>
          {saving ? vi.common.loading : vi.admin.addOverride}
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
