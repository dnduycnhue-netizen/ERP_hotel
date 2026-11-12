import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/shell/app-shell";
import { countUnreadAlerts } from "@/features/alerts/queries";
import { PermissionsProvider } from "@/lib/permissions/permissions-provider";
import { listAccessibleProperties } from "@/lib/supabase/access";
import {
  createClient,
  getAuthenticatedUserEmail,
  getAuthenticatedUserId,
} from "@/lib/supabase/server";

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
  // Email/tên cho menu người dùng ở topbar (Q123): email lấy từ JWT
  // claims tại chỗ (0 round-trip), tên lấy bằng 1 câu select profiles
  // theo userId — userId cũng lấy từ claims tại chỗ nên có trước khi
  // chạy các promise dưới; lỗi select (vd RLS) chỉ làm tên hiện trống,
  // không chặn layout vì đây chỉ là thông tin hiển thị.
  // listAccessibleProperties, RPC my_permissions, số cảnh báo chưa xử
  // lý, email và hồ sơ không phụ thuộc nhau nên chạy song song. Đếm cảnh
  // báo chạy qua RLS của bảng alerts (chỉ dòng có quyền alert.receive.*
  // tương ứng) nên người không có quyền nào vẫn ra 0 — không cần chặn riêng.
  const userId = await getAuthenticatedUserId(supabase);
  const profileQuery = userId
    ? supabase
        .from("profiles")
        .select("full_name")
        .eq("id", userId)
        .maybeSingle()
    : Promise.resolve({ data: null as { full_name: string } | null });
  const [
    properties,
    { data: myPermissions },
    unreadAlerts,
    userEmail,
    profileResponse,
  ] = await Promise.all([
    listAccessibleProperties(supabase),
    supabase.rpc("my_permissions", { p_property: propertyId }),
    countUnreadAlerts(propertyId),
    getAuthenticatedUserEmail(supabase),
    profileQuery,
  ]);

  const currentProperty = properties.find(({ id }) => id === propertyId);

  if (!currentProperty) {
    notFound();
  }

  // Chuông chỉ hiện khi người dùng có ít nhất một quyền nhận cảnh báo
  // tại khách sạn (Q208); người không có quyền nào không thấy chuông.
  const canViewAlerts = (myPermissions ?? []).some((p: string) =>
    p.startsWith("alert.receive."),
  );

  // Ghi rõ kiểu ở biên: parser select của supabase-js suy ra
  // `data?.full_name` là `any` ở câu select này (cùng mẫu với select
  // "active" ở layout cha), nên ép về đúng kiểu hợp đồng của AppShell.
  const userName: string | null = profileResponse.data?.full_name ?? null;

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
        userEmail={userEmail}
        userName={userName}
      >
        {children}
      </AppShell>
    </PermissionsProvider>
  );
}
