import { notFound } from "next/navigation";
import { CreateOrgForm } from "@/components/admin/create-org-form";
import { PageHeader } from "@/components/shell/page-header";
import { hasChainPerm } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/** Tạo tổ chức + pháp nhân + khách sạn trong 1 màn (C5). */
export default async function CreateOrganizationPage() {
  const supabase = await createClient();
  const canManage = await hasChainPerm(supabase, "admin.org.manage");
  if (!canManage) {
    notFound();
  }

  return (
    <div className="space-y-6">
      <PageHeader
        title={vi.admin.createOrgTitle}
        description={vi.admin.createOrgDescription}
      />
      <div className="max-w-2xl rounded-lg border bg-card p-6">
        <CreateOrgForm />
      </div>
    </div>
  );
}
