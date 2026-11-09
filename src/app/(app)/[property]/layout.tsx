import type { ReactNode } from "react";
import { notFound } from "next/navigation";
import { AdminLink } from "@/components/common/admin-link";
import { MasterLink } from "@/components/common/master-link";
import { ProcurementLink } from "@/components/common/procurement-link";
import { PropertySwitcher } from "@/components/common/property-switcher";
import { vi } from "@/i18n/vi";
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
      <div className="min-h-screen bg-muted/30">
        <header className="border-b bg-background">
          <div className="mx-auto flex max-w-7xl flex-col gap-4 px-4 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
            <a
              className="font-semibold tracking-tight"
              href={`/${currentProperty.id}`}
            >
              {vi.appName}
            </a>
            <div className="flex items-center gap-4">
              <MasterLink propertyId={currentProperty.id} />
              <ProcurementLink propertyId={currentProperty.id} />
              <AdminLink />
              <PropertySwitcher
                currentPropertyId={currentProperty.id}
                properties={properties}
              />
            </div>
          </div>
        </header>
        <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6">{children}</main>
      </div>
    </PermissionsProvider>
  );
}
