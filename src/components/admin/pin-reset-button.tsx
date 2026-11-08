"use client";

import { useState } from "react";
import { PinDialog } from "@/components/common/pin-dialog";
import { Button } from "@/components/ui/button";
import { setPinAction } from "@/features/admin/actions";
import { vi } from "@/i18n/vi";

/** Đặt lại mã PIN cho người dùng khác (tự sửa bị chặn ở server). */
export function PinResetButton({
  userId,
  disabled,
}: {
  userId: string;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  async function handleSubmit(pin: string) {
    setSubmitting(true);
    setError(null);
    const result = await setPinAction(userId, pin);
    setSubmitting(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setOpen(false);
    setNotice(vi.admin.resetPinDone);
  }

  return (
    <div className="flex items-center gap-3">
      <Button
        variant="outline"
        disabled={disabled}
        onClick={() => {
          setError(null);
          setOpen(true);
        }}
      >
        {vi.admin.resetPin}
      </Button>
      {notice ? (
        <p role="status" className="text-sm text-green-700 dark:text-green-400">
          {notice}
        </p>
      ) : null}
      <PinDialog
        open={open}
        onOpenChange={setOpen}
        title={vi.admin.resetPinTitle}
        description={vi.admin.pinLengthHint}
        length={6}
        error={error}
        submitting={submitting}
        onSubmit={handleSubmit}
      />
    </div>
  );
}
