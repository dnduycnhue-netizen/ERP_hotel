import { HELP_ARTICLES } from "@/i18n/help";
import {
  HELP_KIND_ORDER,
  type HelpArticle,
  type HelpKind,
} from "@/i18n/help/types";
import { normalizeSearch, searchWords } from "@/lib/text/normalize";

export type HelpListItem = {
  slug: string;
  kind: HelpKind;
  title: string;
  summary: string;
  /** Người dùng có quyền liên quan tới bài này. */
  relevant: boolean;
};

/** Bài hiển thị cho khách sạn: bỏ bài của module đang tắt. */
export function visibleArticles(modules: {
  restaurant: boolean;
  hk_frontdesk: boolean;
}): HelpArticle[] {
  return HELP_ARTICLES.filter(
    (a) => a.module === "core" || modules[a.module] === true,
  );
}

export function isRelevant(
  article: HelpArticle,
  permissions: ReadonlySet<string>,
): boolean {
  return article.perms.some((p) => permissions.has(p));
}

export function toListItems(
  articles: HelpArticle[],
  permissions: ReadonlySet<string>,
): HelpListItem[] {
  return articles.map((a) => ({
    slug: a.slug,
    kind: a.kind,
    title: a.title,
    summary: a.summary,
    relevant: isRelevant(a, permissions),
  }));
}

/** Tìm theo từng từ, không dấu, trên tiêu đề + tóm tắt. */
export function filterListItems(
  items: HelpListItem[],
  query: string,
  kind: HelpKind | "all",
): HelpListItem[] {
  const words = searchWords(query);
  return items
    .filter((i) => kind === "all" || i.kind === kind)
    .filter((i) => {
      if (words.length === 0) return true;
      const hay = normalizeSearch(`${i.title} ${i.summary}`);
      return words.every((w) => hay.includes(w));
    })
    .sort((a, b) => {
      if (a.relevant !== b.relevant) return a.relevant ? -1 : 1;
      return (
        HELP_KIND_ORDER.indexOf(a.kind) - HELP_KIND_ORDER.indexOf(b.kind)
      );
    });
}

export function findArticle(slug: string): HelpArticle | undefined {
  return HELP_ARTICLES.find((a) => a.slug === slug);
}
