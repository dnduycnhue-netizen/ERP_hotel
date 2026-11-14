import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { HELP_ARTICLES } from "@/i18n/help";
import { HELP_KIND_ORDER } from "@/i18n/help/types";
import { filterListItems, toListItems, visibleArticles } from "@/features/help/lib";

const ALL_ON = { restaurant: true, hk_frontdesk: true };

describe("Trung tâm hướng dẫn: toàn vẹn nội dung", () => {
  it("slug duy nhất, chỉ gồm a-z 0-9 và dấu gạch", () => {
    const slugs = HELP_ARTICLES.map((a) => a.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
    for (const s of slugs) expect(s).toMatch(/^[a-z0-9]+(-[a-z0-9]+)*$/);
  });

  it("mỗi loại có ít nhất 5 bài và có đủ 5 loại", () => {
    for (const kind of HELP_KIND_ORDER) {
      expect(HELP_ARTICLES.filter((a) => a.kind === kind).length).toBeGreaterThanOrEqual(5);
    }
  });

  it("bài viết có tiêu đề, tóm tắt và nội dung; bước/dòng bảng không rỗng", () => {
    for (const a of HELP_ARTICLES) {
      expect(a.title.trim().length, a.slug).toBeGreaterThanOrEqual(3);
      expect(a.summary.trim().length, a.slug).toBeGreaterThan(10);
      expect(a.blocks.length, a.slug).toBeGreaterThan(0);
      for (const b of a.blocks) {
        if (b.t === "steps") {
          expect(b.items.length, a.slug).toBeGreaterThan(0);
          for (const s of b.items) {
            expect(s.text.trim().length, a.slug).toBeGreaterThan(5);
            if (s.href !== undefined && s.href !== "") expect(s.href, a.slug).toMatch(/^\//);
          }
        }
        if (b.t === "table") {
          for (const row of b.rows) expect(row.length, a.slug).toBe(b.head.length);
        }
        if (b.t === "ul") expect(b.items.length, a.slug).toBeGreaterThan(0);
      }
    }
  });

  it("bài liên quan trỏ tới bài có thật và không trỏ về chính nó", () => {
    const slugs = new Set(HELP_ARTICLES.map((a) => a.slug));
    for (const a of HELP_ARTICLES) {
      for (const r of a.related) {
        expect(slugs.has(r), `${a.slug} -> ${r}`).toBe(true);
        expect(r).not.toBe(a.slug);
      }
    }
  });

  it("mã quyền trong bài đều có trong migration (không tham chiếu quyền không tồn tại)", () => {
    const dir = join(process.cwd(), "supabase", "migrations");
    const sql = readdirSync(dir)
      .filter((f) => f.endsWith(".sql"))
      .map((f) => readFileSync(join(dir, f), "utf8"))
      .join("\n");
    const perms = new Set(HELP_ARTICLES.flatMap((a) => a.perms));
    for (const p of perms) expect(sql.includes(`'${p}'`), p).toBe(true);
  });

  it("bài của module nhà hàng/buồng phòng ẩn khi module tắt; bài lõi luôn hiện", () => {
    const off = visibleArticles({ restaurant: false, hk_frontdesk: false });
    expect(off.every((a) => a.module === "core")).toBe(true);
    expect(off.length).toBeLessThan(HELP_ARTICLES.length);
    expect(visibleArticles(ALL_ON).length).toBe(HELP_ARTICLES.length);
  });

  it("đánh dấu 'Dành cho bạn' theo quyền và đưa lên đầu; tìm không dấu từng từ", () => {
    const items = toListItems(visibleArticles(ALL_ON), new Set(["receiving.perform"]));
    const sorted = filterListItems(items, "", "all");
    expect(sorted[0]?.relevant).toBe(true);
    expect(sorted.some((i) => i.slug === "sop-nhan-hang-mu" && i.relevant)).toBe(true);

    const found = filterListItems(items, "nhan hang mu", "all").map((i) => i.slug);
    expect(found).toContain("sop-nhan-hang-mu");
    expect(filterListItems(items, "kiem ke", "sop").every((i) => i.kind === "sop")).toBe(true);
    expect(filterListItems(items, "zzzzkhongco", "all")).toEqual([]);
  });
});
