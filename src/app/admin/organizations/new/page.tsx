import { notFound } from "next/navigation";
import { CreateOrgForm } from "@/components/admin/create-org-form";
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
      <div>
        <h1 className="text-2xl font-bold tracking-tight">
          {vi.admin.createOrgTitle}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {vi.admin.createOrgDescription}
        </p>
      </div>
      <div className="max-w-2xl rounded-lg border bg-card p-6">
        <CreateOrgForm />
      </div>
    </div>
  );
}
