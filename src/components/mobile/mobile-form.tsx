import type { ReactNode } from "react";
import {
  mobileControlClassName,
  mobileLabelClassName,
} from "@/components/mobile/mobile-tokens";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

/**
 * Form control mobile thân thiện (W1).
 *
 * Dùng `<input>` / `<select>` NATIVE bọc trong `<label>` — theo tiền
 * lệ `mobile-new-return-form.tsx`. KHÔNG tạo component input/label/
 * select mới trong `src/components/ui/` (quy tắc nhà: `ui/` chỉ có
 * `button.tsx`). Chữ trong control là 16px để iOS không tự zoom khi
 * focus; control cao 48px (≥ touch target 44px).
 *
 * Cách dùng:
 * ```tsx
 * <MobileField label="Số lượng" hint="Đơn vị: cái" error={err}>
 *   <input type="number" inputMode="decimal" value={v} onChange={...}
 *     className={mobileControlClassName} />
 * </MobileField>
 * ```
 */

export { mobileControlClassName, mobileLabelClassName };

/** Một trường form mobile: nhãn + control native + gợi ý / lỗi. */
export function MobileField({
  label,
  hint,
  error,
  required,
  children,
  className,
}: {
  label: string;
  hint?: string;
  error?: string;
  required?: boolean;
  children: ReactNode;
  className?: string;
}) {
  return (
    <label className={cn(mobileLabelClassName, className)}>
      <span>
        {label}
        {required ? (
          <span
            className="text-destructive"
            aria-label={vi.mobile.fieldRequired}
          >
            {" *"}
          </span>
        ) : null}
      </span>
      {children}
      {error ? (
        <span className="text-xs font-normal text-destructive" role="alert">
          {error}
        </span>
      ) : hint ? (
        <span className="text-xs font-normal text-muted-foreground">
          {hint}
        </span>
      ) : null}
    </label>
  );
}
