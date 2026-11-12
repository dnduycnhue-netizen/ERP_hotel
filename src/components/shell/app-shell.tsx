"use client";

import { useState, useSyncExternalStore, type ReactNode } from "react";
import type { AccessibleProperty } from "@/lib/supabase/access";
import { AppSidebar } from "./app-sidebar";
import { AppTopbar } from "./app-topbar";
import type { AdminNavVisibility } from "./nav-items";

const COLLAPSED_STORAGE_KEY = "erp-sidebar-collapsed";
const COLLAPSED_CHANGE_EVENT = "erp-sidebar-collapsed-change";

/**
 * Đọc trạng thái thu gọn từ localStorage qua useSyncExternalStore:
 * server render luôn mở (getServerSnapshot = false, khớp HTML),
 * client đọc lại sau hydration nên không lệch hydration, và việc ghi
 * ở tab khác cũng đồng bộ qua sự kiện `storage`.
 */
function getCollapsedSnapshot(): boolean {
  try {
    return window.localStorage.getItem(COLLAPSED_STORAGE_KEY) === "1";
  } catch {
    return false;
  }
}

function subscribeCollapsed(onStoreChange: () => void): () => void {
  window.addEventListener("storage", onStoreChange);
  window.addEventListener(COLLAPSED_CHANGE_EVENT, onStoreChange);
  return () => {
    window.removeEventListener("storage", onStoreChange);
    window.removeEventListener(COLLAPSED_CHANGE_EVENT, onStoreChange);
  };
}

/**
 * Vỏ app kiểu ClickUp (ADR-006): sidebar trái + topbar + vùng nội dung.
 *
 * Mode "admin" (Q122): propertyId/propertyName/properties/canViewAlerts/
 * unreadAlerts được phép vắng — sidebar chỉ hiện nav quản trị theo cờ
 * adminNav, topbar ẩn JumpSearch/bộ chọn khách sạn/chuông. Dữ liệu
 * định danh người dùng (Q123) do server layout truyền xuống qua props.
 */
export function AppShell({
  propertyId,
  propertyName,
  properties = [],
  canViewAlerts = false,
  unreadAlerts = 0,
  mode = "property",
  adminNav,
  userEmail,
  userName,
  children,
}: {
  propertyId?: string;
  propertyName?: string;
  properties?: AccessibleProperty[];
  canViewAlerts?: boolean;
  unreadAlerts?: number;
  mode?: "property" | "admin";
  adminNav?: AdminNavVisibility;
  userEmail?: string | null;
  userName?: string | null;
  children: ReactNode;
}) {
  const collapsed = useSyncExternalStore(
    subscribeCollapsed,
    getCollapsedSnapshot,
    () => false,
  );
  const [mobileOpen, setMobileOpen] = useState(false);

  const toggleCollapsed = () => {
    try {
      const next = !getCollapsedSnapshot();
      window.localStorage.setItem(COLLAPSED_STORAGE_KEY, next ? "1" : "0");
    } catch {
      // localStorage không dùng được (chế độ riêng tư...) — bỏ qua.
    }
    window.dispatchEvent(new Event(COLLAPSED_CHANGE_EVENT));
  };

  return (
    <div className="flex min-h-screen bg-background">
      <AppSidebar
        propertyId={propertyId}
        propertyName={propertyName}
        collapsed={collapsed}
        onToggleCollapsed={toggleCollapsed}
        mobileOpen={mobileOpen}
        onCloseMobile={() => setMobileOpen(false)}
        mode={mode}
        adminNav={adminNav}
      />
      <div className="flex min-w-0 flex-1 flex-col">
        <AppTopbar
          propertyId={propertyId ?? null}
          properties={properties}
          canViewAlerts={canViewAlerts}
          unreadAlerts={unreadAlerts}
          onOpenMobile={() => setMobileOpen(true)}
          userEmail={userEmail}
          userName={userName}
          showJumpSearch={mode !== "admin"}
        />
        <main className="mx-auto w-full max-w-[1440px] px-4 py-6 sm:px-6">
          {children}
        </main>
      </div>
    </div>
  );
}
