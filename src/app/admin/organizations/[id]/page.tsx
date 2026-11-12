import Link from "next/link";
import { notFound } from "next/navigation";
import { LegalEntityNameForm } from "@/components/admin/legal-entity-name-form";
import { QuickAssignWizard } from "@/components/admin/quick-assign-wizard";
import { PageHeader } from "@/components/shell/page-header";
import {
  filterQuickAssignRoles,
  getOrgDetail,
  hasChainPerm,
  listUsers,
} from "@/features/admin";
import { vi } from "@/i18n/vi";
import { createClient } from "@/lib/supabase/server";

/**
 * Trang thành công sau khi tạo tổ chức (C5): tóm tắt tổ chức / pháp nhân /
 * khách sạn mới + các bước tiếp theo (tạo tài khoản, kho, outlet) +
 * wizard gán nhanh vai trò (06 §6.4).
 */
export default async function OrganizationDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const supabase = await createClient();
  const canManage = await hasChainPerm(supabase, "admin.org.manage");
  if (!canManage) {
    notFound();
  }
  const [detail, users] = await Promise.all([
    getOrgDetail(supabase, id),
    listUsers(supabase),
  ]);
  if (!detail) {
    notFound();
  }
  const { org, legalEntity, property, roles } = detail;
  const sodProfile =
    property.sod_profile === "without_cc" ? "without_cc" : "with_cc";
  const quickAssignRoles = filterQuickAssignRoles(sodProfile, roles);
  const nextSteps = [
    {
      href: "/admin/users/new",
      title: vi.admin.orgNextStepUsers,
      hint: vi.admin.orgNextStepUsersHint,
    },
    {
      href: `/${property.id}/master/warehouses`,
      title: vi.admin.orgNextStepWarehouses,
      hint: vi.admin.orgNextStepWarehousesHint,
    },
    {
      href: `/${property.id}/master/outlets`,
      title: vi.admin.orgNextStepOutlets,
      hint: vi.admin.orgNextStepOutletsHint,
    },
  ];

  return (
    <div className="space-y-8">
      <PageHeader title={org.name} description={vi.admin.orgCreated} />

      <div className="grid gap-4 md:grid-cols-3">
        <section className="rounded-lg border bg-card p-4">
          <h2 className="text-sm font-semibold">{vi.admin.orgSection}</h2>
          <p className="mt-2 text-sm">{org.name}</p>
        </section>
        <section className="rounded-lg border bg-card p-4">
          <h2 className="text-sm font-semibold">{vi.admin.legalSection}</h2>
          <dl className="mt-2 space-y-1 text-sm">
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">{vi.admin.legalCode}</dt>
              <dd className="font-mono">{legalEntity.code}</dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="shrink-0 text-muted-foreground">
                {vi.admin.legalName}
              </dt>
              <dd className="min-w-0 flex-1">
                <LegalEntityNameForm
                  key={legalEntity.name}
                  orgId={org.id}
                  legalEntityId={legalEntity.id}
                  currentName={legalEntity.name}
                />
              </dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">{vi.admin.taxCode}</dt>
              <dd className="font-mono">{legalEntity.tax_code ?? "—"}</dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">
                {vi.admin.accountingRegime}
              </dt>
              <dd className="font-mono">{legalEntity.accounting_regime}</dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">
                {vi.admin.costingMethod}
              </dt>
              <dd className="font-mono">{legalEntity.costing_method}</dd>
            </div>
          </dl>
        </section>
        <section className="rounded-lg border bg-card p-4">
          <h2 className="text-sm font-semibold">{vi.admin.propertySection}</h2>
          <dl className="mt-2 space-y-1 text-sm">
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">{vi.admin.propertyCode}</dt>
              <dd className="font-mono">{property.code}</dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">{vi.admin.propertyName}</dt>
              <dd>{property.name}</dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">{vi.admin.address}</dt>
              <dd>{property.address ?? "—"}</dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">{vi.admin.sodProfile}</dt>
              <dd className="font-mono">{property.sod_profile}</dd>
            </div>
            <div className="flex justify-between gap-2">
              <dt className="text-muted-foreground">{vi.admin.roomsCount}</dt>
              <dd>{property.rooms_count}</dd>
            </div>
          </dl>
        </section>
      </div>

      <section className="space-y-3">
        <div>
          <h2 className="text-base font-semibold">
            {vi.admin.orgNextStepsTitle}
          </h2>
          <p className="mt-1 text-sm text-muted-foreground">
            {vi.admin.orgNextStepsDescription}
          </p>
        </div>
        <ul className="grid gap-3 md:grid-cols-3">
          {nextSteps.map((step) => (
            <li key={step.href} className="rounded-lg border bg-card p-4">
              <Link
                href={step.href}
                className="text-sm font-medium text-primary hover:underline"
              >
                {step.title}
              </Link>
              <p className="mt-1 text-sm text-muted-foreground">{step.hint}</p>
            </li>
          ))}
        </ul>
      </section>

      <QuickAssignWizard
        propertyId={property.id}
        sodProfile={sodProfile}
        roles={quickAssignRoles}
        users={users.filter((user) => user.active)}
      />

      <p>
        <Link
          href="/admin/organizations"
          className="text-sm text-primary hover:underline"
        >
          {vi.admin.orgListTitle}
        </Link>
      </p>
    </div>
  );
}
