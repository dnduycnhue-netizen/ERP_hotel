import Link from "next/link";
import { Search } from "lucide-react";
import { vi } from "@/i18n/vi";

/**
 * Chip lọc trạng thái dùng chung cho các danh sách chứng từ kho (T-031).
 * Kiểu ClickUp (ADR-008): chip đang chọn nền brand nhạt + chữ brand.
 * `hrefForStatus` tự giữ lại các tham số lọc khác (vd. từ khóa tìm kiếm).
 */
export function StatusFilter({
  status,
  options,
  hrefForStatus,
}: {
  status: string;
  options: { value: string; label: string }[];
  hrefForStatus: (status: string) => string;
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      {options.map(({ value, label }) => (
        <Link
          key={value}
          href={hrefForStatus(value)}
          aria-current={status === value ? "page" : undefined}
          className={`rounded-full border px-3 py-1.5 text-sm font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-brand/40 ${
            status === value
              ? "border-brand/40 bg-brand/10 text-brand"
              : "bg-background text-muted-foreground hover:text-foreground"
          }`}
        >
          {label}
        </Link>
      ))}
    </div>
  );
}

/**
 * Phân trang dùng chung cho các danh sách kho (T-031).
 * `hrefForPage` tự giữ lại các tham số lọc hiện tại.
 */
export function DocPagination({
  page,
  totalPages,
  hrefForPage,
}: {
  page: number;
  totalPages: number;
  hrefForPage: (page: number) => string;
}) {
  if (totalPages <= 1) {
    return null;
  }
  return (
    <div className="flex items-center gap-2 text-sm">
      {page > 1 ? (
        <Link
          href={hrefForPage(page - 1)}
          className="flex h-9 items-center rounded-md border bg-background px-3 font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          ← {vi.common.back}
        </Link>
      ) : null}
      <span className="text-muted-foreground">
        {page} / {totalPages}
      </span>
      {page < totalPages ? (
        <Link
          href={hrefForPage(page + 1)}
          className="flex h-9 items-center rounded-md border bg-background px-3 font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
        >
          {vi.common.next} →
        </Link>
      ) : null}
    </div>
  );
}

/**
 * Ô tìm kiếm (GET form) dùng chung cho các danh sách kho (T-031).
 * Giữ lại `status` hiện tại qua input ẩn để không mất bộ lọc.
 */
export function DocSearchForm({
  placeholder,
  defaultValue,
  status,
}: {
  placeholder: string;
  defaultValue: string;
  status?: string;
}) {
  return (
    <form method="get" className="flex gap-2">
      {status ? <input type="hidden" name="status" value={status} /> : null}
      <div className="relative w-full max-w-sm">
        <Search
          className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
          aria-hidden
        />
        <input
          type="search"
          name="search"
          defaultValue={defaultValue}
          placeholder={placeholder}
          aria-label={placeholder}
          className="h-9 w-full rounded-md border bg-background pr-3 pl-9 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
        />
      </div>
      <button
        type="submit"
        className="h-9 shrink-0 rounded-md border bg-background px-3 text-sm font-medium outline-none transition-colors hover:bg-accent focus-visible:ring-2 focus-visible:ring-brand/40"
      >
        {vi.common.search}
      </button>
    </form>
  );
}
