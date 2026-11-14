"use client";

import { Dialog } from "@base-ui/react/dialog";
import { TriangleAlert } from "lucide-react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";

/**
 * Hộp xác nhận trước mọi nút ghi sổ (docs/06-UI-UX.md mục 1):
 * nêu rõ hậu quả — chứng từ đã ghi sổ không sửa được, chỉ đảo được.
 */
export function ConfirmPostDialog({
  open,
  onOpenChange,
  title = vi.components.confirmPost.title,
  docNo,
  consequences = [vi.components.confirmPost.defaultConsequence],
  confirmLabel = vi.components.confirmPost.confirmAction,
  onConfirm,
  confirming = false,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title?: string;
  docNo?: string;
  consequences?: string[];
  confirmLabel?: string;
  onConfirm: () => void;
  confirming?: boolean;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 z-[60] bg-black/50" />
        <Dialog.Popup className="fixed z-[61] top-1/2 left-1/2 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-card p-6 shadow-lg">
          <div className="flex items-start gap-3">
            <TriangleAlert
              className="mt-0.5 size-6 shrink-0 text-destructive"
              aria-hidden
            />
            <div>
              <Dialog.Title className="text-lg font-semibold">
                {title}
              </Dialog.Title>
              {docNo ? (
                <p className="mt-1 text-sm text-muted-foreground">
                  {vi.components.confirmPost.documentLabel}: {docNo}
                </p>
              ) : null}
              <Dialog.Description className="mt-2 text-sm leading-6">
                <ul className="list-disc space-y-1 pl-5">
                  {consequences.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </Dialog.Description>
            </div>
          </div>
          <div className="mt-6 flex justify-end gap-2">
            <Dialog.Close
              render={
                <Button variant="outline" disabled={confirming}>
                  {vi.common.cancel}
                </Button>
              }
            />
            <Button
              variant="destructive"
              disabled={confirming}
              onClick={onConfirm}
            >
              {confirming ? vi.common.loading : confirmLabel}
            </Button>
          </div>
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
