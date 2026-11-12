"use client";

import { Delete } from "lucide-react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import { vi } from "@/i18n/vi";

/**
 * Bàn phím số lớn cho màn hình hiện trường (docs/06-UI-UX.md mục 4):
 * thao tác một tay, nút to, chữ to. Giá trị là chuỗi để không mất số 0
 * thập phân lúc đang nhập ("10." vẫn là "10.").
 *
 * - Lưới 3×4 cố định: 1–9, ".", "0", xóa một chữ số.
 * - Phím "±" (đổi dấu, vd. nhiệt độ âm) và "Xóa hết" là hai hàng riêng
 *   phía trên/dưới lưới để bố cục không lệch.
 * - Không dùng `input type="number"` của trình duyệt: bàn phím ảo của
 *   điện thoại che nửa màn hình và không đồng nhất giữa các máy.
 */
export function NumPad({
  value,
  onChange,
  disabled = false,
  allowDecimal = true,
  allowNegative = false,
  label,
}: {
  value: string;
  onChange: (value: string) => void;
  disabled?: boolean;
  allowDecimal?: boolean;
  allowNegative?: boolean;
  /** Nhãn đọc cho trình đọc màn hình. */
  label?: string;
}) {
  function pressDigit(digit: string) {
    if (disabled) {
      return;
    }
    if (value.replace("-", "").replace(".", "").length >= 12) {
      return;
    }
    if (value === "0") {
      onChange(digit);
      return;
    }
    if (value === "-0") {
      onChange(`-${digit}`);
      return;
    }
    onChange(`${value}${digit}`);
  }

  function pressDecimal() {
    if (disabled || !allowDecimal || value.includes(".")) {
      return;
    }
    if (value === "" || value === "-") {
      onChange(`${value}0.`);
      return;
    }
    onChange(`${value}.`);
  }

  function pressSign() {
    if (disabled || !allowNegative) {
      return;
    }
    onChange(value.startsWith("-") ? value.slice(1) : `-${value}`);
  }

  function pressBackspace() {
    if (disabled) {
      return;
    }
    const next = value.slice(0, -1);
    onChange(next === "-" ? "" : next);
  }

  function pressClear() {
    if (!disabled) {
      onChange("");
    }
  }

  const keyClass = "h-14 text-xl font-semibold touch-manipulation select-none";

  return (
    <div className="flex flex-col gap-2">
      {allowNegative ? (
        <Button
          type="button"
          variant="outline"
          disabled={disabled}
          onClick={pressSign}
          className="h-10 touch-manipulation select-none"
          aria-label={vi.components.numPad.toggleSign}
        >
          {vi.components.numPad.toggleSignLabel}
        </Button>
      ) : null}
      <div
        role="group"
        aria-label={label ?? vi.components.numPad.keyboardLabel}
        className="grid grid-cols-3 gap-2"
      >
        {["1", "2", "3", "4", "5", "6", "7", "8", "9"].map((digit) => (
          <Button
            key={digit}
            type="button"
            variant="outline"
            disabled={disabled}
            onClick={() => pressDigit(digit)}
            className={keyClass}
            aria-label={vi.components.numPad.digit.replace("{digit}", String(digit))}
          >
            {digit}
          </Button>
        ))}
        <Button
          type="button"
          variant="outline"
          disabled={disabled || !allowDecimal}
          onClick={pressDecimal}
          className={keyClass}
          aria-label={vi.components.numPad.decimalPoint}
        >
          .
        </Button>
        <Button
          type="button"
          variant="outline"
          disabled={disabled}
          onClick={() => pressDigit("0")}
          className={keyClass}
          aria-label={vi.components.numPad.zero}
        >
          0
        </Button>
        <Button
          type="button"
          variant="outline"
          disabled={disabled}
          onClick={pressBackspace}
          className={keyClass}
          aria-label={vi.components.numPad.backspace}
        >
          <Delete className="size-6" aria-hidden />
        </Button>
      </div>
      <Button
        type="button"
        variant="ghost"
        disabled={disabled}
        onClick={pressClear}
        className={cn(
          "h-10 touch-manipulation select-none",
          "text-muted-foreground",
        )}
        aria-label={vi.components.numPad.clearAll}
      >
        {vi.components.numPad.clearAll}
      </Button>
    </div>
  );
}
