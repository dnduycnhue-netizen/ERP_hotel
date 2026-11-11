import { LoaderCircle, type LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

/**
 * Trạng thái trang chuẩn cho màn hình hiện trường `/m` (W1).
 *
 * Mọi màn mobile (W2/W3/W4) dùng 3 component này thay vì tự viết
 * `<p>Đang tải…</p>` / empty / error riêng — để trạng thái đang tải,
 * rỗng, lỗi nhìn giống nhau trên cả 4 màn. Chúng chỉ chuẩn hóa
 * khoảng đệm + cỡ chữ mobile (`py-16`, chữ 16px) trên nền 2 component
 * dùng chung `EmptyState` / `ErrorState` đã có.
 */

/** Trạng thái đang tải: spinner + chữ, có `aria-busy` cho screen reader. */
export function MobileLoadingState({
  label = vi.common.loading,
  className,
}: {
  label?: string;
  className?: string;
}) {
  return (
    <div
      aria-busy="true"
      aria-live="polite"
      role="status"
      className={cn(
        "flex min-h-48 flex-col items-center justify-center gap-3 px-6 py-16 text-center",
        className,
      )}
    >
      <LoaderCircle
        className="size-6 animate-spin text-muted-foreground"
        aria-hidden
      />
      <p className="text-base text-muted-foreground">{label}</p>
    </div>
  );
}

/** Trạng thái rỗng: icon + tiêu đề + mô tả + nút hành động (tùy chọn). */
export function MobileEmptyState({
  icon,
  title,
  description,
  action,
  className,
}: {
  icon?: LucideIcon;
  title?: string;
  description?: string;
  action?: ReactNode;
  className?: string;
}) {
  return (
    <EmptyState
      icon={icon}
      title={title}
      description={description}
      action={action}
      className={cn("py-16", className)}
    />
  );
}

/** Trạng thái lỗi: icon + mô tả + nút thử lại (tùy chọn). */
export function MobileErrorState({
  title,
  description,
  onRetry,
  className,
}: {
  title?: string;
  description?: string;
  onRetry?: () => void;
  className?: string;
}) {
  return (
    <ErrorState
      title={title}
      description={description}
      onRetry={onRetry}
      className={cn("py-16", className)}
    />
  );
}
