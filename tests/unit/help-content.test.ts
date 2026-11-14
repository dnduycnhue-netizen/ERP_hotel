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

import { HELP_SECTIONS, helpSectionForPath, isHelpSection } from "@/features/help/context";
import { HELP_SECTION_SLUGS, suggestedItems } from "@/features/help/lib";

describe("Ngữ cảnh hướng dẫn (nút ?)", () => {
  it("đường dẫn desktop/mobile ánh xạ đúng mục", () => {
    const P = "b0000000-0000-4000-8000-000000000002";
    expect(helpSectionForPath(`/${P}/procurement/po`)).toBe("procurement");
    expect(helpSectionForPath(`/${P}/inventory/waste/new`)).toBe("waste");
    expect(helpSectionForPath(`/${P}/inventory/counts`)).toBe("count");
    expect(helpSectionForPath(`/${P}/inventory/locks`)).toBe("locks");
    expect(helpSectionForPath(`/${P}/inventory/receipts`)).toBe("receiving");
    expect(helpSectionForPath(`/${P}/inventory/stock`)).toBe("inventory");
    expect(helpSectionForPath(`/${P}/finance/invoices`)).toBe("finance");
    expect(helpSectionForPath(`/${P}/frontdesk/minibar`)).toBe("minibar");
    expect(helpSectionForPath(`/${P}/housekeeping/trolleys`)).toBe("trolley");
    expect(helpSectionForPath(`/${P}/reports/stock-card`)).toBe("reports");
    expect(helpSectionForPath(`/m/${P}/receive/abc`)).toBe("receiving");
    expect(helpSectionForPath(`/m/${P}/count`)).toBe("count");
    expect(helpSectionForPath(`/m/${P}/minibar/xyz`)).toBe("minibar");
    expect(helpSectionForPath(`/${P}`)).toBeNull();
    expect(helpSectionForPath(`/${P}/help`)).toBeNull();
  });

  it("mỗi mục có danh sách bài, mọi slug tồn tại; isHelpSection chặn giá trị lạ", () => {
    const slugs = new Set(HELP_ARTICLES.map((a) => a.slug));
    for (const section of HELP_SECTIONS) {
      expect(HELP_SECTION_SLUGS[section].length, section).toBeGreaterThan(0);
      for (const s of HELP_SECTION_SLUGS[section]) expect(slugs.has(s), `${section}:${s}`).toBe(true);
    }
    expect(isHelpSection("count")).toBe(true);
    expect(isHelpSection("xyz")).toBe(false);
    expect(isHelpSection(undefined)).toBe(false);
  });

  it("gợi ý giữ thứ tự và bỏ bài của module tắt", () => {
    const off = toListItems(visibleArticles({ restaurant: false, hk_frontdesk: false }), new Set());
    const res = suggestedItems("restaurant", off).map((i) => i.slug);
    expect(res).not.toContain("phan-he-nha-hang");
    expect(res).toContain("quy-tac-gia-von");
    const on = toListItems(visibleArticles({ restaurant: true, hk_frontdesk: true }), new Set());
    expect(suggestedItems("count", on).map((i) => i.slug)[0]).toBe("sop-kiem-ke-cuoi-thang");
  });
});
