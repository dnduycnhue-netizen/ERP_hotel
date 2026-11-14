"use client";

import { useState } from "react";
import { Dialog } from "@base-ui/react/dialog";
import { Check, Copy } from "lucide-react";
import { Button } from "@/components/ui/button";
import { resetUserPasswordAction } from "@/features/admin/actions";
import { vi } from "@/i18n/vi";

/**
 * Đặt lại mật khẩu cho người dùng khác (gọi Edge Function
 * admin-reset-password). Không đặt lại mật khẩu của chính mình bằng
 * đường này — quản trị tự đổi mật khẩu của mình ở màn /settings/password.
 * Mật khẩu tạm chỉ hiển thị một lần, không ghi log.
 */
export function ResetPasswordButton({
  userId,
  disabled,
}: {
  userId: string;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [mode, setMode] = useState<"auto" | "custom">("auto");
  const [password, setPassword] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [tempPassword, setTempPassword] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  function handleOpenChange(next: boolean) {
    if (!next) {
      setMode("auto");
      setPassword("");
      setError(null);
      setTempPassword(null);
      setCopied(false);
    }
    setOpen(next);
  }

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSubmitting(true);
    setError(null);
    const result = await resetUserPasswordAction({
      userId,
      password: mode === "custom" ? password : "",
    });
    setSubmitting(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setTempPassword(result.data.temp_password);
    setPassword("");
  }

  async function handleCopy() {
    if (!tempPassword) return;
    await navigator.clipboard.writeText(tempPassword);
    setCopied(true);
  }

  const customValid = mode === "auto" || password.length >= 12;

  return (
    <div className="flex items-center gap-3">
      <Button
        variant="outline"
        disabled={disabled}
        onClick={() => setOpen(true)}
      >
        {vi.admin.resetPassword}
      </Button>
      <Dialog.Root open={open} onOpenChange={handleOpenChange}>
        <Dialog.Portal>
          <Dialog.Backdrop className="fixed inset-0 z-[60] bg-black/50" />
          <Dialog.Popup className="fixed z-[61] top-1/2 left-1/2 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-card p-6 shadow-lg">
            <Dialog.Title className="text-lg font-semibold">
              {vi.admin.resetPasswordTitle}
            </Dialog.Title>
            <Dialog.Description className="mt-1 text-sm text-muted-foreground">
              {vi.admin.resetPasswordDescription}
            </Dialog.Description>
            {tempPassword ? (
              <div className="mt-6 space-y-3">
                <p
                  role="status"
                  className="text-sm text-green-700 dark:text-green-400"
                >
                  {vi.admin.resetPasswordDone}
                </p>
                <div className="space-y-1 text-sm">
                  <span className="font-medium">
                    {vi.admin.createUserTempPassword}
                  </span>
                  <span className="flex items-center gap-2">
                    <code className="flex-1 rounded-md border bg-muted px-3 py-2 font-mono text-sm break-all">
                      {tempPassword}
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
                  {vi.admin.resetPasswordHint}
                </p>
                <div className="flex justify-end">
                  <Dialog.Close
                    render={
                      <Button variant="outline">{vi.common.close}</Button>
                    }
                  />
                </div>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="mt-6 space-y-4">
                <fieldset className="space-y-2 text-sm">
                  <label className="flex items-center gap-2">
                    <input
                      type="radio"
                      name="password-mode"
                      checked={mode === "auto"}
                      onChange={() => setMode("auto")}
                    />
                    {vi.admin.resetPasswordAuto}
                  </label>
                  <label className="flex items-center gap-2">
                    <input
                      type="radio"
                      name="password-mode"
                      checked={mode === "custom"}
                      onChange={() => setMode("custom")}
                    />
                    {vi.admin.resetPasswordCustom}
                  </label>
                </fieldset>
                {mode === "custom" ? (
                  <label className="block space-y-1 text-sm">
                    <span className="font-medium">
                      {vi.admin.resetPasswordNew}
                    </span>
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
                {error ? (
                  <p role="alert" className="text-sm text-destructive">
                    {error}
                  </p>
                ) : null}
                <div className="flex justify-end gap-2">
                  <Dialog.Close
                    render={
                      <Button variant="outline" disabled={submitting}>
                        {vi.common.cancel}
                      </Button>
                    }
                  />
                  <Button type="submit" disabled={!customValid || submitting}>
                    {submitting ? vi.common.loading : vi.admin.resetPassword}
                  </Button>
                </div>
              </form>
            )}
          </Dialog.Popup>
        </Dialog.Portal>
      </Dialog.Root>
    </div>
  );
}
