"use client";

import { useState } from "react";
import Link from "next/link";
import { Check, Copy } from "lucide-react";
import { Button } from "@/components/ui/button";
import {
  createUserAction,
  type CreateUserResult,
} from "@/features/admin/actions";
import type { RoleSummary } from "@/features/admin/data/queries";
import { vi } from "@/i18n/vi";

type PresetKey =
  | "purchaser"
  | "approver_receiver"
  | "front_desk"
  | "storekeeper"
  | "housekeeping"
  | "custom";

const PRESET_ROLES: Record<Exclude<PresetKey, "custom">, string[]> = {
  purchaser: ["purchaser"],
  approver_receiver: ["outlet_head", "receiver"],
  front_desk: ["front_desk"],
  storekeeper: ["storekeeper"],
  housekeeping: ["hk_attendant"],
};

const PRESET_LABELS: Record<PresetKey, string> = {
  purchaser: vi.admin.createUserPresetPurchaser,
  approver_receiver: vi.admin.createUserPresetApproverReceiver,
  front_desk: vi.admin.createUserPresetFrontDesk,
  storekeeper: vi.admin.createUserPresetStorekeeper,
  housekeeping: vi.admin.createUserPresetHousekeeping,
  custom: vi.admin.createUserPresetCustom,
};

/**
 * Tạo tài khoản mới trong 1 bước: chọn mẫu vai trò (preset) hoặc tùy
 * chọn nhiều vai trò, chọn phạm vi, đặt hoặc sinh mật khẩu tạm. Gọi Edge
 * Function admin-create-user qua createUserAction. Mật khẩu tạm chỉ hiển
 * thị một lần sau khi tạo xong — không ghi log.
 */
export function CreateUserForm({
  roles,
  properties,
}: {
  roles: RoleSummary[];
  properties: { id: string; name: string }[];
}) {
  const [preset, setPreset] = useState<PresetKey>("purchaser");
  const [employeeCode, setEmployeeCode] = useState("");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [roleIds, setRoleIds] = useState<string[]>(() =>
    roles
      .filter((role) => PRESET_ROLES.purchaser.includes(role.code))
      .map((role) => role.id),
  );
  const [propertyId, setPropertyId] = useState("");
  const [passwordMode, setPasswordMode] = useState<"auto" | "custom">("auto");
  const [password, setPassword] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [created, setCreated] = useState<CreateUserResult | null>(null);
  const [copied, setCopied] = useState(false);

  function applyPreset(next: PresetKey) {
    setPreset(next);
    if (next !== "custom") {
      // Q165: preset chỉ BỔ SUNG vai trò của mẫu, không reset các vai trò
      // đã tick tay trước đó (hợp nhất thay vì thay thế toàn bộ).
      const presetRoleIds = roles
        .filter((role) => PRESET_ROLES[next].includes(role.code))
        .map((role) => role.id);
      setRoleIds((prev) => [...new Set([...prev, ...presetRoleIds])]);
    }
  }

  function toggleRole(roleId: string, checked: boolean) {
    setPreset("custom");
    setRoleIds((prev) =>
      checked ? [...prev, roleId] : prev.filter((id) => id !== roleId),
    );
  }

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    const result = await createUserAction({
      employeeCode,
      fullName,
      email,
      phone,
      password: passwordMode === "custom" ? password : "",
      roleIds,
      propertyId: propertyId === "" ? null : propertyId,
    });
    setSaving(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setCreated(result.data);
  }

  async function handleCopy() {
    if (!created) return;
    await navigator.clipboard.writeText(created.temp_password);
    setCopied(true);
  }

  if (created) {
    return (
      <div className="space-y-4">
        <p role="status" className="text-sm text-green-700 dark:text-green-400">
          {vi.admin.createUserCreated}
        </p>
        <div className="space-y-1 text-sm">
          <span className="font-medium">{vi.admin.createUserLoginEmail}</span>
          <p className="rounded-md border bg-muted px-3 py-2 font-mono break-all">
            {created.login_email}
          </p>
        </div>
        <div className="space-y-1 text-sm">
          <span className="font-medium">{vi.admin.createUserTempPassword}</span>
          <span className="flex items-center gap-2">
            <code className="flex-1 rounded-md border bg-muted px-3 py-2 font-mono break-all">
              {created.temp_password}
            </code>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={handleCopy}
            >
              {copied ? (
                <Check className="size-4" />
              ) : (
                <Copy className="size-4" />
              )}
              {copied ? vi.common.copied : vi.common.copy}
            </Button>
          </span>
        </div>
        <p className="text-sm text-muted-foreground">
          {vi.admin.createUserTempPasswordHint}
        </p>
        <div className="flex flex-wrap gap-2">
          <Link
            href={`/admin/users/${created.user_id}/access`}
            className="inline-flex h-8 items-center justify-center gap-1.5 rounded-lg border border-border bg-background px-2.5 text-sm font-medium whitespace-nowrap hover:bg-muted"
          >
            {vi.admin.createUserViewAccess}
          </Link>
          <Link
            href="/admin/users"
            className="inline-flex h-8 items-center justify-center gap-1.5 rounded-lg border border-border bg-background px-2.5 text-sm font-medium whitespace-nowrap hover:bg-muted"
          >
            {vi.admin.createUserBackToList}
          </Link>
        </div>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <p className="text-sm text-muted-foreground">
        {vi.admin.createUserDescription}
      </p>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">{vi.admin.createUserPreset}</span>
        <select
          value={preset}
          onChange={(event) => applyPreset(event.target.value as PresetKey)}
          className="h-9 w-full rounded-md border bg-background px-3"
        >
          {(Object.keys(PRESET_LABELS) as PresetKey[]).map((key) => (
            <option key={key} value={key}>
              {PRESET_LABELS[key]}
            </option>
          ))}
        </select>
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="block space-y-1 text-sm">
          <span className="font-medium">{vi.admin.createUserEmployeeCode}</span>
          <input
            value={employeeCode}
            onChange={(event) =>
              setEmployeeCode(event.target.value.toUpperCase())
            }
            required
            autoComplete="off"
            className="h-9 w-full rounded-md border bg-background px-3 font-mono uppercase"
          />
        </label>
        <label className="block space-y-1 text-sm">
          <span className="font-medium">{vi.admin.createUserFullName}</span>
          <input
            value={fullName}
            onChange={(event) => setFullName(event.target.value)}
            required
            autoComplete="name"
            className="h-9 w-full rounded-md border bg-background px-3"
          />
        </label>
        <label className="block space-y-1 text-sm">
          <span className="font-medium">{vi.admin.createUserEmail}</span>
          <input
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            autoComplete="email"
            className="h-9 w-full rounded-md border bg-background px-3"
          />
          <span className="block text-xs text-muted-foreground">
            {vi.admin.createUserEmailHint}
          </span>
        </label>
        <label className="block space-y-1 text-sm">
          <span className="font-medium">{vi.admin.createUserPhone}</span>
          <input
            type="tel"
            value={phone}
            onChange={(event) => setPhone(event.target.value)}
            autoComplete="tel"
            className="h-9 w-full rounded-md border bg-background px-3"
          />
        </label>
      </div>
      <fieldset className="space-y-2">
        <legend className="text-sm font-medium">
          {vi.admin.createUserRoles}
        </legend>
        <p className="text-xs text-muted-foreground">
          {vi.admin.createUserRolesHint}
        </p>
        <div className="grid gap-2 sm:grid-cols-2">
          {roles.map((role) => (
            <label
              key={role.id}
              className="flex items-start gap-2 rounded-md border px-3 py-2 text-sm"
            >
              <input
                type="checkbox"
                checked={roleIds.includes(role.id)}
                onChange={(event) => toggleRole(role.id, event.target.checked)}
                className="mt-0.5"
              />
              <span>
                <span className="block font-medium">{role.name_vi}</span>
                <span className="block font-mono text-xs text-muted-foreground">
                  {role.code}
                </span>
              </span>
            </label>
          ))}
        </div>
      </fieldset>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">{vi.admin.createUserProperty}</span>
        <select
          value={propertyId}
          onChange={(event) => setPropertyId(event.target.value)}
          className="h-9 w-full rounded-md border bg-background px-3"
        >
          <option value="">{vi.admin.createUserPropertyChain}</option>
          {properties.map((property) => (
            <option key={property.id} value={property.id}>
              {property.name}
            </option>
          ))}
        </select>
      </label>
      <fieldset className="space-y-2 text-sm">
        <legend className="font-medium">
          {vi.admin.createUserPasswordMode}
        </legend>
        <label className="flex items-center gap-2">
          <input
            type="radio"
            name="password-mode"
            checked={passwordMode === "auto"}
            onChange={() => setPasswordMode("auto")}
          />
          {vi.admin.createUserPasswordAuto}
        </label>
        <label className="flex items-center gap-2">
          <input
            type="radio"
            name="password-mode"
            checked={passwordMode === "custom"}
            onChange={() => setPasswordMode("custom")}
          />
          {vi.admin.createUserPasswordCustom}
        </label>
        {passwordMode === "custom" ? (
          <label className="block space-y-1">
            <span className="font-medium">{vi.admin.createUserPassword}</span>
            <input
              type="text"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              autoComplete="new-password"
              minLength={12}
              required
              className="h-9 w-full rounded-md border bg-background px-3"
            />
            <span className="block text-xs text-muted-foreground">
              {vi.admin.createUserPasswordHint}
            </span>
          </label>
        ) : null}
      </fieldset>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      <Button type="submit" disabled={saving}>
        {saving ? vi.common.loading : vi.admin.createUserSubmit}
      </Button>
    </form>
  );
}
