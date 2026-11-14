import { HELP_ARTICLES } from "@/i18n/help";
import {
  HELP_KIND_ORDER,
  type HelpArticle,
  type HelpKind,
} from "@/i18n/help/types";
import { normalizeSearch, searchWords } from "@/lib/text/normalize";
import type { HelpSection } from "./context";

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

/** Bài gợi ý cho từng mục màn hình (nút "?" trên khung). */
export const HELP_SECTION_SLUGS: Record<HelpSection, string[]> = {
  procurement: ["phan-he-thu-mua", "luong-mua-hang-nhan-thanh-toan", "luong-mua-cho-va-tam-ung", "sop-duyet-chung-tu", "quy-tac-gia-tran-gia-tay"],
  receiving: ["sop-nhan-hang-mu", "vai-tro-nhan-hang", "phan-he-nhan-hang", "quy-tac-dung-sai-can-lai", "quy-tac-anh-bang-chung"],
  inventory: ["phan-he-kho", "luong-linh-kho-dieu-chuyen-huy", "quy-tac-so-cai-bat-bien", "quy-tac-gia-von"],
  count: ["sop-kiem-ke-cuoi-thang", "luong-kiem-ke-thang", "phan-he-kiem-ke", "quy-tac-nhan-hang-mu-dem-mu"],
  waste: ["sop-huy-hang", "luong-linh-kho-dieu-chuyen-huy", "quy-tac-anh-bang-chung"],
  locks: ["sop-khoa-ngay-ky", "quy-tac-khoa-so-ngay-nghiep-vu"],
  finance: ["phan-he-tai-chinh", "sop-thanh-toan-ncc", "quy-tac-doi-chieu-3-ben", "vai-tro-ke-toan"],
  restaurant: ["phan-he-nha-hang", "luong-ban-hang-nha-hang", "vai-tro-bep-nha-hang", "quy-tac-gia-von"],
  minibar: ["phan-he-buong-phong-minibar", "luong-minibar-tinh-tien", "sop-kiem-minibar-tra-phong", "quy-tac-minibar-doi-soat"],
  trolley: ["sop-ca-xe-day", "vai-tro-buong-phong", "phan-he-buong-phong-minibar"],
  reports: ["phan-he-bao-cao-canh-bao", "quy-tac-khoa-so-ngay-nghiep-vu"],
  master: ["phan-he-danh-muc", "quy-tac-gia-tran-gia-tay", "quy-tac-phan-quyen-theo-quyen"],
};

/** Danh sách mục tiêu cho nút "?": giữ thứ tự gợi ý, chỉ lấy bài đang hiển thị. */
export function suggestedItems(
  section: HelpSection,
  items: HelpListItem[],
): HelpListItem[] {
  const bySlug = new Map(items.map((i) => [i.slug, i]));
  return HELP_SECTION_SLUGS[section]
    .map((s) => bySlug.get(s))
    .filter((i): i is HelpListItem => i !== undefined);
}
