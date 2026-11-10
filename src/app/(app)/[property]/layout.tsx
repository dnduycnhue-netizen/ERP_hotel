import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { AppShell } from "@/components/shell/app-shell";
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
  // listAccessibleProperties và RPC my_permissions không phụ thuộc nhau
  // nên chạy song song.
  const [properties, { data: myPermissions }] = await Promise.all([
    listAccessibleProperties(supabase),
    supabase.rpc("my_permissions", { p_property: propertyId }),
  ]);

  const currentProperty = properties.find(({ id }) => id === propertyId);

  if (!currentProperty) {
    notFound();
  }

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
      >
        {children}
      </AppShell>
    </PermissionsProvider>
  );
}
