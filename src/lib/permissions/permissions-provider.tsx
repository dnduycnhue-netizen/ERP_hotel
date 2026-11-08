"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { getMyPermissionsAction } from "@/features/admin/actions";

/**
 * Quyền của người dùng hiện tại tại khách sạn đang chọn
 * (docs/06-UI-UX.md mục 6.5): nạp lần đầu khi chọn khách sạn, làm mới
 * sau mỗi 5 phút và sau mỗi lần gán/thu hồi quyền.
 *
 * Server component truyền `initialPermissions` để lần render đầu không
 * phải chờ; client tự làm mới theo lịch.
 */
const PermissionsContext = createContext<ReadonlySet<string>>(
  new Set<string>(),
);

const RefreshContext = createContext<() => Promise<void>>(async () => {});

export function PermissionsProvider({
  propertyId,
  initialPermissions,
  children,
}: {
  propertyId: string | null;
  initialPermissions: string[];
  children: ReactNode;
}) {
  const [permissions, setPermissions] = useState<ReadonlySet<string>>(
    () => new Set(initialPermissions),
  );

  const refresh = useCallback(async () => {
    const next = await getMyPermissionsAction(propertyId);
    setPermissions(new Set(next));
  }, [propertyId]);

  useEffect(() => {
    const timer = window.setInterval(
      () => {
        void refresh();
      },
      5 * 60 * 1000,
    );
    return () => window.clearInterval(timer);
  }, [refresh]);

  const value = useMemo(() => permissions, [permissions]);

  return (
    <PermissionsContext.Provider value={value}>
      <RefreshContext.Provider value={refresh}>
        {children}
      </RefreshContext.Provider>
    </PermissionsContext.Provider>
  );
}

/** Kiểm tra một mã quyền (AGENTS.md quy tắc 10: kiểm tra quyền, không kiểm tra vai trò). */
export function useCan(permissionCode: string): boolean {
  const permissions = useContext(PermissionsContext);
  return permissions.has(permissionCode);
}

/** Toàn bộ quyền hiện tại + hàm làm mới (dùng sau gán/thu hồi quyền). */
export function usePermissions(): {
  permissions: ReadonlySet<string>;
  refresh: () => Promise<void>;
} {
  return {
    permissions: useContext(PermissionsContext),
    refresh: useContext(RefreshContext),
  };
}
