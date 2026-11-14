import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { EmptyState } from "@/components/common/empty-state";
import { HelpArticleView } from "@/components/help/help-article-view";
import { PageHeader } from "@/components/shell/page-header";
import { findArticle, visibleArticles } from "@/features/help/lib";
import { vi } from "@/i18n/vi";
import { getPropertyModules } from "@/lib/modules/server";
import { createClient } from "@/lib/supabase/server";

/** 1 bài hướng dẫn. Bài của module đang tắt ở khách sạn hiện như không tìm thấy. */
export default async function HelpArticlePage({
  params,
}: {
  params: Promise<{ property: string; slug: string }>;
}) {
  const { property: propertyId, slug } = await params;
  const supabase = await createClient();
  const modules = await getPropertyModules(supabase, propertyId);
  const visible = visibleArticles(modules);
  const article = findArticle(slug);

  if (!article || !visible.some((a) => a.slug === article.slug)) {
    return (
      <div className="flex flex-col gap-4">
        <Link
          href={`/${propertyId}/help`}
          className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:underline"
        >
          <ArrowLeft className="size-4" aria-hidden />
          {vi.help.backToList}
        </Link>
        <EmptyState title={vi.help.notFoundTitle} />
      </div>
    );
  }

  const related = article.related
    .map((s) => visible.find((a) => a.slug === s))
    .filter((a): a is NonNullable<typeof a> => a !== undefined);

  return (
    <div className="flex flex-col gap-4">
      <Link
        href={`/${propertyId}/help`}
        className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:underline"
      >
        <ArrowLeft className="size-4" aria-hidden />
        {vi.help.backToList}
      </Link>
      <PageHeader
        title={article.title}
        description={`${vi.help.kinds[article.kind]} · ${article.summary}`}
      />
      <HelpArticleView article={article} propertyId={propertyId} />
      {related.length > 0 ? (
        <section className="max-w-3xl space-y-2 border-t pt-4">
          <h2 className="text-sm font-semibold">{vi.help.related}</h2>
          <ul className="flex flex-wrap gap-2">
            {related.map((r) => (
              <li key={r.slug}>
                <Link
                  href={`/${propertyId}/help/${r.slug}`}
                  className="inline-flex min-h-9 items-center rounded-full border px-3.5 text-sm hover:bg-muted"
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
