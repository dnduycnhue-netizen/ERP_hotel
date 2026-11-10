"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronsLeft, ChevronsRight, X } from "lucide-react";
import { vi } from "@/i18n/vi";
import { usePermissions } from "@/lib/permissions/permissions-provider";
import { cn } from "@/lib/utils";
import { NAV_GROUPS, NAV_ITEMS } from "./nav-items";

/**
 * Sidebar điều hướng trái kiểu ClickUp (ADR-006).
 * Render dưới dạng `<header>` (chứa logo + điều hướng chính) để giữ
 * test smoke T-047 S2 xanh (header chứa ≥ 8 link, trong đó có link
 * Nhận hàng và link về trang tổng quan).
 */
export function AppSidebar({
  propertyId,
  propertyName,
  collapsed,
  onToggleCollapsed,
  mobileOpen,
  onCloseMobile,
}: {
  propertyId: string;
  propertyName: string;
  collapsed: boolean;
  onToggleCollapsed: () => void;
  mobileOpen: boolean;
  onCloseMobile: () => void;
}) {
  const pathname = usePathname();
  const { permissions } = usePermissions();

  const isActive = (item: (typeof NAV_ITEMS)[number]): boolean => {
    const href = item.href(propertyId);
    if (item.key === "dashboard") {
      return pathname === href;
    }
    const prefix = item.matchPrefix(propertyId);
    return pathname === href || pathname.startsWith(`${prefix}/`);
  };

  const content = (
    <>
      <div
        className={cn(
          "flex h-14 shrink-0 items-center gap-2 border-b px-3",
          collapsed && "justify-center px-0",
        )}
      >
        <Link
          href={`/${propertyId}`}
          onClick={onCloseMobile}
          className="flex min-w-0 items-center gap-2.5 rounded-md px-1 py-1 outline-none focus-visible:ring-2 focus-visible:ring-brand"
          aria-label={propertyName}
        >
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand text-base font-bold text-white">
            M
          </span>
          {!collapsed ? (
            <span className="min-w-0">
              <span className="block truncate text-sm font-semibold text-foreground">
                {propertyName}
              </span>
              <span className="block text-xs text-muted-foreground">
                Mini-ERP
              </span>
            </span>
          ) : null}
        </Link>
        {!collapsed ? (
          <button
            type="button"
            onClick={onCloseMobile}
            className="ml-auto rounded-md p-1.5 text-muted-foreground hover:bg-accent hover:text-foreground lg:hidden"
            aria-label={vi.shell.closeSidebar}
          >
            <X className="size-4" aria-hidden />
          </button>
        ) : null}
      </div>

      <nav
        aria-label={vi.shell.menu}
        className="min-h-0 flex-1 overflow-y-auto px-2 py-3"
      >
        {NAV_GROUPS.map((group) => {
          const items = NAV_ITEMS.filter(
            (item) => item.group === group.id && item.visible(permissions),
          );
          if (items.length === 0) return null;
          return (
            <div key={group.id} className="mt-4 first:mt-0">
              {!collapsed ? (
                <p className="px-2 pb-1.5 text-[11px] font-semibold tracking-wider text-muted-foreground uppercase">
                  {group.label}
                </p>
              ) : null}
              <ul className="space-y-0.5">
                {items.map((item) => {
                  const active = isActive(item);
                  const Icon = item.icon;
                  return (
                    <li key={item.key}>
                      <Link
                        href={item.href(propertyId)}
                        onClick={onCloseMobile}
                        aria-current={active ? "page" : undefined}
                        title={collapsed ? item.label : undefined}
                        className={cn(
                          "flex h-9 items-center gap-2.5 rounded-md px-2 text-sm font-medium transition-colors outline-none focus-visible:ring-2 focus-visible:ring-brand",
                          active
                            ? "bg-brand/10 text-brand"
                            : "text-foreground/75 hover:bg-accent hover:text-foreground",
                          collapsed && "justify-center px-0",
                        )}
                      >
                        <Icon className="size-4 shrink-0" aria-hidden />
                        {!collapsed ? (
                          <span className="truncate">{item.label}</span>
                        ) : null}
                      </Link>
                    </li>
                  );
                })}
              </ul>
            </div>
          );
        })}
      </nav>

      <div className="shrink-0 border-t p-2">
        <button
          type="button"
          onClick={onToggleCollapsed}
          className="hidden h-9 w-full items-center gap-2.5 rounded-md px-2 text-sm font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-foreground lg:flex"
          aria-label={
            collapsed ? vi.shell.expandSidebar : vi.shell.collapseSidebar
          }
        >
          {collapsed ? (
            <ChevronsRight className="size-4 shrink-0" aria-hidden />
          ) : (
            <>
              <ChevronsLeft className="size-4 shrink-0" aria-hidden />
              <span className="truncate">{vi.shell.collapseSidebar}</span>
            </>
          )}
        </button>
      </div>
    </>
  );

  return (
    <>
      {/* Desktop: sidebar cố định, thu gọn được. */}
      <header
        className={cn(
          "sticky top-0 hidden h-screen shrink-0 flex-col border-r bg-sidebar lg:flex",
          collapsed ? "w-[68px]" : "w-66",
        )}
      >
        {content}
      </header>

      {/* Mobile: drawer phủ khi bấm hamburger. */}
      {mobileOpen ? (
        <div
          className="fixed inset-0 z-50 lg:hidden"
          role="dialog"
          aria-modal="true"
          aria-label={vi.shell.menu}
        >
          <button
            type="button"
            aria-label={vi.shell.closeSidebar}
            onClick={onCloseMobile}
            className="absolute inset-0 bg-black/40"
          />
          <header className="absolute inset-y-0 left-0 flex w-72 flex-col border-r bg-sidebar shadow-xl">
            {content}
          </header>
        </div>
      ) : null}
    </>
  );
}
