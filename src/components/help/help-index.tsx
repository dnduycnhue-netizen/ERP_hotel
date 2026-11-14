"use client";

import Link from "next/link";
import { useMemo, useState } from "react";
import { Search } from "lucide-react";
import { filterListItems, type HelpListItem } from "@/features/help/lib";
import { HELP_KIND_ORDER, type HelpKind } from "@/i18n/help/types";
import { vi } from "@/i18n/vi";
import { cn } from "@/lib/utils";

/** Trang chỉ mục: lọc theo loại + tìm kiếm không dấu; bài "Dành cho bạn" lên đầu. */
export function HelpIndex({
  basePath,
  items,
  suggested = [],
}: {
  /** `/<p>/help` (desktop) hoặc `/m/<p>/help` (mobile). */
  basePath: string;
  items: HelpListItem[];
  /** Bài gợi ý cho màn hình vừa xem (từ nút "?"). */
  suggested?: HelpListItem[];
}) {
  const [query, setQuery] = useState("");
  const [kind, setKind] = useState<HelpKind | "all">("all");
  const shown = useMemo(
    () => filterListItems(items, query, kind),
    [items, query, kind],
  );

  return (
    <div className="flex flex-col gap-4">
      {suggested.length > 0 ? (
        <section
          aria-label={vi.help.suggestedTitle}
          className="rounded-xl border border-primary/30 bg-primary/5 p-4"
        >
          <h2 className="mb-2 text-sm font-semibold">{vi.help.suggestedTitle}</h2>
          <ul className="flex flex-wrap gap-2">
            {suggested.map((item) => (
              <li key={item.slug}>
                <Link
                  href={`${basePath}/${item.slug}`}
                  className="inline-flex min-h-10 items-center rounded-full border bg-background px-3.5 text-sm font-medium hover:bg-muted"
                >
                  {item.title}
                </Link>
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      <label className="relative block max-w-xl">
        <span className="sr-only">{vi.help.searchLabel}</span>
        <Search
          className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground"
          aria-hidden
        />
        <input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={vi.help.searchPlaceholder}
          className="h-10 w-full rounded-lg border bg-background pr-3 pl-9 text-sm outline-none focus:border-ring"
        />
      </label>

      <div className="flex flex-wrap gap-1.5" role="tablist">
        {(["all", ...HELP_KIND_ORDER] as const).map((k) => (
          <button
            key={k}
            type="button"
            role="tab"
            aria-selected={kind === k}
            onClick={() => setKind(k)}
            className={cn(
              "min-h-9 rounded-full border px-3.5 text-sm font-medium transition-colors",
              kind === k
                ? "border-primary bg-primary text-primary-foreground"
                : "bg-background hover:bg-muted",
            )}
          >
            {k === "all" ? vi.help.allKinds : vi.help.kinds[k]}
          </button>
        ))}
      </div>
      {kind !== "all" ? (
        <p className="text-sm text-muted-foreground">
          {vi.help.kindHints[kind]}
        </p>
      ) : null}

      {shown.length === 0 ? (
        <p className="py-10 text-center text-sm text-muted-foreground">
          {vi.help.noResults}
        </p>
      ) : (
        <ul className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {shown.map((item) => (
            <li key={item.slug}>
              <Link
                href={`${basePath}/${item.slug}`}
                className="flex h-full flex-col gap-1.5 rounded-xl border bg-card p-4 transition-colors hover:border-primary/50 hover:bg-muted/40"
              >
                <span className="flex flex-wrap items-center gap-1.5">
                  <span className="rounded-full bg-muted px-2 py-0.5 text-[11px] font-medium text-muted-foreground">
                    {vi.help.kinds[item.kind]}
                  </span>
                  {item.relevant ? (
                    <span className="rounded-full bg-primary/10 px-2 py-0.5 text-[11px] font-medium text-primary">
                      {vi.help.forYou}
                    </span>
                  ) : null}
                </span>
                <span className="text-sm font-semibold">{item.title}</span>
                <span className="text-sm leading-relaxed text-muted-foreground">
                  {item.summary}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
