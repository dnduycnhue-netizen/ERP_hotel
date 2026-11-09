import Link from "next/link";
import { vi } from "@/i18n/vi";

/**
 * Chip lọc trạng thái dùng chung cho các danh sách chứng từ kho (T-031).
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
    <div className="flex flex-wrap gap-2">
      {options.map(({ value, label }) => (
        <Link
          key={value}
          href={hrefForStatus(value)}
          aria-current={status === value ? "page" : undefined}
          className={`rounded-lg border px-3 py-1.5 text-sm font-medium ${
            status === value
              ? "bg-primary text-primary-foreground"
              : "bg-card hover:border-ring"
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
          className="rounded-lg border bg-card px-3 py-1.5 hover:border-ring"
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
          className="rounded-lg border bg-card px-3 py-1.5 hover:border-ring"
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
      <input
        type="search"
        name="search"
        defaultValue={defaultValue}
        placeholder={placeholder}
        className="w-full max-w-sm rounded-lg border bg-card px-3 py-1.5 text-sm outline-none focus:border-ring"
      />
      <button
        type="submit"
        className="rounded-lg border bg-card px-3 py-1.5 text-sm font-medium hover:border-ring"
      >
        {vi.common.search}
      </button>
    </form>
  );
}
