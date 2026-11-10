import type { Page } from "@playwright/test";
import { expect } from "@playwright/test";

/**
 * Helper dung chung cho spec mobile (W5).
 *
 * - Khong tran ngang: viewport 390px — noi dung khong duoc rong hon
 *   cua so (nguoi dung hien truong khong keo ngang bang 1 tay).
 * - Dich cham: WCAG 2.5.8 toi thieu 24px; muc tieu thiet ke 44px
 *   (Apple HIG) chi ap cho nut hanh dong chinh / dong danh sach.
 *   Ghi chu: nut submit form dang nhap + link MobileNav hien chi
 *   ~32–40px — duoi 44px, ghi nhan o bao cao W5, khong ep test fail
 *   vi do la quyet dinh cua workstream UI (W1).
 */

/** Trang khong co thanh cuon ngang o viewport hien tai. */
export async function expectNoHorizontalOverflow(page: Page): Promise<void> {
  const overflow = await page.evaluate(() => ({
    scrollWidth: document.documentElement.scrollWidth,
    innerWidth: window.innerWidth,
  }));
  expect(
    overflow.scrollWidth,
    `tran ngang: scrollWidth ${overflow.scrollWidth} > innerWidth ${overflow.innerWidth}`,
  ).toBeLessThanOrEqual(overflow.innerWidth);
}

/**
 * Tat ca phan tu tuong tac thay duoc trong `main` dat toi thieu
 * 24×24px (WCAG 2.5.8 AA). Bo qua phan tu an (offsetParent null)
 * va phan tu bi vo hieu hoa.
 */
export async function expectMinTouchTargets(page: Page): Promise<void> {
  const small = await page.evaluate(() => {
    const bad: string[] = [];
    for (const el of document.querySelectorAll(
      "main a, main button, main input, main select",
    )) {
      const html = el as HTMLElement;
      if (html.offsetParent === null) continue;
      if ((html as HTMLButtonElement).disabled) continue;
      const r = html.getBoundingClientRect();
      if (r.width > 0 && (r.width < 24 || r.height < 24)) {
        bad.push(
          `${el.tagName.toLowerCase()}.${(html.className as string)
            .toString()
            .slice(0, 60)} ${Math.round(r.width)}x${Math.round(r.height)}`,
        );
      }
    }
    return bad;
  });
  expect(small, `phan tu tuong tac nho hon 24px: ${small.join("; ")}`).toEqual(
    [],
  );
}
