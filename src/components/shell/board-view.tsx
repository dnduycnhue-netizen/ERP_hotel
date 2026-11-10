import type { ReactNode } from "react";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

export type BoardColumn = {
  key: string;
  /** Tiêu đề cột (nhãn trạng thái). */
  label: ReactNode;
  /** Thẻ trong cột. */
  cards: ReactNode[];
};

/**
 * Bảng trạng thái chỉ đọc kiểu ClickUp (ADR-008): nhóm các dòng đã
 * tải của trang hiện tại theo cột trạng thái. KHÔNG kéo-thả — kéo một
 * chứng từ sang trạng thái khác phải gọi RPC duyệt/hủy/ghi sổ tương
 * ứng, không phải đổi cột đơn thuần (xem Q133). Bấm thẻ để mở chi
 * tiết; thao tác trạng thái vẫn làm ở màn chi tiết như trước.
 */
export function BoardView({
  columns,
  emptyTitle,
}: {
  columns: BoardColumn[];
  emptyTitle?: string;
}) {
  const totalCards = columns.reduce(
    (sum, column) => sum + column.cards.length,
    0,
  );
  if (totalCards === 0) {
    return (
      <p className="rounded-lg border bg-card px-3 py-6 text-center text-sm text-muted-foreground">
        {emptyTitle ?? vi.components.table.emptyTitle}
      </p>
    );
  }
  return (
    <div className="space-y-2">
      <p className="text-xs text-muted-foreground">{vi.shell.boardNote}</p>
      <div className="flex items-start gap-3 overflow-x-auto pb-2">
        {columns.map((column) => (
          <section
            key={column.key}
            aria-label={
              typeof column.label === "string" ? column.label : undefined
            }
            className="w-64 shrink-0 rounded-lg border bg-muted/40 p-2"
          >
            <header className="flex items-center justify-between gap-2 px-1 py-1.5">
              <h2 className="min-w-0 truncate text-xs font-semibold tracking-wide text-foreground uppercase">
                {column.label}
              </h2>
              <span
                className={cn(
                  "shrink-0 rounded-full bg-background px-2 py-0.5 text-xs font-medium text-muted-foreground",
                )}
              >
                {column.cards.length}
              </span>
            </header>
            <div className="space-y-2">
              {column.cards.length === 0 ? (
                <p className="rounded-md border border-dashed bg-background px-3 py-4 text-center text-xs text-muted-foreground">
                  {vi.common.noData}
                </p>
              ) : (
                column.cards
              )}
            </div>
          </section>
        ))}
      </div>
    </div>
  );
}
