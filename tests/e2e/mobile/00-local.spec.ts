import { test, expect } from "@playwright/test";
import {
  expectMinTouchTargets,
  expectNoHorizontalOverflow,
} from "./mobile-helpers";

/**
 * Tang LOCAL (W5) — chay duoc tren local build, khong can dang nhap,
 * khong can du lieu. Mobile viewport 390×844 (iPhone 12/13/14).
 * 6 test: L1, L2, L3, L3b, L4, L5.
 *
 * Chay: TEST_BASE_URL=http://localhost:3000 npx playwright test
 *   --project=mobile-local
 * (xem tests/e2e/README.md muc Mobile — W5).
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

// Local build khong co backend that: moi navigation qua middleware +
// layout deu cho Supabase fail (vai giay) — tang timeout mac dinh
// (L3/L3b dat rieng 180s).
// Goto dung "domcontentloaded" thay vi "load" mac dinh: tren VM, su kien
// "load" co luc treo >100s vi response RSC streaming van mo trong khi
// cac cuoc goi Supabase that bai cham — DOM shell (form/meta) da co
// ngay sau khi parse xong HTML.
test.setTimeout(120000);

test("L1 — trang đăng nhập hiển thị đủ form ở 390px", async ({ page }) => {
  await page.goto("/login", { waitUntil: "domcontentloaded" });
  await expect(page.getByRole("heading", { name: "Đăng nhập" })).toBeVisible();
  await expect(page.getByLabel("Email tài khoản")).toBeVisible();
  await expect(page.getByLabel("Mật khẩu")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Đăng nhập", exact: true }),
  ).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test("L2 — meta viewport là device-width (không zoom cố định)", async ({
  page,
}) => {
  await page.goto("/login", { waitUntil: "domcontentloaded" });
  const content = await page
    .locator('meta[name="viewport"]')
    .getAttribute("content");
  expect(content).toContain("width=device-width");
  expect(content).toContain("initial-scale=1");
});

test("L3 — chưa đăng nhập thì mọi màn /m/* chuyển về /login", async ({
  page,
}) => {
  // Moi navigation phai cho layout /m/[p] goi getUser() xong moi redirect
  // — tren local build khong co backend that nen moi lan mat vai giay.
  test.setTimeout(180000);
  const fakeProperty = "00000000-0000-4000-8000-000000000099";
  for (const path of [
    `/m/${fakeProperty}/receive`,
    `/m/${fakeProperty}/count`,
    `/m/${fakeProperty}/trolley`,
    `/m/${fakeProperty}/minibar`,
  ]) {
    await page.goto(path, { waitUntil: "commit" });
    await expect(page).toHaveURL(/\/login/, { timeout: 60000 });
  }
});

test("L3b — route nhà hàng chưa có thì 404, có rồi thì chuyển về /login", async ({
  page,
}) => {
  // Route mobile nha hang la gia dinh (W4 chua merge — Q198): neu route
  // chua ton tai, Next tra trang 404 thay vi chay layout auth (khong
  // redirect); neu W4 da co route, hanh vi phai giong 4 man tren.
  test.setTimeout(180000);
  const fakeProperty = "00000000-0000-4000-8000-000000000099";
  for (const path of [
    `/m/${fakeProperty}/restaurant/kitchen`,
    `/m/${fakeProperty}/restaurant/dishes`,
  ]) {
    await page.goto(path, { waitUntil: "commit" });
    const outcome = await Promise.race([
      page
        .waitForURL(/\/login/, { timeout: 60000 })
        .then(() => "login" as const)
        .catch(() => "pending" as const),
      page
        .getByRole("heading", { name: "Không tìm thấy trang" })
        .waitFor({ timeout: 60000 })
        .then(() => "not-found" as const)
        .catch(() => "pending" as const),
    ]);
    expect(outcome, `${path} phai redirect /login hoac 404 trong 60s`).not.toBe(
      "pending",
    );
  }
});

test("L4 — trang /offline hiển thị được ở 390px, không tràn ngang", async ({
  page,
}) => {
  await page.goto("/offline", { waitUntil: "domcontentloaded" });
  const main = page.locator("main");
  await expect(main).toBeVisible();
  await expect(main).not.toBeEmpty();
  await expectNoHorizontalOverflow(page);
});

test("L5 — form đăng nhập đủ lớn để chạm (tối thiểu 24px, mục tiêu 44px)", async ({
  page,
}) => {
  await page.goto("/login", { waitUntil: "domcontentloaded" });
  await expectMinTouchTargets(page);
  // Ghi nhan so do that (khong ep 44px — nut submit shadcn h-10 = 40px,
  // duoi guideline 44px; thuoc pham vi workstream UI, xem bao cao W5).
  const sizes = await page.evaluate(() => {
    const out: Record<string, number> = {};
    for (const el of document.querySelectorAll("main input, main button")) {
      const html = el as HTMLElement;
      const key =
        html.tagName.toLowerCase() +
        ":" +
        (html.getAttribute("aria-label") ??
          html.textContent?.trim().slice(0, 20) ??
          "");
      out[key] = Math.round(html.getBoundingClientRect().height);
    }
    return out;
  });
  for (const height of Object.values(sizes)) {
    expect(height).toBeGreaterThanOrEqual(24);
  }
});
