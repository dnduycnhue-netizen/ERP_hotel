"use client";

import { Dialog } from "@base-ui/react/dialog";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { submitCountAction } from "@/features/count/actions";
import { vi } from "@/i18n/vi";
import { interpolate } from "./count-utils";

/**
 * Nộp đợt kiểm kê (T-033): 1 PIN cho mỗi người đếm, khớp không phụ thuộc
 * thứ tự (server kiểm theo từng user — docs/09-API-RPC.md §5, D5).
 * Submit chỉ chạy online (PIN của nhiều người không xếp hàng offline).
 */
export function CountSubmitDialog({
  open,
  onOpenChange,
  countId,
  docNo,
  counterCount,
  onSubmitted,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  countId: string;
  docNo: string;
  counterCount: number;
  onSubmitted: (result: {
    recountLineIds: string[];
    redLineIds: string[];
  }) => void;
}) {
  const [pins, setPins] = useState<string[]>(() =>
    Array(counterCount).fill(""),
  );
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const valid = pins.every((pin) => /^\d{4,6}$/.test(pin));

  function close(): void {
    if (submitting) {
      return;
    }
    onOpenChange(false);
  }

  async function handleSubmit(): Promise<void> {
    if (!valid || submitting) {
      return;
    }
    setSubmitting(true);
    setError(null);
    const res = await submitCountAction({ countId, pins });
    setSubmitting(false);
    if (!res.ok) {
      setError(res.error);
      return;
    }
    setPins(Array(counterCount).fill(""));
    onOpenChange(false);
    onSubmitted({
      recountLineIds: res.data.recount_line_ids,
      redLineIds: res.data.red_line_ids,
    });
  }

  return (
    <Dialog.Root open={open} onOpenChange={close}>
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 bg-black/50" />
        <Dialog.Popup className="fixed top-1/2 left-1/2 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-card p-6 shadow-lg">
          <Dialog.Title className="text-lg font-semibold">
            {vi.count.submitTitle}
          </Dialog.Title>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.count.docNo}: {docNo}
          </p>
          <Dialog.Description className="mt-2 text-sm leading-6 text-muted-foreground">
            {vi.count.submitHint}
          </Dialog.Description>
          <div className="mt-4 flex flex-col gap-3">
            {pins.map((pin, index) => (
              <label
                key={index}
                className="flex flex-col gap-1.5 text-sm font-medium"
              >
                {interpolate(vi.count.counterPin, { index: index + 1 })}
                <input
                  type="password"
                  inputMode="numeric"
                  autoComplete="off"
                  maxLength={6}
                  value={pin}
                  onChange={(event) =>
                    setPins((prev) =>
                      prev.map((p, i) =>
                        i === index ? event.target.value.replace(/\D/g, "") : p,
                      ),
                    )
                  }
                  disabled={submitting}
                  className="h-12 rounded-lg border bg-background px-3 text-base tracking-[0.3em] outline-none focus:border-ring"
                />
              </label>
            ))}
          </div>
          {error ? (
            <p role="alert" className="mt-3 text-sm text-destructive">
              {error}
            </p>
          ) : null}
          <div className="mt-6 flex justify-end gap-2">
            <Dialog.Close
              render={
                <Button variant="outline" disabled={submitting}>
                  {vi.common.cancel}
                </Button>
              }
            />
            <Button
              disabled={!valid || submitting}
              onClick={() => void handleSubmit()}
            >
              {submitting ? vi.count.submitting : vi.count.submitButton}
            </Button>
          </div>
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
