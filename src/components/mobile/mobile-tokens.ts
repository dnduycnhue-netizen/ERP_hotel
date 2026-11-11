/**
 * Design tokens dùng chung cho màn hình hiện trường `/m` (W1).
 *
 * Nguồn sự thật duy nhất cho các giá trị "mobile" để các màn W2/W3/W4
 * không tự chế số lẻ: touch target tối thiểu 44px (Tailwind `min-h-11`),
 * cỡ chữ cơ bản 16px (`text-base` — cũng là ngưỡng iOS không tự zoom
 * khi focus input), nút chính đen #171717 (= `bg-primary` của theme,
 * dùng `Button` mặc định), accent tím ClickUp #7B68EE (= `--brand`,
 * class `text-brand` / `bg-brand` đã có trong `globals.css`).
 *
 * Pill trạng thái KHÔNG định nghĩa lại ở đây: màn mobile tái dùng
 * `DocStatusBadge` (`@/components/common/doc-status-badge`) như desktop.
 */
export const mobileTokens = {
  /** Touch target tối thiểu 44px — áp cho mọi nút/link bấm được. */
  touchTarget: "min-h-11",
  /** Cỡ chữ cơ bản trên mobile (16px). */
  bodyText: "text-base",
  /** Chữ phụ (nhãn, gợi ý) — không nhỏ hơn 14px trên mobile. */
  secondaryText: "text-sm",
  /** Màu accent tím #7B68EE: nav đang chọn, link, focus ring. */
  accentText: "text-brand",
  accentBg: "bg-brand",
  /** Nút chính đen #171717: `Button` mặc định đã có màu này. */
  primaryButton: "bg-primary text-primary-foreground",
  /** Thẻ nội dung mobile: bo lớn + bóng nhẹ như màn nhận hàng hiện có. */
  card: "rounded-xl border bg-card p-4 shadow-sm",
  /** Khoảng cách dọc chuẩn giữa các khối trong một màn mobile. */
  stackGap: "flex flex-col gap-4",
  /** Khoảng cách dọc chuẩn giữa các trường trong một form mobile. */
  formGap: "flex flex-col gap-3",
} as const;

/**
 * Class dùng chung cho `<input>` / `<select>` native trên mobile — theo
 * tiền lệ `mobile-new-return-form.tsx`: cao 48px (≥ 44px), chữ 16px
 * (iOS không zoom khi focus), viền hiện rõ khi focus.
 */
export const mobileControlClassName =
  "h-12 w-full rounded-lg border bg-background px-3 text-base outline-none focus:border-ring";

/** Class dùng chung cho `<label>` bọc control native trên mobile. */
export const mobileLabelClassName = "flex flex-col gap-1.5 text-sm font-medium";
