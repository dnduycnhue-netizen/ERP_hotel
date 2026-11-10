"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { Search } from "lucide-react";
import { vi } from "@/i18n/vi";
import { usePermissions } from "@/lib/permissions/permissions-provider";
import { cn } from "@/lib/utils";
import {
  buildJumpDestinations,
  normalizeSearchText,
  type JumpDestination,
} from "./nav-items";

/**
 * Ô tìm kiếm nhảy nhanh ở topbar (ADR-006): index tĩnh các đích điều
 * hướng, khớp không dấu. KHÔNG tìm dữ liệu nghiệp vụ (không có backend
 * tìm kiếm) — chỉ giúp mở nhanh chức năng.
 */
export function JumpSearch({ propertyId }: { propertyId: string }) {
  const router = useRouter();
  const { permissions } = usePermissions();
  const [query, setQuery] = useState("");
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const boxRef = useRef<HTMLDivElement>(null);

  const destinations: JumpDestination[] = buildJumpDestinations(
    propertyId,
  ).filter((destination) => destination.visible(permissions));

  const needle = normalizeSearchText(query.trim());
  const matches =
    needle.length === 0
      ? []
      : destinations.filter((destination) =>
          normalizeSearchText(
            `${destination.label} ${destination.groupLabel}`,
          ).includes(needle),
        );

  useEffect(() => {
    const onPointerDown = (event: PointerEvent) => {
      if (boxRef.current && !boxRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("pointerdown", onPointerDown);
    return () => document.removeEventListener("pointerdown", onPointerDown);
  }, []);

  const goTo = (destination: JumpDestination) => {
    setOpen(false);
    setQuery("");
    router.push(destination.href(propertyId));
  };

  return (
    <div ref={boxRef} className="relative w-full max-w-md">
      <div className="flex h-9 items-center gap-2 rounded-md border bg-background px-3 focus-within:ring-2 focus-within:ring-brand/40">
        <Search className="size-4 shrink-0 text-muted-foreground" aria-hidden />
        <input
          value={query}
          onChange={(event) => {
            setQuery(event.target.value);
            setActiveIndex(0);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onKeyDown={(event) => {
            if (event.key === "Escape") {
              setOpen(false);
              return;
            }
            if (event.key === "ArrowDown") {
              event.preventDefault();
              setActiveIndex((index) =>
                Math.min(index + 1, matches.length - 1),
              );
              return;
            }
            if (event.key === "ArrowUp") {
              event.preventDefault();
              setActiveIndex((index) => Math.max(index - 1, 0));
              return;
            }
            if (event.key === "Enter" && matches.length > 0) {
              event.preventDefault();
              goTo(matches[activeIndex] ?? matches[0]);
            }
          }}
          placeholder={vi.shell.searchPlaceholder}
          aria-label={vi.shell.searchPlaceholder}
          role="combobox"
          aria-expanded={open && matches.length > 0}
          aria-controls="jump-search-list"
          className="h-full w-full bg-transparent text-sm outline-none placeholder:text-muted-foreground"
        />
      </div>
      {open && needle.length > 0 ? (
        <div
          id="jump-search-list"
          role="listbox"
          className="absolute top-10 right-0 left-0 z-50 overflow-hidden rounded-lg border bg-popover shadow-lg"
        >
          {matches.length === 0 ? (
            <p className="px-3 py-2.5 text-sm text-muted-foreground">
              {vi.shell.searchNoResults}
            </p>
          ) : (
            <ul className="max-h-80 overflow-y-auto py-1">
              {matches.slice(0, 8).map((destination, index) => (
                <li key={`${destination.groupLabel}-${destination.label}`}>
                  <button
                    type="button"
                    role="option"
                    aria-selected={index === activeIndex}
                    onMouseEnter={() => setActiveIndex(index)}
                    onClick={() => goTo(destination)}
                    className={cn(
                      "flex w-full items-center justify-between gap-2 px-3 py-2 text-left text-sm",
                      index === activeIndex
                        ? "bg-brand/10 text-brand"
                        : "text-foreground hover:bg-accent",
                    )}
                  >
                    <span className="truncate font-medium">
                      {destination.label}
                    </span>
                    <span className="shrink-0 text-xs text-muted-foreground">
                      {destination.groupLabel}
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>
      ) : null}
    </div>
  );
}
