import { ConfigScopeSelector } from "@/components/admin/config-scope-selector";
import { SettingsEditor } from "@/components/admin/settings-editor";
import { ErrorState } from "@/components/common/error-state";
import { PageHeader } from "@/components/shell/page-header";
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
      <PageHeader
        title={vi.admin.configSettingsTitle}
        description={vi.admin.configSettingsDescription}
      />
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
