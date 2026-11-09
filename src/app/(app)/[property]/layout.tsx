import type { ReactNode } from "react";
import { notFound, redirect } from "next/navigation";
import { AdminLink } from "@/components/common/admin-link";
import { MasterLink } from "@/components/common/master-link";
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
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError && userError.name !== "AuthSessionMissingError") {
    throw userError;
  }
  if (!userData.user) {
    redirect("/login");
  }

  const properties = await listAccessibleProperties(supabase);
  const currentProperty = properties.find(({ id }) => id === propertyId);

  if (!currentProperty) {
    notFound();
  }

  const { data: myPermissions } = await supabase.rpc("my_permissions", {
    p_property: propertyId,
  });

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
