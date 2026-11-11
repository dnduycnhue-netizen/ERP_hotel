import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/shell/app-shell";
import { countUnreadAlerts } from "@/features/alerts/queries";
import { PermissionsProvider } from "@/lib/permissions/permissions-provider";
import { listAccessibleProperties } from "@/lib/supabase/access";
import { createClient } from "@/lib/supabase/server";

export default async function PropertyLayout({
  children,
  params,
}: Readonly<{
  children: ReactNode;
  params: Promise<{ property: string }>;
}>) {
  const { property: propertyId } = await params;
  const supabase = await createClient();

  // Layout cha (app) đã chặn người chưa đăng nhập (getUser + redirect
  // /login) nên ở đây không gọi getUser() lần nữa; hai lần gọi nối tiếp
  // chỉ thêm một vòng round-trip tới Supabase Auth cho mỗi request.
  // listAccessibleProperties, RPC my_permissions và số cảnh báo chưa xử
  // lý không phụ thuộc nhau nên chạy song song. Đếm cảnh báo chạy qua
  // RLS của bảng alerts (chỉ dòng có quyền alert.receive.<code> tương
  // ứng) nên người không có quyền nào vẫn ra 0 — không cần chặn riêng.
  const [properties, { data: myPermissions }, unreadAlerts] = await Promise.all(
    [
      listAccessibleProperties(supabase),
      supabase.rpc("my_permissions", { p_property: propertyId }),
      countUnreadAlerts(propertyId),
    ],
  );

  const currentProperty = properties.find(({ id }) => id === propertyId);

  if (!currentProperty) {
    notFound();
  }

  // Chuông chỉ hiện khi người dùng có ít nhất một quyền nhận cảnh báo
  // tại khách sạn (Q208); người không có quyền nào không thấy chuông.
  const canViewAlerts = (myPermissions ?? []).some((p: string) =>
    p.startsWith("alert.receive."),
  );

  return (
    <PermissionsProvider
      key={propertyId}
      propertyId={propertyId}
      initialPermissions={myPermissions ?? []}
    >
      <AppShell
        propertyId={currentProperty.id}
        propertyName={currentProperty.name}
        properties={properties}
        canViewAlerts={canViewAlerts}
        unreadAlerts={unreadAlerts}
      >
        {children}
      </AppShell>
    </PermissionsProvider>
  );
}
