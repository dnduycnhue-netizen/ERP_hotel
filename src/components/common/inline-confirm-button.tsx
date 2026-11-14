"use client";

import { useState, type ComponentProps } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";

/**
 * Nút có bước xác nhận NGAY TRÊN TRANG (thay `window.confirm`): bấm lần 1 hiện
 * câu hỏi + "Xác nhận"/"Bỏ qua"; bấm "Xác nhận" mới chạy `onConfirm`.
 * Hộp thoại confirm của trình duyệt bị trình duyệt tự động hủy (B-33, lỗi 8
 * test demo) và khó dùng trên điện thoại.
 */
export function InlineConfirmButton({
  label,
  confirmText,
  onConfirm,
  disabled = false,
  variant,
  size,
  className,
  title,
}: {
  label: string;
  confirmText: string;
  onConfirm: () => void | Promise<void>;
  disabled?: boolean;
  variant?: ComponentProps<typeof Button>["variant"];
  size?: ComponentProps<typeof Button>["size"];
  className?: string;
  title?: string;
}) {
  const [asking, setAsking] = useState(false);

  if (!asking) {
    return (
      <Button
        type="button"
        variant={variant}
        size={size}
        className={className}
        disabled={disabled}
        title={title}
        onClick={() => setAsking(true)}
      >
        {label}
      </Button>
    );
  }
  return (
    <span
      role="alertdialog"
      aria-label={confirmText}
      className="inline-flex flex-wrap items-center gap-2 rounded-md border bg-muted/40 px-2 py-1"
    >
      <span className="text-sm">{confirmText}</span>
      <Button
        type="button"
        size={size}
        className={className}
        disabled={disabled}
        onClick={() => {
          setAsking(false);
          void onConfirm();
        }}
      >
        {vi.common.confirm}
      </Button>
      <Button
        type="button"
        variant="ghost"
        size={size}
        className={className}
        onClick={() => setAsking(false)}
      >
        {vi.inventory.doc.actions.dismiss}
      </Button>
    </span>
  );
}
