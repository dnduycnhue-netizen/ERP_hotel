import Link from "next/link";
import { EmptyState } from "@/components/common/empty-state";
import { HelpArticleView } from "@/components/help/help-article-view";
import { findArticle, visibleArticles } from "@/features/help/lib";
import { vi } from "@/i18n/vi";
import { getPropertyModules } from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";

/** 1 bài hướng dẫn trên điện thoại. */
export default async function MobileHelpArticlePage({
  params,
}: {
  params: Promise<{ p: string; slug: string }>;
}) {
  const { p: propertyId, slug } = await params;
  const supabase = await createClient();
  const modules = await getPropertyModules(supabase, propertyId);
  const visible = visibleArticles(modules);
  const article = findArticle(slug);

  if (!article || !visible.some((a) => a.slug === article.slug)) {
    return <EmptyState title={vi.help.notFoundTitle} />;
  }

  const related = article.related
    .map((s) => visible.find((a) => a.slug === s))
    .filter((a): a is NonNullable<typeof a> => a !== undefined);

  return (
    <div className="flex flex-col gap-4">
      <div>
        <p className="text-xs font-medium text-muted-foreground">
          {vi.help.kinds[article.kind]}
        </p>
        <h2 className="text-xl font-semibold tracking-tight">{article.title}</h2>
        <p className="mt-1 text-sm text-muted-foreground">{article.summary}</p>
      </div>
      <HelpArticleView
        article={article}
        propertyId={propertyId}
        showLinks={false}
      />
      {related.length > 0 ? (
        <section className="space-y-2 border-t pt-4">
          <h3 className="text-sm font-semibold">{vi.help.related}</h3>
          <ul className="flex flex-wrap gap-2">
            {related.map((r) => (
              <li key={r.slug}>
                <Link
                  href={`/m/${propertyId}/help/${r.slug}`}
                  className="inline-flex min-h-11 items-center rounded-full border px-4 text-sm hover:bg-muted"
                >
                  {r.title}
                </Link>
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  );
}
