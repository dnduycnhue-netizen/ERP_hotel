"use client";

import { useRef, useState } from "react";
import Link from "next/link";
import { Bell, KeyRound, LogOut, Menu, UserRound } from "lucide-react";
import { vi } from "@/i18n/vi";
import { switchProperty } from "@/app/(app)/actions";
import { signOut } from "@/app/(auth)/login/actions";
import type { AccessibleProperty } from "@/lib/supabase/access";
import { cn } from "@/lib/utils";
import { JumpSearch } from "./jump-search";

/**
 * Thanh trên cùng của vỏ app (ADR-006): hamburger (mobile), tìm kiếm
 * nhảy nhanh, bộ chọn khách sạn gọn, menu người dùng (đăng xuất).
 * Không phải `<header>` — sidebar đã giữ vai trò landmark header.
 *
 * Mode admin (Q122/Q123): khi propertyId null hoặc showJumpSearch=false
 * thì ẩn JumpSearch, bộ chọn khách sạn và chuông. Khi có userEmail hoặc
 * userName thì hiện khối định danh ở đầu dropdown user menu (Q123);
 * dữ liệu do server layout truyền xuống qua props, component không gọi
 * thêm getUser/getClaims.
 */
export function AppTopbar({
  propertyId,
  properties = [],
  canViewAlerts = false,
  unreadAlerts = 0,
  onOpenMobile,
  userEmail,
  userName,
  showJumpSearch = true,
}: {
  propertyId?: string | null;
  properties?: AccessibleProperty[];
  canViewAlerts?: boolean;
  unreadAlerts?: number;
  onOpenMobile: () => void;
  userEmail?: string | null;
  userName?: string | null;
  showJumpSearch?: boolean;
}) {
  const [userMenuOpen, setUserMenuOpen] = useState(false);
  const switchFormRef = useRef<HTMLFormElement>(null);

  // Nút avatar giữ nguyên aria-label vi.auth.signOut (đừng đổi — e2e
  // selector dựa vào nó).
  const hasIdentity = Boolean(userEmail ?? userName);

  return (
    <div className="sticky top-0 z-40 flex h-14 shrink-0 items-center gap-3 border-b bg-background/95 px-4 backdrop-blur sm:px-6">
      <button
        type="button"
        onClick={onOpenMobile}
        className="rounded-md p-2 text-muted-foreground hover:bg-accent hover:text-foreground lg:hidden"
        aria-label={vi.shell.menu}
      >
        <Menu className="size-5" aria-hidden />
      </button>

      {propertyId != null && showJumpSearch ? (
        <JumpSearch propertyId={propertyId} />
      ) : null}

      <div className="ml-auto flex items-center gap-2">
        {propertyId != null && showJumpSearch && properties.length > 1 ? (
          <form
            ref={switchFormRef}
            action={switchProperty}
            className="hidden sm:block"
          >
            <label className="sr-only" htmlFor="shell-property-id">
              {vi.property.switchLabel}
            </label>
            <select
              id="shell-property-id"
              name="propertyId"
              defaultValue={propertyId}
              title={vi.shell.switchProperty}
              onChange={() => switchFormRef.current?.requestSubmit()}
              className="h-9 max-w-56 rounded-md border bg-background px-2 text-sm outline-none focus-visible:ring-2 focus-visible:ring-brand/40"
            >
              {properties.map((property) => (
                <option key={property.id} value={property.id}>
                  {property.name} ({property.code})
                </option>
              ))}
            </select>
          </form>
        ) : null}

        {propertyId != null && showJumpSearch && canViewAlerts ? (
          <Link
            href={`/${propertyId}/alerts`}
            aria-label={
              unreadAlerts > 0
                ? `${vi.shell.unreadAlerts} (${unreadAlerts > 99 ? "99+" : unreadAlerts})`
                : vi.shell.alerts
            }
            title={vi.shell.alerts}
            className="relative flex h-9 w-9 items-center justify-center rounded-full border bg-background text-muted-foreground outline-none transition-colors hover:bg-accent hover:text-foreground focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <Bell className="size-4" aria-hidden />
            {unreadAlerts > 0 ? (
              <span className="absolute -top-1 -right-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-destructive px-1 text-[10px] leading-none font-semibold text-destructive-foreground">
                {unreadAlerts > 99 ? "99+" : unreadAlerts}
              </span>
            ) : null}
          </Link>
        ) : null}

        <div className="relative">
          <button
            type="button"
            onClick={() => setUserMenuOpen((open) => !open)}
            aria-expanded={userMenuOpen}
            aria-label={vi.auth.signOut}
            className="flex h-9 w-9 items-center justify-center rounded-full border bg-background text-muted-foreground outline-none transition-colors hover:bg-accent hover:text-foreground focus-visible:ring-2 focus-visible:ring-brand/40"
          >
            <UserRound className="size-4" aria-hidden />
          </button>
          {userMenuOpen ? (
            <>
              <button
                type="button"
                aria-label={vi.common.close}
                onClick={() => setUserMenuOpen(false)}
                className="fixed inset-0 z-40 cursor-default"
              />
              <div
                className={cn(
                  "absolute right-0 z-50 mt-2 overflow-hidden rounded-lg border bg-popover py-1 shadow-lg",
                  hasIdentity ? "w-56" : "w-44",
                )}
              >
                {hasIdentity ? (
                  <>
                    <div className="min-w-0 px-3 py-2">
                      {userName ? (
                        <p className="truncate text-sm font-medium text-foreground">
                          {userName}
                        </p>
                      ) : null}
                      {userEmail ? (
                        <p className="truncate text-xs text-muted-foreground">
                          {userEmail}
                        </p>
                      ) : null}
                    </div>
                    <div aria-hidden className="my-1 border-t" />
                  </>
                ) : null}
                <Link
                  href="/settings/password"
                  onClick={() => setUserMenuOpen(false)}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm font-medium text-foreground hover:bg-accent"
                >
                  <KeyRound className="size-4" aria-hidden />
                  {vi.password.changePasswordTitle}
                </Link>
                <form action={signOut}>
                  <button
                    type="submit"
                    className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm font-medium text-foreground hover:bg-accent"
                  >
                    <LogOut className="size-4" aria-hidden />
                    {vi.auth.signOut}
                  </button>
                </form>
              </div>
            </>
          ) : null}
        </div>
      </div>
    </div>
  );
}
