import { MODULE_ARTICLES } from "./modules";
import { ROLE_ARTICLES } from "./roles";
import { RULE_ARTICLES } from "./rules";
import { SOP_ARTICLES } from "./sops";
import type { HelpArticle } from "./types";
import { WORKFLOW_ARTICLES } from "./workflows";

/** Toàn bộ bài hướng dẫn — gom từ các file theo loại. */
export const HELP_ARTICLES: HelpArticle[] = [
  ...ROLE_ARTICLES,
  ...MODULE_ARTICLES,
  ...WORKFLOW_ARTICLES,
  ...SOP_ARTICLES,
  ...RULE_ARTICLES,
];
