/**
 * Mô hình nội dung Trung tâm hướng dẫn (Q279).
 * Nội dung nằm ở `src/i18n/help/*` (được miễn luật chuỗi tiếng Việt của ESLint,
 * cùng chỗ với vi.ts) để chuẩn bị bản tiếng Anh sau này.
 */
export type HelpKind = "role" | "module" | "workflow" | "sop" | "rule";

/** Phân hệ của bài viết — bài của module đang tắt ở khách sạn sẽ bị ẩn. */
export type HelpModule = "core" | "restaurant" | "hk_frontdesk";

export type HelpTone = "info" | "warn" | "rule";

export type HelpStep = {
  /** Ai làm (tên vai trò hiển thị, ví dụ "Thu mua & Thủ kho"). */
  who?: string;
  /** Nội dung bước; hỗ trợ **in đậm**. */
  text: string;
  /** Đường dẫn màn hình (không có tiền tố khách sạn), ví dụ "/procurement/po". */
  href?: string;
};

export type HelpBlock =
  | { t: "h"; text: string }
  | { t: "p"; text: string }
  | { t: "ul"; items: string[] }
  | { t: "steps"; items: HelpStep[] }
  | { t: "note"; tone: HelpTone; text: string }
  | { t: "table"; head: string[]; rows: string[][] };

export type HelpArticle = {
  /** Định danh dùng trong URL: /help/<slug>. Duy nhất. */
  slug: string;
  kind: HelpKind;
  title: string;
  summary: string;
  module: HelpModule;
  /**
   * Mã quyền liên quan: người dùng có ÍT NHẤT MỘT quyền thì bài được đánh dấu
   * "Dành cho bạn" (kiểm bằng quyền, không so tên vai trò — AGENTS.md quy tắc 10).
   */
  perms: string[];
  /** slug các bài liên quan. */
  related: string[];
  blocks: HelpBlock[];
};

export const HELP_KIND_ORDER: HelpKind[] = [
  "role",
  "module",
  "workflow",
  "sop",
  "rule",
];

/**
 * Dựng bài SOP theo khung chuẩn: Mục đích → Phạm vi → Vai trò → Điều kiện
 * → Các bước → Kiểm soát/bằng chứng → Lỗi thường gặp.
 */
export function sop(input: {
  slug: string;
  title: string;
  summary: string;
  module: HelpModule;
  perms: string[];
  related: string[];
  purpose: string;
  scope: string;
  roles: string[];
  prerequisites: string[];
  steps: HelpStep[];
  controls: string[];
  mistakes: string[];
}): HelpArticle {
  return {
    slug: input.slug,
    kind: "sop",
    title: input.title,
    summary: input.summary,
    module: input.module,
    perms: input.perms,
    related: input.related,
    blocks: [
      { t: "h", text: "Mục đích" },
      { t: "p", text: input.purpose },
      { t: "h", text: "Phạm vi áp dụng" },
      { t: "p", text: input.scope },
      { t: "h", text: "Ai thực hiện" },
      { t: "ul", items: input.roles },
      { t: "h", text: "Điều kiện trước khi làm" },
      { t: "ul", items: input.prerequisites },
      { t: "h", text: "Các bước" },
      { t: "steps", items: input.steps },
      { t: "h", text: "Kiểm soát và bằng chứng" },
      { t: "ul", items: input.controls },
      { t: "h", text: "Lỗi thường gặp" },
      { t: "ul", items: input.mistakes },
    ],
  };
}

/** ---- Sơ đồ luồng (swimlane) hiển thị đầu bài (Q281) ---- */
export type FlowNodeKind = "step" | "decision" | "start" | "end" | "system";

export type FlowNode = {
  id: string;
  /** Hàng bơi (người/bộ phận làm) — chỉ số trong `lanes`. */
  lane: number;
  /** Cột theo thứ tự thời gian (trái → phải). */
  col: number;
  label: string;
  kind?: FlowNodeKind;
  /** Trạng thái chứng từ sau bước này (nhãn nhỏ dưới ô). */
  status?: string;
};

export type FlowEdge = {
  from: string;
  to: string;
  label?: string;
  /** "bad" = nhánh từ chối/lỗi (nét đứt, màu đỏ). */
  tone?: "ok" | "bad";
};

export type FlowDiagram = {
  title: string;
  /** Tên các hàng bơi, theo thứ tự từ trên xuống. */
  lanes: string[];
  nodes: FlowNode[];
  edges: FlowEdge[];
};

/**
 * Dựng sơ đồ gọn: nút `[id, lane, col, label, kind?, status?]`,
 * cạnh `[from, to, label?, tone?]`.
 */
export function flow(
  title: string,
  lanes: string[],
  nodes: Array<
    [string, number, number, string, FlowNodeKind?, string?]
  >,
  edges: Array<[string, string, string?, ("ok" | "bad")?]>,
): FlowDiagram {
  return {
    title,
    lanes,
    nodes: nodes.map(([id, lane, col, label, kind, status]) => ({
      id,
      lane,
      col,
      label,
      kind,
      status,
    })),
    edges: edges.map(([from, to, label, tone]) => ({ from, to, label, tone })),
  };
}
