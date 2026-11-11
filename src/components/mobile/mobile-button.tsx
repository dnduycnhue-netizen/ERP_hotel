import type { ComponentProps } from "react";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

/**
 * Nút bấm chuẩn cho màn hình hiện trường `/m` (W1).
 *
 * `Button` mặc định của repo đã là nút chính đen #171717 (theo
 * ClickUp: CTA đen, tím #7B68EE chỉ làm accent) nhưng các size sẵn
 * (`h-8` / `h-9`) đều thấp hơn touch target tối thiểu 44px. Wrapper
 * này chỉ ép `min-h-11` + chữ 16px; mọi prop khác (`variant`,
 * `disabled`, `onClick`, `type`, …) chuyển thẳng xuống `Button`.
 * Link dạng nút KHÔNG dùng `asChild` (Button không có prop này) —
 * dùng class outline trực tiếp như tiền lệ repo.
 */
export function MobileButton({
  className,
  ...props
}: ComponentProps<typeof Button>) {
  return (
    <Button className={cn("min-h-11 px-5 text-base", className)} {...props} />
  );
}
