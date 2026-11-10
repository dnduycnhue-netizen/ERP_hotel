import Link from "next/link";
import { notFound } from "next/navigation";
import {
  ArrowRight,
  Building2,
  CheckCircle2,
  Layers,
  Package,
  Settings,
  Users,
  Warehouse,
} from "lucide-react";
import { PageHeader } from "@/components/shell/page-header";
import { createClient } from "@/lib/supabase/server";
import { vi } from "@/i18n/vi";

type LegalEntityInfo = {
  code: string;
  name: string;
  costing_method: string;
  accounting_regime: string;
};

export default async function PropertyHome({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const supabase = await createClient();

  const { data: property, error: propError } = await supabase
    .from("properties")
    .select(
      "id, code, name, sod_profile, rooms_count, org_id, legal_entity:legal_entities(code, name, costing_method, accounting_regime)",
    )
    .eq("id", propertyId)
    .single();

  if (propError || !property) {
    notFound();
  }

  const [
    { count: itemsCount },
    { count: warehousesCount },
    { count: groupsCount },
    { count: rolesCount },
  ] = await Promise.all([
    supabase
      .from("items")
      .select("id", { count: "exact", head: true })
      .eq("org_id", property.org_id),
    supabase
      .from("warehouses")
      .select("id", { count: "exact", head: true })
      .eq("property_id", propertyId),
    supabase
      .from("item_groups")
      .select("id", { count: "exact", head: true })
      .eq("org_id", property.org_id),
    supabase
      .from("roles")
      .select("id", { count: "exact", head: true })
      .eq("org_id", property.org_id),
  ]);

  const le = property.legal_entity as unknown as LegalEntityInfo | null;

  const kpis = [
    {
      label: vi.property.kpiItems,
      value: itemsCount ?? 0,
      description: vi.property.kpiItemsDescription,
      icon: Package,
      tileClassName: "bg-blue-500/10 text-blue-600",
    },
    {
      label: vi.property.kpiWarehouses,
      value: warehousesCount ?? 0,
      description: vi.property.kpiWarehousesDescription,
      icon: Warehouse,
      tileClassName: "bg-emerald-500/10 text-emerald-600",
    },
    {
      label: vi.property.kpiGroups,
      value: groupsCount ?? 0,
      description: vi.property.kpiGroupsDescription,
      icon: Layers,
      tileClassName: "bg-amber-500/10 text-amber-600",
    },
    {
      label: vi.property.kpiRoles,
      value: rolesCount ?? 0,
      description: vi.property.kpiRolesDescription,
      icon: Users,
      tileClassName: "bg-brand/10 text-brand",
    },
  ];

  const modules = [
    {
      href: `/${propertyId}/master/items`,
      title: vi.property.moduleItemsTitle,
      description: vi.property.moduleItemsDescription,
      icon: Package,
      tileClassName: "bg-blue-500/10 text-blue-600",
    },
    {
      href: `/${propertyId}/master/warehouses`,
      title: vi.property.moduleWarehousesTitle,
      description: vi.property.moduleWarehousesDescription,
      icon: Building2,
      tileClassName: "bg-emerald-500/10 text-emerald-600",
    },
    {
      href: "/admin/users",
      title: vi.property.moduleUsersTitle,
      description: vi.property.moduleUsersDescription,
      icon: Users,
      tileClassName: "bg-brand/10 text-brand",
    },
    {
      href: "/admin/settings",
      title: vi.property.moduleSettingsTitle,
      description: vi.property.moduleSettingsDescription,
      icon: Settings,
      tileClassName: "bg-amber-500/10 text-amber-600",
    },
  ];

  const securityItems = [
    {
      title: vi.property.securityLedgerTitle,
      description: vi.property.securityLedgerDescription,
    },
    {
      title: vi.property.securityRlsTitle,
      description: vi.property.securityRlsDescription,
    },
    {
      title: vi.property.securitySodTitle,
      description: `${vi.property.securitySodDescription} ${
        property.sod_profile === "with_cc"
          ? vi.property.sodWithCc
          : vi.property.sodWithoutCc
      }.`,
    },
  ];

  return (
    <div className="space-y-8">
      <PageHeader
        title={property.name}
        description={
          <>
            {vi.property.codeLabel}{" "}
            <span className="font-mono font-semibold text-foreground">
              {property.code}
            </span>
            {" | "}
            {vi.property.legalEntityLabel}{" "}
            <span className="font-semibold text-foreground">
              {le?.name ?? "—"}
            </span>{" "}
            ({le?.code}){" | "}
            {vi.property.costingLabel}{" "}
            <span className="font-semibold text-foreground">
              {le?.costing_method === "fifo"
                ? vi.property.costingFifo
                : vi.property.costingMovingAvg}
            </span>
          </>
        }
        actions={
          <>
            <Link
              href={`/${propertyId}/master/items`}
              className="inline-flex h-9 items-center justify-center rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground shadow transition-colors hover:bg-primary/90"
            >
              {vi.property.goToItems}
            </Link>
            <Link
              href="/admin/users"
              className="inline-flex h-9 items-center justify-center rounded-md border border-input bg-background px-4 text-sm font-medium shadow-sm transition-colors hover:bg-accent hover:text-accent-foreground"
            >
              {vi.property.manageUsers}
            </Link>
          </>
        }
      >
        <span className="inline-flex items-center gap-1.5 rounded-full bg-emerald-100 px-2.5 py-1 text-[11px] font-semibold tracking-wide text-emerald-700 uppercase">
          <CheckCircle2 className="size-3.5" aria-hidden />
          {vi.property.activeStatus}
        </span>
      </PageHeader>

      {/* KPI */}
      <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
        {kpis.map((kpi) => {
          const Icon = kpi.icon;
          return (
            <div
              key={kpi.label}
              className="rounded-xl border bg-card p-4 shadow-sm"
            >
              <div className="flex items-center justify-between gap-2">
                <p className="text-sm font-medium text-muted-foreground">
                  {kpi.label}
                </p>
                <span
                  className={`flex h-8 w-8 items-center justify-center rounded-lg ${kpi.tileClassName}`}
                >
                  <Icon className="size-4" aria-hidden />
                </span>
              </div>
              <p className="mt-2 text-2xl font-bold text-foreground">
                {kpi.value}
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                {kpi.description}
              </p>
            </div>
          );
        })}
      </div>

      {/* Phân hệ */}
      <section>
        <h2 className="text-base font-semibold tracking-tight text-foreground">
          {vi.property.modulesTitle}
        </h2>
        <p className="mt-0.5 text-sm text-muted-foreground">
          {vi.property.modulesDescription}
        </p>

        <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {modules.map((module) => {
            const Icon = module.icon;
            return (
              <Link
                key={module.title}
                href={module.href}
                className="group flex flex-col justify-between rounded-xl border bg-card p-5 shadow-sm transition-all hover:border-brand/50 hover:shadow-md"
              >
                <div>
                  <span
                    className={`flex h-10 w-10 items-center justify-center rounded-lg ${module.tileClassName}`}
                  >
                    <Icon className="size-5" aria-hidden />
                  </span>
                  <h3 className="mt-3 font-semibold text-foreground group-hover:text-brand">
                    {module.title}
                  </h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                    {module.description}
                  </p>
                </div>
                <span className="mt-4 flex items-center gap-1 text-sm font-medium text-brand">
                  {vi.property.openNow}
                  <ArrowRight
                    className="size-4 transition-transform group-hover:translate-x-0.5"
                    aria-hidden
                  />
                </span>
              </Link>
            );
          })}
        </div>
      </section>

      {/* Bảo mật */}
      <section className="rounded-xl border bg-card p-6 shadow-sm">
        <h2 className="text-base font-semibold text-foreground">
          {vi.property.securityTitle}
        </h2>
        <div className="mt-4 grid grid-cols-1 gap-4 text-sm text-muted-foreground sm:grid-cols-3">
          {securityItems.map((item) => (
            <div key={item.title} className="flex items-start gap-2">
              <CheckCircle2
                className="mt-0.5 size-4 shrink-0 text-emerald-600"
                aria-hidden
              />
              <div>
                <p className="font-medium text-foreground">{item.title}</p>
                <p className="mt-0.5 leading-relaxed">{item.description}</p>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
