"use client";

import type { ReactNode } from "react";
import { Button } from "@/components/ui/button";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";
import { EmptyState } from "./empty-state";
import { ErrorState } from "./error-state";

export type DataTableColumn<T> = {
  /** Khóa cột; dùng để đọc `row[key]` khi không có `cell`. */
  key: string;
  header: string;
  cell?: (row: T) => ReactNode;
  align?: "left" | "right" | "center";
};

export type DataTablePagination = {
  page: number;
  pageSize: number;
  total: number;
  onPageChange: (page: number) => void;
};

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
 * Bảng dữ liệu dùng chung: 4 trạng thái tải / rỗng / lỗi / có dữ liệu
 * (AGENTS.md mục 5) + phân trang phía server. Không tự gọi API —
 * dữ liệu và phân trang do màn hình cha truyền vào.
 */
export function DataTable<T extends { id: string | number }>({
  columns,
  rows,
  loading = false,
  error,
  onRetry,
  emptyTitle,
  emptyDescription,
  emptyAction,
  pagination,
  className,
}: {
  columns: DataTableColumn<T>[];
  rows: T[];
  loading?: boolean;
  error?: string | null;
  onRetry?: () => void;
  emptyTitle?: string;
  emptyDescription?: string;
  emptyAction?: ReactNode;
  pagination?: DataTablePagination;
  className?: string;
}) {
  const totalPages = pagination
    ? Math.max(1, Math.ceil(pagination.total / pagination.pageSize))
    : 1;
  const from = pagination ? (pagination.page - 1) * pagination.pageSize + 1 : 0;
  const to = pagination
    ? Math.min(pagination.page * pagination.pageSize, pagination.total)
    : rows.length;

  return (
    <div className={cn("w-full overflow-x-auto rounded-lg border", className)}>
      <table className="w-full text-sm">
        <thead className="bg-muted/50 text-left">
          <tr>
            {columns.map((column) => (
              <th
                key={column.key}
                scope="col"
                className={cn(
                  "px-3 py-2 font-medium whitespace-nowrap",
                  column.align === "right" && "text-right",
                  column.align === "center" && "text-center",
                )}
              >
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading
            ? Array.from({ length: 3 }).map((_, index) => (
                <tr key={`skeleton-${index}`} className="border-t">
                  {columns.map((column) => (
                    <td key={column.key} className="px-3 py-3">
                      <span className="block h-4 w-24 animate-pulse rounded bg-muted" />
                    </td>
                  ))}
                </tr>
              ))
            : null}
          {!loading && error ? (
            <tr className="border-t">
              <td colSpan={columns.length}>
                <ErrorState description={error} onRetry={onRetry} />
              </td>
            </tr>
          ) : null}
          {!loading && !error && rows.length === 0 ? (
            <tr className="border-t">
              <td colSpan={columns.length}>
                <EmptyState
                  title={emptyTitle ?? vi.components.table.emptyTitle}
                  description={
                    emptyDescription ?? vi.components.table.emptyDescription
                  }
                  action={emptyAction}
                />
              </td>
            </tr>
          ) : null}
          {!loading &&
            !error &&
            rows.map((row) => (
              <tr key={row.id} className="border-t hover:bg-muted/40">
                {columns.map((column) => (
                  <td
                    key={column.key}
                    className={cn(
                      "px-3 py-2 align-top",
                      column.align === "right" && "text-right",
                      column.align === "center" && "text-center",
                    )}
                  >
                    {column.cell
                      ? column.cell(row)
                      : String(
                          (row as Record<string, unknown>)[column.key] ?? "",
                        )}
                  </td>
                ))}
              </tr>
            ))}
        </tbody>
      </table>
      {pagination ? (
        <div className="flex flex-wrap items-center justify-between gap-2 border-t px-3 py-2 text-sm text-muted-foreground">
          <span>
            {pagination.total > 0
              ? interpolate(vi.components.table.showing, {
                  from,
                  to,
                  total: pagination.total,
                })
              : vi.components.table.emptyTitle}
          </span>
          <span className="flex items-center gap-2">
            <Button
              variant="outline"
              size="sm"
              disabled={pagination.page <= 1}
              onClick={() => pagination.onPageChange(pagination.page - 1)}
            >
              {vi.components.table.previousPage}
            </Button>
            <span>
              {interpolate(vi.components.table.pageOf, {
                page: pagination.page,
                totalPages,
              })}
            </span>
            <Button
              variant="outline"
              size="sm"
              disabled={pagination.page >= totalPages}
              onClick={() => pagination.onPageChange(pagination.page + 1)}
            >
              {vi.components.table.nextPage}
            </Button>
          </span>
        </div>
      ) : null}
    </div>
  );
}
