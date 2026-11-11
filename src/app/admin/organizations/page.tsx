import Link from "next/link";
import { connection } from "next/server";
import { notFound } from "next/navigation";
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
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">
            {vi.admin.orgListTitle}
          </h1>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.admin.orgListDescription}
          </p>
        </div>
        <Link
          href="/admin/organizations/new"
          className="inline-flex h-9 items-center justify-center gap-1.5 rounded-lg bg-primary px-4 text-sm font-medium whitespace-nowrap text-primary-foreground"
        >
          {vi.admin.createOrg}
        </Link>
      </div>

      <OrganizationsTable organizations={organizations} />
    </div>
  );
}
