import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { ModuleDisabled } from "@/components/common/module-disabled";
import { getPropertyModules } from "@/lib/modules/server";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/**
 * Khu lễ tân — minibar (T-035) + số liệu PMS ngày (T-036).
 * Chặn người không có quyền lễ tân nào ở tầng layout.
 */
export default async function FrontdeskLayout({
  children,
  params,
}: Readonly<{
  children: ReactNode;
  params: Promise<{ property: string }>;
}>) {
  const { property: propertyId } = await params;
  const supabase = await createClient();
  const modules = await getPropertyModules(supabase, propertyId);
  if (!modules.hk_frontdesk) {
    return <ModuleDisabled name={vi.admin.modules.hkFrontdesk} />;
  }

  const { data: myPerms } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });

  const perms = new Set(myPerms ?? []);
  const canAccess =
    perms.has("minibar.request_check") ||
    perms.has("minibar.charge.confirm") ||
    perms.has("minibar.waive.request") ||
    perms.has("minibar.waive.approve") ||
    perms.has("pms.input");

  if (!canAccess) {
    notFound();
  }

  return <div className="space-y-6">{children}</div>;
}
