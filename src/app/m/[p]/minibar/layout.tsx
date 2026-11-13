import type { ReactNode } from "react";
import { ModuleDisabled } from "@/components/common/module-disabled";
import { vi } from "@/i18n/vi";
import { getPropertyModules } from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";

/**
 * Chặn truy cập thẳng URL khi module Buồng phòng & Lễ tân tắt ở khách sạn (Q254).
 * DB đã chặn ghi; layout này chặn luôn phần hiển thị.
 */
export default async function MinibarModuleLayout({
  children,
  params,
}: Readonly<{
  children: ReactNode;
  params: Promise<{ p: string }>;
}>) {
  const { p: propertyId } = await params;
  const supabase = await createClient();
  const modules = await getPropertyModules(supabase, propertyId);
  if (!modules.hk_frontdesk) {
    return <ModuleDisabled name={vi.admin.modules.hkFrontdesk} />;
  }
  return children;
}
