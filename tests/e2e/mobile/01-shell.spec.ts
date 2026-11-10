import { test, expect } from "@playwright/test";
import { TEST_PROPERTY_ID, mobileUrl, requireMobileLive } from "../helpers";
import { TEST_SEED } from "../fixtures/real-data";
import {
  expectMinTouchTargets,
  expectNoHorizontalOverflow,
} from "./mobile-helpers";

/**
 * Tang LIVE-DATA (W5) — shell /m/[p] (W1). Chi chay tren may Mac
 * sau khi seed xong (doi dieu phoi vien bao).
 *
 * Dieu kien: TEST_PROPERTY_ID=<id TEST47> + TEST_USER_EMAIL/TEST_USER_PASSWORD
 * (email TEST02: outlet_head + receiver) — xem tests/e2e/README.md.
 * Tren VM test nay skip (thieu env).
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

test.beforeAll(() => {
  requireMobileLive();
});

test("M-S1 — shell mobile: header hiện tên khách sạn test", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  await expect(
    page.getByRole("heading", { name: "Nhiệm vụ nhận hàng hôm nay" }),
  ).toBeVisible();
  // Header layout /m/[p]: ten app (link ve receive) + ten khach san.
  await expect(page.getByText(TEST_SEED.propertyName)).toBeVisible();
  await expectNoHorizontalOverflow(page);
});

test("M-S2 — MobileNav: link Nhận hàng có mặt (TEST02 có receiving.view)", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  const nav = page.locator("nav");
  await expect(nav).toBeVisible();
  await expect(
    nav.getByRole("link", { name: "Nhiệm vụ nhận hàng hôm nay" }),
  ).toBeVisible();
  // Moi link nav deu tro ve dung property test.
  const hrefs = await nav
    .locator("a")
    .evaluateAll((els) => els.map((el) => el.getAttribute("href") ?? ""));
  expect(hrefs.length).toBeGreaterThan(0);
  for (const href of hrefs) {
    expect(href.startsWith(`/m/${TEST_PROPERTY_ID}/`)).toBe(true);
  }
});

test("M-S3 — shell không tràn ngang, phần tử chạm ≥ 24px", async ({ page }) => {
  await page.goto(mobileUrl("/receive"));
  await expect(
    page.getByRole("heading", { name: "Nhiệm vụ nhận hàng hôm nay" }),
  ).toBeVisible();
  await expectNoHorizontalOverflow(page);
  await expectMinTouchTargets(page);
});

test("M-S4 — Dexie offline DB tồn tại sau khi mở màn hiện trường", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  const databases = (await page.evaluate(() => indexedDB.databases())) as {
    name?: string;
  }[];
  expect(databases.map((d) => d.name)).toContain("erp-hotel-offline");
});
