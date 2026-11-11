"use client";

import Link from "next/link";
import { DataTable } from "@/components/common/data-table";
import type { OrgSummary } from "@/features/admin";
import { vi } from "@/i18n/vi";

/**
 * Bảng tổ chức (Q203): cột `cell` là hàm nên phải định nghĩa ở phía
 * client — trang server chỉ được truyền dữ liệu thuần (rows) sang.
 * Truyền hàm từ Server Component sang Client Component làm React nổ
 * lỗi serialize ("Functions cannot be passed directly to Client
 * Components") và trang /admin/organizations sập hoàn toàn.
 */
export function OrganizationsTable({
  organizations,
}: {
  organizations: OrgSummary[];
}) {
  return (
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
  );
}
