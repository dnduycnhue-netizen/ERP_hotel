"use client";

import { useState } from "react";
import { ConfirmPostDialog } from "@/components/common/confirm-post-dialog";
import { Button } from "@/components/ui/button";
import { setActiveAction } from "@/features/admin/actions";
import { vi } from "@/i18n/vi";

/**
 * Khóa / mở khóa tài khoản. Khóa cần xác nhận và lý do (ghi nhật ký);
 * mở khóa là thao tác đảo được nên gọi trực tiếp.
 */
export function LockAccountButton({
  userId,
  active,
  disabled,
}: {
  userId: string;
  active: boolean;
  disabled?: boolean;
}) {
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function apply(nextActive: boolean, lockReason?: string) {
    setWorking(true);
    setError(null);
    setNotice(null);
    const result = await setActiveAction(userId, nextActive, lockReason);
    setWorking(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setNotice(nextActive ? vi.admin.accountUnlocked : vi.admin.accountLocked);
  }

  if (!active) {
    return (
      <div className="flex items-center gap-3">
        <Button
          variant="outline"
          disabled={disabled || working}
          onClick={() => void apply(true)}
        >
          {working ? vi.common.loading : vi.admin.unlockAccount}
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
    );
  }

  return (
    <div className="space-y-2">
      <div className="flex items-center gap-3">
        <Button
          variant="destructive"
          disabled={disabled || working}
          onClick={() => setConfirmOpen(true)}
        >
          {vi.admin.lockAccount}
        </Button>
        {notice ? (
          <p
            role="status"
            className="text-sm text-green-700 dark:text-green-400"
          >
            {notice}
          </p>
        ) : null}
      </div>
      <label className="block max-w-sm space-y-1 text-sm">
        <span className="font-medium">{vi.admin.lockReasonLabel}</span>
        <input
          value={reason}
          onChange={(event) => setReason(event.target.value)}
          placeholder={vi.admin.lockReasonHint}
          className="h-9 w-full rounded-md border bg-background px-3"
        />
      </label>
      {error ? (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      ) : null}
      <ConfirmPostDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        title={vi.admin.lockAccountTitle}
        consequences={[vi.admin.lockAccountWarning]}
        confirmLabel={vi.admin.lockAccount}
        confirming={working}
        onConfirm={() => {
          setConfirmOpen(false);
          void apply(false, reason);
        }}
      />
    </div>
  );
}
