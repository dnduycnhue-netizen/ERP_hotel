"use client";

import { Dialog } from "@base-ui/react/dialog";
import {
  useRef,
  useState,
  type ChangeEvent,
  type ClipboardEvent,
  type KeyboardEvent,
} from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

function interpolate(
  template: string,
  values: Record<string, string | number>,
): string {
  return Object.entries(values).reduce(
    (text, [key, value]) => text.replace(`{${key}}`, String(value)),
    template,
  );
}

/**
 * Nhập mã PIN để xác nhận thao tác nhạy cảm (ghi sổ nhận hàng, gửi kiểm kê…).
 * PIN không hiển thị dạng rõ và không ghi log — chỉ chuyển chuỗi đã nhập
 * cho màn hình cha gọi RPC; server kiểm tra `pin_hash`.
 */
export function PinDialog({
  open,
  onOpenChange,
  title = vi.components.pinDialog.title,
  description = vi.components.pinDialog.description,
  length = 6,
  minLength,
  error,
  submitting = false,
  onSubmit,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  title?: string;
  description?: string;
  /** Số chữ số của PIN. Mặc định 6. */
  length?: number;
  /**
   * Số chữ số tối thiểu phải nhập (mặc định bằng `length`).
   * PIN nhận hàng dài 4–6 chữ số nên màn T-024 dùng `length={6}`
   * kèm `minLength={4}`: nhập 4 số là đủ gửi, ô còn trống không bắt buộc.
   */
  minLength?: number;
  /** Thông báo lỗi từ server (vd. ERR_PIN_INVALID đã dịch). */
  error?: string | null;
  submitting?: boolean;
  onSubmit: (pin: string) => void;
}) {
  const [digits, setDigits] = useState<string[]>(() => Array(length).fill(""));
  const inputsRef = useRef<Array<HTMLInputElement | null>>([]);

  function handleOpenChange(next: boolean) {
    if (next) {
      setDigits(Array(length).fill(""));
      // Hộp thoại mở lại: đưa con trỏ về ô đầu tiên.
      window.setTimeout(() => inputsRef.current[0]?.focus(), 0);
    }
    onOpenChange(next);
  }

  const effectiveMinLength = Math.min(Math.max(minLength ?? length, 1), length);
  const pin = digits.join("");
  const complete = digits
    .slice(0, effectiveMinLength)
    .every((digit) => digit !== "");

  function setDigit(index: number, value: string) {
    const digit = value.replace(/\D/g, "").slice(-1);
    setDigits((prev) => {
      const next = [...prev];
      next[index] = digit;
      return next;
    });
    if (digit && index < length - 1) {
      inputsRef.current[index + 1]?.focus();
    }
  }

  function handleChange(index: number) {
    return (event: ChangeEvent<HTMLInputElement>) => {
      setDigit(index, event.target.value);
    };
  }

  function handleKeyDown(index: number) {
    return (event: KeyboardEvent<HTMLInputElement>) => {
      if (event.key === "Backspace" && !digits[index] && index > 0) {
        inputsRef.current[index - 1]?.focus();
      }
      if (event.key === "Enter" && complete && !submitting) {
        onSubmit(pin);
      }
    };
  }

  function handlePaste(event: ClipboardEvent<HTMLInputElement>) {
    event.preventDefault();
    const pasted = event.clipboardData
      .getData("text")
      .replace(/\D/g, "")
      .slice(0, length);
    if (pasted.length === 0) {
      return;
    }
    setDigits((prev) => {
      const next = [...prev];
      for (let i = 0; i < pasted.length; i += 1) {
        next[i] = pasted[i];
      }
      return next;
    });
    inputsRef.current[Math.min(pasted.length, length - 1)]?.focus();
  }

  return (
    <Dialog.Root open={open} onOpenChange={handleOpenChange}>
      <Dialog.Portal>
        <Dialog.Backdrop className="fixed inset-0 bg-black/50" />
        <Dialog.Popup className="fixed top-1/2 left-1/2 w-[calc(100vw-2rem)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-xl border bg-card p-6 shadow-lg">
          <Dialog.Title className="text-lg font-semibold">{title}</Dialog.Title>
          <Dialog.Description className="mt-1 text-sm text-muted-foreground">
            {description}
          </Dialog.Description>
          <div className="mt-6 flex justify-center gap-2" dir="ltr">
            {digits.map((digit, index) => (
              <input
                key={index}
                ref={(element) => {
                  inputsRef.current[index] = element;
                }}
                value={digit}
                onChange={handleChange(index)}
                onKeyDown={handleKeyDown(index)}
                onPaste={handlePaste}
                inputMode="numeric"
                autoComplete="one-time-code"
                aria-label={`Chữ số ${index + 1} trên ${length}`}
                maxLength={1}
                disabled={submitting}
                className={cn(
                  "size-11 rounded-lg border bg-background text-center text-lg font-semibold outline-none",
                  "focus:border-ring focus:ring-3 focus:ring-ring/50",
                  error && "border-destructive",
                )}
              />
            ))}
          </div>
          {error ? (
            <p
              role="alert"
              className="mt-3 text-center text-sm text-destructive"
            >
              {error}
            </p>
          ) : null}
          {!complete && !error ? (
            <p className="mt-3 text-center text-sm text-muted-foreground">
              {effectiveMinLength < length
                ? interpolate(vi.components.pinDialog.incompleteMin, {
                    minLength: effectiveMinLength,
                  })
                : interpolate(vi.components.pinDialog.incomplete, { length })}
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
              disabled={!complete || submitting}
              onClick={() => onSubmit(pin)}
            >
              {submitting
                ? vi.common.loading
                : vi.components.pinDialog.confirmAction}
            </Button>
          </div>
        </Dialog.Popup>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
