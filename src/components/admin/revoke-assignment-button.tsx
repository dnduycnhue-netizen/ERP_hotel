"use client";

import { useState } from "react";
import { Dialog } from "@base-ui/react/dialog";
import { Button } from "@/components/ui/button";
import { revokeRoleAction } from "@/features/admin/actions";
import { vi } from "@/i18n/vi";

/** Thu hồi một lần gán vai trò — bắt buộc nhập lý do (ghi nhật ký). */
export function RevokeAssignmentButton({
  assignmentId,
  userId,
  disabled,
}: {
  assignmentId: string;
  userId: string;
  disabled?: boolean;
}) {
  const [open, setOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [working, setWorking] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleRevoke() {
    setWorking(true);
    setError(null);
    const result = await revokeRoleAction(assignmentId, reason, userId);
    setWorking(false);
    if (!result.ok) {
      setError(result.error);
      return;
    }
    setOpen(false);
    setReason("");
  }

  return (
    <>
      <Button
        variant="outline"
        size="sm"
        disabled={disabled}
        onClick={() => {
          setError(null);
          setOpen(true);
        }}
      >
        {vi.admin.revoke}
      </Button>
      <Dialog.Root open={open} onOpenChange={setOpen}>
        <Dialog.Portal>
          <Dialog.Backdrop className="fixed inset-0 z-[60] bg-black/50" />
          <Dialog.Popup className="fixed z-[61] top-1/2 left-1/2 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-card p-6 shadow-lg">
            <Dialog.Title className="text-lg font-semibold">
              {vi.admin.revokeTitle}
            </Dialog.Title>
            <Dialog.Description className="mt-1 text-sm text-muted-foreground">
              {vi.admin.revokeReasonHint}
            </Dialog.Description>
            <label className="mt-4 block space-y-1 text-sm">
              <span className="font-medium">{vi.admin.revokeReasonLabel}</span>
              <input
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                className="h-9 w-full rounded-md border bg-background px-3"
              />
            </label>
            {error ? (
              <p role="alert" className="mt-2 text-sm text-destructive">
                {error}
              </p>
            ) : null}
            <div className="mt-6 flex justify-end gap-2">
              <Dialog.Close
                render={<Button variant="outline">{vi.common.cancel}</Button>}
              />
              <Button
                variant="destructive"
                disabled={working || reason.trim() === ""}
                onClick={handleRevoke}
              >
                {working ? vi.common.loading : vi.admin.revoke}
              </Button>
            </div>
          </Dialog.Popup>
        </Dialog.Portal>
      </Dialog.Root>
    </>
  );
}
