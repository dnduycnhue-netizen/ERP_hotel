"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronsLeft, ChevronsRight, X, type LucideIcon } from "lucide-react";
import { vi } from "@/i18n/vi";
import { usePermissions } from "@/lib/permissions/permissions-provider";
import { cn } from "@/lib/utils";
import {
  ADMIN_NAV_ITEMS,
  NAV_GROUPS,
  NAV_ITEMS,
  type AdminNavVisibility,
} from "./nav-items";

type SidebarNavItem = {
  key: string;
  label: string;
  href: string;
  icon: LucideIcon;
  active: boolean;
};

type SidebarNavGroup = {
  id: string;
  label: string;
  items: SidebarNavItem[];
};

/**
 * Sidebar điều hướng trái kiểu ClickUp (ADR-006).
 * Render dưới dạng `<header>` (chứa logo + điều hướng chính) để giữ
 * test smoke T-047 S2 xanh (header chứa ≥ 8 link, trong đó có link
 * Nhận hàng và link về trang tổng quan).
 *
 * Mode "admin" (Q122): logo về "/", nhãn vi.admin.title, nav chỉ 1 nhóm
 * "Hệ thống" với 6 mục, mỗi mục chỉ hiện khi cờ adminNav tương ứng true.
 */
export function AppSidebar({
  propertyId,
  propertyName,
  collapsed,
  onToggleCollapsed,
  mobileOpen,
  onCloseMobile,
  mode = "property",
  adminNav,
}: {
  propertyId?: string;
  propertyName?: string;
  collapsed: boolean;
  onToggleCollapsed: () => void;
  mobileOpen: boolean;
  onCloseMobile: () => void;
  mode?: "property" | "admin";
  adminNav?: AdminNavVisibility;
}) {
  const pathname = usePathname();
  const { permissions } = usePermissions();

  const isAdmin = mode === "admin";

  const isActive = (item: (typeof NAV_ITEMS)[number]): boolean => {
    const href = item.href(propertyId ?? "");
    if (item.key === "dashboard") {
      return pathname === href;
    }
    const prefix = item.matchPrefix(propertyId ?? "");
    return pathname === href || pathname.startsWith(`${prefix}/`);
  };

  /**
   * Nhóm điều hướng đã tính sẵn — cùng hình dạng cho cả 2 mode nên JSX
   * render phía dưới dùng chung 1 lần, hành vi collapse/drawer giữ
   * nguyên. Mode "property": Y HỆT như cũ (NAV_GROUPS + NAV_ITEMS lọc
   * theo quyền); mode "admin": 1 nhóm "Hệ thống", lọc theo cờ adminNav.
   */
  const groups: SidebarNavGroup[] = isAdmin
    ? [
        {
          id: "system",
          label: vi.shell.groups.system,
          items: ADMIN_NAV_ITEMS.filter(
            (item) => adminNav?.[item.key] ?? false,
          ).map((item) => ({
            key: item.key,
            label: item.label,
            href: item.href,
            icon: item.icon,
            active:
              pathname === item.href || pathname.startsWith(`${item.href}/`),
          })),
        },
      ]
    : NAV_GROUPS.map((group) => ({
        id: group.id,
        label: group.label,
        items: NAV_ITEMS.filter(
          (item) => item.group === group.id && item.visible(permissions),
        ).map((item) => ({
          key: item.key,
          label: item.label,
          href: item.href(propertyId ?? ""),
          icon: item.icon,
          active: isActive(item),
        })),
      }));

  const logoHref = isAdmin ? "/" : `/${propertyId ?? ""}`;
  const logoLabel = isAdmin ? vi.admin.title : (propertyName ?? "");

  const content = (
    <>
      <div
        className={cn(
          "flex h-14 shrink-0 items-center gap-2 border-b px-3",
          collapsed && "justify-center px-0",
        )}
      >
        <Link
          href={logoHref}
          onClick={onCloseMobile}
          className="flex min-w-0 items-center gap-2.5 rounded-md px-1 py-1 outline-none focus-visible:ring-2 focus-visible:ring-brand"
          aria-label={logoLabel}
        >
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-brand text-base font-bold text-white">
            M
          </span>
          {!collapsed ? (
            <span className="min-w-0">
              <span className="block truncate text-sm font-semibold text-foreground">
                {logoLabel}
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
        {groups.map((group) => {
          const items = group.items;
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
                  const active = item.active;
                  const Icon = item.icon;
                  return (
                    <li key={item.key}>
                      <Link
                        href={item.href}
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
