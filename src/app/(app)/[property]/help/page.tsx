import { HelpIndex } from "@/components/help/help-index";
import { PageHeader } from "@/components/shell/page-header";
import { toListItems, visibleArticles } from "@/features/help/lib";
import { vi } from "@/i18n/vi";
import { getModuleAwarePermissions, getPropertyModules } from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";

/** Trung tâm hướng dẫn: theo vai trò, phân hệ, luồng nghiệp vụ, SOP, quy tắc (Q279). */
export default async function HelpIndexPage({
  params,
}: {
  params: Promise<{ property: string }>;
}) {
  const { property: propertyId } = await params;
  const supabase = await createClient();
  const [modules, perms] = await Promise.all([
    getPropertyModules(supabase, propertyId),
    getModuleAwarePermissions(supabase, propertyId),
  ]);
  const items = toListItems(visibleArticles(modules), new Set(perms));

  return (
    <div className="flex flex-col gap-4">
      <PageHeader title={vi.help.title} description={vi.help.intro} />
      <HelpIndex propertyId={propertyId} items={items} />
      <p className="max-w-3xl text-xs text-muted-foreground">
        {vi.help.disclaimer}
      </p>
    </div>
  );
}
