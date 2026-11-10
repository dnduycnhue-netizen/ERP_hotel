"use client";

import { KanbanSquare, List } from "lucide-react";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

export type ListViewMode = "list" | "board";

/**
 * Chuyển List/Board kiểu ClickUp (ADR-008): nút gạt phân đoạn, mục
 * đang chọn nền brand nhạt + chữ brand. Chỉ là chuyển cách hiển thị —
 * không đổi dữ liệu hay bộ lọc.
 */
export function ViewToggle({
  value,
  onChange,
}: {
  value: ListViewMode;
  onChange: (value: ListViewMode) => void;
}) {
  return (
    <div
      role="group"
      aria-label={vi.shell.listView}
      className="inline-flex h-9 items-center rounded-md border bg-background p-0.5"
    >
      <button
        type="button"
        onClick={() => onChange("list")}
        aria-pressed={value === "list"}
        className={cn(
          "flex h-8 items-center gap-1.5 rounded px-2.5 text-sm font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-brand/40",
          value === "list"
            ? "bg-brand/10 text-brand"
            : "text-muted-foreground hover:text-foreground",
        )}
      >
        <List className="size-4" aria-hidden />
        {vi.shell.listView}
      </button>
      <button
        type="button"
        onClick={() => onChange("board")}
        aria-pressed={value === "board"}
        className={cn(
          "flex h-8 items-center gap-1.5 rounded px-2.5 text-sm font-medium outline-none transition-colors focus-visible:ring-2 focus-visible:ring-brand/40",
          value === "board"
            ? "bg-brand/10 text-brand"
            : "text-muted-foreground hover:text-foreground",
        )}
      >
        <KanbanSquare className="size-4" aria-hidden />
        {vi.shell.boardView}
      </button>
    </div>
  );
}
