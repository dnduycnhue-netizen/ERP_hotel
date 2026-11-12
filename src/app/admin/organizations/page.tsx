import Link from "next/link";
import { connection } from "next/server";
import { notFound } from "next/navigation";
import { PageHeader } from "@/components/shell/page-header";
import { hasChainPerm, listOrganizations } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";
import { OrganizationsTable } from "./organizations-table";

/** Danh sách tổ chức (C5): mỗi tổ chức gồm pháp nhân + khách sạn. */
export default async function OrganizationsPage() {
  // Chặn prerender (Q202): trang đọc session Supabase — không có dòng
  // này, Next 16 thử prerender và nổ lỗi `Date.now()` khi nạp session.
  await connection();
  const supabase = await createClient();
  const canManage = await hasChainPerm(supabase, "admin.org.manage");
  if (!canManage) {
    notFound();
  }
  const organizations = await listOrganizations(supabase);

  return (
    <div className="space-y-6">
      <PageHeader
        title={vi.admin.orgListTitle}
        description={vi.admin.orgListDescription}
        actions={
          <Link
            href="/admin/organizations/new"
            className="inline-flex h-9 items-center justify-center gap-1.5 rounded-lg bg-primary px-4 text-sm font-medium whitespace-nowrap text-primary-foreground"
          >
            {vi.admin.createOrg}
          </Link>
        }
      />

      <OrganizationsTable organizations={organizations} />
    </div>
  );
}
