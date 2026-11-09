import { ApprovalRulesEditor } from "@/components/admin/approval-rules-editor";
import { ConfigScopeSelector } from "@/components/admin/config-scope-selector";
import { ErrorState } from "@/components/common/error-state";
import {
  listApprovalApprovers,
  listApprovalRules,
  resolveAdminConfigScope,
} from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

export default async function ApprovalRulesPage({
  searchParams,
}: {
  searchParams: Promise<{ property?: string }>;
}) {
  const { property } = await searchParams;
  const supabase = await createClient();
  const scope = await resolveAdminConfigScope(
    supabase,
    "admin.approval_rules.manage",
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
  const [rules, approvers] = await Promise.all([
    listApprovalRules(supabase, scope.orgId, scope.propertyId),
    listApprovalApprovers(supabase, scope.orgId, scope.propertyId),
  ]);

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">
          {vi.admin.configApprovalTitle}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.admin.configApprovalDescription}
        </p>
      </div>
      <ConfigScopeSelector
        path="/admin/approval-rules"
        properties={scope.properties}
        selectedPropertyId={scope.propertyId}
      />
      <ApprovalRulesEditor
        orgId={scope.orgId}
        propertyId={scope.propertyId}
        initialRules={rules}
        approvers={approvers}
      />
    </div>
  );
}
