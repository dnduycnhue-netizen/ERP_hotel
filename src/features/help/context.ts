/**
 * Ngữ cảnh hướng dẫn: từ đường dẫn màn hình suy ra "mục" để gợi ý bài liên quan.
 * File này KHÔNG import nội dung bài (để component client nhẹ); danh sách bài của
 * từng mục ở `lib.ts` (chạy phía server).
 */
export const HELP_SECTIONS = [
  "procurement",
  "receiving",
  "inventory",
  "count",
  "waste",
  "locks",
  "finance",
  "restaurant",
  "minibar",
  "trolley",
  "reports",
  "master",
] as const;

export type HelpSection = (typeof HELP_SECTIONS)[number];

export function isHelpSection(value: string | undefined): value is HelpSection {
  return (HELP_SECTIONS as readonly string[]).includes(value ?? "");
}

/** Đường dẫn → mục hướng dẫn (desktop `/<p>/...` và mobile `/m/<p>/...`). */
export function helpSectionForPath(pathname: string): HelpSection | null {
  const seg = pathname.split("/").filter(Boolean);
  if (seg[0] === "m") {
    const area = seg[2];
    if (area === "receive") return "receiving";
    if (area === "count") return "count";
    if (area === "trolley") return "trolley";
    if (area === "minibar") return "minibar";
    if (area === "restaurant") return "restaurant";
    return null;
  }
  const area = seg[1];
  const sub = seg[2];
  switch (area) {
    case "procurement":
      return "procurement";
    case "receiving":
      return "receiving";
    case "inventory":
      if (sub === "counts") return "count";
      if (sub === "waste") return "waste";
      if (sub === "locks") return "locks";
      if (sub === "receipts") return "receiving";
      return "inventory";
    case "finance":
      return "finance";
    case "restaurant":
      return "restaurant";
    case "frontdesk":
      return "minibar";
    case "housekeeping":
      return sub === "trolleys" ? "trolley" : "minibar";
    case "reports":
    case "alerts":
      return "reports";
    case "master":
      return "master";
    default:
      return null;
  }
}
