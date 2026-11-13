import { connection } from "next/server";
import {
  ModulesManager,
  type ModulesRow,
} from "@/components/admin/modules-manager";
import { EmptyState } from "@/components/common/empty-state";
import { ErrorState } from "@/components/common/error-state";
import { PageHeader } from "@/components/shell/page-header";
import { callAdminRpc } from "@/features/admin/rpc";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

export default async function ModulesPage() {
  await connection();
  const t = vi.admin.modules;
  const supabase = await createClient();
  const result = await callAdminRpc<ModulesRow[]>(
    supabase,
    "admin_modules_overview",
    {},
  );

  return (
    <div className="space-y-6">
      <PageHeader title={t.title} description={t.description} />
      {!result.ok ? (
        <ErrorState title={t.loadError} description={result.error} />
      ) : result.data.length === 0 ? (
        <EmptyState title={t.empty} />
      ) : (
        <ModulesManager rows={result.data} />
      )}
    </div>
  );
}
