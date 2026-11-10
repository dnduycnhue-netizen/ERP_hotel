import Link from "next/link";
import { notFound } from "next/navigation";
import { DataTable } from "@/components/common/data-table";
import { hasChainPerm, listOrganizations } from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/** Danh sách tổ chức (C5): mỗi tổ chức gồm pháp nhân + khách sạn. */
export default async function OrganizationsPage() {
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

      <DataTable
        columns={[
          {
            key: "name",
            header: vi.admin.orgName,
            cell: (row) => (
              <Link
                href={`/admin/organizations/${row.id}`}
                className="font-medium text-primary hover:underline"
              >
                {row.name}
              </Link>
            ),
          },
          {
            key: "legalEntities",
            header: vi.admin.legalSection,
            cell: (row) =>
              row.legalEntities
                .map((entity) => `${entity.code} — ${entity.name}`)
                .join(", ") || "—",
          },
          {
            key: "properties",
            header: vi.admin.propertySection,
            cell: (row) =>
              row.properties
                .map((property) => `${property.code} — ${property.name}`)
                .join(", ") || "—",
          },
        ]}
        rows={organizations}
        emptyTitle={vi.admin.orgListEmpty}
      />
    </div>
  );
}
