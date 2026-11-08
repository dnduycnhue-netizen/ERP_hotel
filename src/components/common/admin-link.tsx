"use client";

import Link from "next/link";
import { useCan } from "@/lib/permissions/permissions-provider";
import { vi } from "@/i18n/vi";

/**
 * Link tới khu vực quản trị, chỉ hiện khi người dùng có quyền quản trị
 * vai trò hoặc người dùng (AGENTS.md quy tắc 10: kiểm tra quyền bằng
 * `useCan`, không kiểm tra tên vai trò).
 */
export function AdminLink() {
  const canRoles = useCan("admin.roles.manage");
  const canUsers = useCan("admin.users.manage");
  if (!canRoles && !canUsers) {
    return null;
  }
  return (
    <Link href="/admin/roles" className="text-sm text-primary hover:underline">
      {vi.admin.title}
    </Link>
  );
}
