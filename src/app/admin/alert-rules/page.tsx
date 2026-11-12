import { AlertRulesEditor } from "@/components/admin/alert-rules-editor";
import { ConfigScopeSelector } from "@/components/admin/config-scope-selector";
import { ErrorState } from "@/components/common/error-state";
import { PageHeader } from "@/components/shell/page-header";
import { listAlertRules, resolveAdminConfigScope } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

export default async function AlertRulesPage({
  searchParams,
}: {
  searchParams: Promise<{ property?: string }>;
}) {
  const { property } = await searchParams;
  const supabase = await createClient();
  const scope = await resolveAdminConfigScope(
    supabase,
    "admin.alert_rules.manage",
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
  const rules = await listAlertRules(supabase, scope.orgId, scope.propertyId);

  return (
    <div className="space-y-6">
      <PageHeader title={vi.admin.configAlertTitle} />
      <ConfigScopeSelector
        path="/admin/alert-rules"
        properties={scope.properties}
        selectedPropertyId={scope.propertyId}
      />
      <AlertRulesEditor
        orgId={scope.orgId}
        propertyId={scope.propertyId}
        initialRules={rules}
      />
    </div>
  );
}
