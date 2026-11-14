import { HelpIndex } from "@/components/help/help-index";
import { PageHeader } from "@/components/shell/page-header";
import { isHelpSection } from "@/features/help/context";
import { suggestedItems, toListItems, visibleArticles } from "@/features/help/lib";
import { vi } from "@/i18n/vi";
import { getModuleAwarePermissions, getPropertyModules } from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";

/** Trung tâm hướng dẫn: theo vai trò, phân hệ, luồng nghiệp vụ, SOP, quy tắc (Q279). */
export default async function HelpIndexPage({
  params,
  searchParams,
}: {
  params: Promise<{ property: string }>;
  searchParams: Promise<{ ctx?: string }>;
}) {
  const { property: propertyId } = await params;
  const { ctx } = await searchParams;
  const supabase = await createClient();
  const [modules, perms] = await Promise.all([
    getPropertyModules(supabase, propertyId),
    getModuleAwarePermissions(supabase, propertyId),
  ]);
  const items = toListItems(visibleArticles(modules), new Set(perms));
  const suggested = isHelpSection(ctx) ? suggestedItems(ctx, items) : [];

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={vi.help.title} description={vi.help.intro} />
      <HelpIndex
        basePath={`/${propertyId}/help`}
        items={items}
        suggested={suggested}
      />
      <p className="max-w-3xl text-xs text-muted-foreground">
        {vi.help.disclaimer}
      </p>
    </div>
  );
}
