"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { changeOwnPasswordAction } from "@/features/account/actions";
import { vi } from "@/i18n/vi";

/** Form tự đổi mật khẩu của chính mình (mật khẩu hiện tại + mới + nhập lại). */
export function ChangePasswordForm() {
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSaving(true);
    setError(null);
    setNotice(null);
    const result = await changeOwnPasswordAction({
      currentPassword,
      newPassword,
      confirmPassword,
    });
    setSaving(false);
    if (!result.ok) {
      setError(result.error ?? null);
      return;
    }
    setCurrentPassword("");
    setNewPassword("");
    setConfirmPassword("");
    setNotice(vi.password.passwordChanged);
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <p className="text-sm text-muted-foreground">
        {vi.password.changePasswordDescription}
      </p>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">{vi.password.currentPassword}</span>
        <input
          type="password"
          value={currentPassword}
          onChange={(event) => setCurrentPassword(event.target.value)}
          autoComplete="current-password"
          required
          className="h-9 w-full rounded-md border bg-background px-3"
        />
      </label>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">{vi.password.newPassword}</span>
        <input
          type="password"
          value={newPassword}
          onChange={(event) => setNewPassword(event.target.value)}
          autoComplete="new-password"
          minLength={12}
          required
          className="h-9 w-full rounded-md border bg-background px-3"
        />
        <span className="block text-xs text-muted-foreground">
          {vi.password.passwordTooShort}
        </span>
      </label>
      <label className="block space-y-1 text-sm">
        <span className="font-medium">{vi.password.confirmPassword}</span>
        <input
          type="password"
          value={confirmPassword}
          onChange={(event) => setConfirmPassword(event.target.value)}
          autoComplete="new-password"
          minLength={12}
          required
          className="h-9 w-full rounded-md border bg-background px-3"
        />
      </label>
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
      <Button type="submit" disabled={saving}>
        {saving ? vi.common.loading : vi.password.changePasswordSubmit}
      </Button>
    </form>
  );
}
