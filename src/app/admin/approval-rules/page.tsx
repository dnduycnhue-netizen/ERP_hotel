import { ApprovalDelegationsEditor } from "@/components/admin/approval-delegations-editor";
import { ApprovalRulesEditor } from "@/components/admin/approval-rules-editor";
import { ConfigScopeSelector } from "@/components/admin/config-scope-selector";
import { ErrorState } from "@/components/common/error-state";
import { PageHeader } from "@/components/shell/page-header";
import {
  listApprovalApprovers,
  listApprovalDelegations,
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
  const [rules, approvers, delegations] = await Promise.all([
    listApprovalRules(supabase, scope.orgId, scope.propertyId),
    listApprovalApprovers(supabase, scope.orgId, scope.propertyId),
    listApprovalDelegations(supabase, scope.orgId, scope.propertyId),
  ]);

  return (
    <div className="space-y-6">
      <PageHeader
        title={vi.admin.configApprovalTitle}
        description={vi.admin.configApprovalDescription}
      />
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
      <div className="space-y-2">
        <h2 className="text-base font-semibold">
          {vi.admin.configDelegationTitle}
        </h2>
        <p className="text-sm text-muted-foreground">
          {vi.admin.configDelegationDescription}
        </p>
      </div>
      <ApprovalDelegationsEditor
        orgId={scope.orgId}
        propertyId={scope.propertyId}
        properties={scope.properties}
        users={approvers.users}
        initialDelegations={delegations}
      />
    </div>
  );
}
