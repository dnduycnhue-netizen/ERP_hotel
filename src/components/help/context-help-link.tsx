"use client";

import { CircleHelp } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { helpSectionForPath } from "@/features/help/context";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

/**
 * Nút "?" trên khung app: mở Trung tâm hướng dẫn, kèm gợi ý các bài liên quan
 * tới màn hình đang xem (`?ctx=<mục>`).
 */
export function ContextHelpLink({
  basePath,
  className,
}: {
  /** `/<p>/help` (desktop) hoặc `/m/<p>/help` (mobile). */
  basePath: string;
  className?: string;
}) {
  const pathname = usePathname();
  const section = helpSectionForPath(pathname);
  const href = section ? `${basePath}?ctx=${section}` : basePath;
  return (
    <Link
      href={href}
      aria-label={vi.help.contextLabel}
      title={vi.help.contextLabel}
      className={cn(
        "flex h-9 w-9 items-center justify-center rounded-full border bg-background text-muted-foreground outline-none transition-colors hover:bg-accent hover:text-foreground focus-visible:ring-2 focus-visible:ring-brand/40",
        className,
      )}
    >
      <CircleHelp className="size-4" aria-hidden />
    </Link>
  );
}
