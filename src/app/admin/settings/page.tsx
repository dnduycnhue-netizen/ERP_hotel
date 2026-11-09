import { ConfigScopeSelector } from "@/components/admin/config-scope-selector";
import { SettingsEditor } from "@/components/admin/settings-editor";
import { ErrorState } from "@/components/common/error-state";
import { listSettingEntries, resolveAdminConfigScope } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

export default async function SettingsPage({
  searchParams,
}: {
  searchParams: Promise<{ property?: string }>;
}) {
  const { property } = await searchParams;
  const supabase = await createClient();
  const scope = await resolveAdminConfigScope(
    supabase,
    "admin.settings.manage",
    property === undefined ? undefined : property || null,
  );
  if (!scope.orgId || !scope.canManage) {
    return (
      <ErrorState
        title={vi.admin.configNoAccessTitle}
        description={vi.admin.configNoAccessDescription}
      />
    );
  }
  const entries = await listSettingEntries(
    supabase,
    scope.orgId,
    scope.propertyId,
  );

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">
          {vi.admin.configSettingsTitle}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.admin.configSettingsDescription}
        </p>
      </div>
      <ConfigScopeSelector
        path="/admin/settings"
        properties={scope.properties}
        selectedPropertyId={scope.propertyId}
      />
      <SettingsEditor
        orgId={scope.orgId}
        propertyId={scope.propertyId}
        initialEntries={entries}
      />
    </div>
  );
}
