"use client";

import { useRef, useState } from "react";
import { LogOut, Menu, UserRound } from "lucide-react";
import { vi } from "@/i18n/vi";
import { switchProperty } from "@/app/(app)/actions";
import { signOut } from "@/app/(auth)/login/actions";
import type { AccessibleProperty } from "@/lib/supabase/access";
import { JumpSearch } from "./jump-search";

/**
 * Thanh trên cùng của vỏ app (ADR-006): hamburger (mobile), tìm kiếm
 * nhảy nhanh, bộ chọn khách sạn gọn, menu người dùng (đăng xuất).
 * Không phải `<header>` — sidebar đã giữ vai trò landmark header.
 */
export function AppTopbar({
  propertyId,
  properties,
  onOpenMobile,
}: {
  propertyId: string;
  properties: AccessibleProperty[];
  onOpenMobile: () => void;
}) {
  const [userMenuOpen, setUserMenuOpen] = useState(false);
  const switchFormRef = useRef<HTMLFormElement>(null);

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

      <JumpSearch propertyId={propertyId} />

      <div className="ml-auto flex items-center gap-2">
        {properties.length > 1 ? (
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
              <div className="absolute right-0 z-50 mt-2 w-44 overflow-hidden rounded-lg border bg-popover py-1 shadow-lg">
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
