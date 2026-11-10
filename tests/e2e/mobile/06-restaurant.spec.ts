import { test, expect, type Page } from "@playwright/test";
import { mobileUrl, requireMobileLive } from "../helpers";
import { RESTAURANT_MOBILE_ROUTES } from "../fixtures/mobile-real-data";
import { expectNoHorizontalOverflow } from "./mobile-helpers";

/**
 * Tang LIVE-DATA (W5) — man nha hang mobile (W4).
 * Chi chay tren may Mac sau khi seed xong (doi dieu phoi vien bao).
 *
 * Route that (Q198 — da khop sau khi W4 merge):
 *   /m/[p]/restaurant/kitchen | /sales | /banquets | /buffet
 * (W4 khong lam route mobile `/dishes` — chon mon nam trong man
 * ghi ban `/sales`; route desktop van co `/dishes`).
 * Neu W4 doi ten, sua RESTAURANT_MOBILE_ROUTES trong
 * tests/e2e/fixtures/mobile-real-data.ts (1 cho) + ghi Q198.
 *
 * Vi route co the chua co tren ban build chay test, moi test tu skip
 * (khong fail) khi server tra 404 — dieu phoi vien khop lai sau khi
 * W4 merge.
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

test.beforeAll(() => {
  requireMobileLive();
});

/** Mo route; tra ve true neu route ton tai (200), false neu 404. */
async function routeExists(page: Page, path: string): Promise<boolean> {
  const response = await page.goto(mobileUrl(path));
  if (response?.status() === 404) return false;
  expect(response?.status(), `GET ${path}`).toBe(200);
  return true;
}

for (const [key, path] of Object.entries(RESTAURANT_MOBILE_ROUTES)) {
  test(`M-K-${key} — màn nhà hàng mobile ${path} tải được ở 390px`, async ({
    page,
  }) => {
    if (!(await routeExists(page, path))) {
      test.skip(
        true,
        `Route W4 ${path} chưa có trên bản build này (404) — khớp lại sau khi W4 merge (Q198).`,
      );
    }
    await expect(page.locator("main")).toBeVisible();
    expect(await page.locator("main h1, main h2").count()).toBeGreaterThan(0);
    await expectNoHorizontalOverflow(page);
  });
}

test("M-K-all — món MON01 (nếu màn món ăn liệt kê món thật)", async ({
  page,
}) => {
  // Chi kiem khi route sales ton tai VA co du lieu mon (MON01 moi chi
  // co trong pgTAP restaurant_test.sql, chua import tu Excel — Q168).
  // Neu chua co mon nao, test skip ro ly do thay vi fail.
  if (!(await routeExists(page, RESTAURANT_MOBILE_ROUTES.sales))) {
    test.skip(
      true,
      "Route W4 /restaurant/sales chưa có trên bản build này (404) — Q198.",
    );
  }
  const body = await page.locator("main").innerText();
  if (!body.includes("MON01") && !body.includes("Cơm gà xối mỡ")) {
    test.skip(
      true,
      "Chưa có món MON01 trên màn mobile — món buffet/alacarte chưa import từ Excel (Q168).",
    );
  }
  await expect(page.getByText("Cơm gà xối mỡ")).toBeVisible();
});
