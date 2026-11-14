import { HelpIndex } from "@/components/help/help-index";
import { isHelpSection } from "@/features/help/context";
import {
  suggestedItems,
  toListItems,
  visibleArticles,
} from "@/features/help/lib";
import { vi } from "@/i18n/vi";
import {
  getModuleAwarePermissions,
  getPropertyModules,
} from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";

/** Hướng dẫn trên điện thoại (Q280): cùng nội dung với bản máy tính. */
export default async function MobileHelpIndexPage({
  params,
  searchParams,
}: {
  params: Promise<{ p: string }>;
  searchParams: Promise<{ ctx?: string }>;
}) {
  const { p: propertyId } = await params;
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
      <p className="text-sm text-muted-foreground">{vi.help.intro}</p>
      <HelpIndex
        basePath={`/m/${propertyId}/help`}
        items={items}
        suggested={suggested}
      />
    </div>
  );
}
