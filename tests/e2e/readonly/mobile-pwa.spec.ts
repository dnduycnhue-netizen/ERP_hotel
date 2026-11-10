import { test, expect } from "@playwright/test";
import { mobileUrl, propertyUrl, requireTestUser } from "../helpers";

/**
 * Mobile 390×844 + PWA (T-046): man hien truong /m/*, Dexie offline DB,
 * service worker dang ky + cache shell. Can tai khoan (skip neu thieu).
 */

test.beforeAll(() => {
  requireTestUser();
});

test("M1 — màn nhận hàng mobile hiển thị nhiệm vụ hoặc trạng thái trống", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  const heading = page.getByRole("heading", {
    name: "Nhiệm vụ nhận hàng hôm nay",
  });
  await expect(heading).toBeVisible();
  const body = await page.locator("main").innerText();
  expect(/Không có đơn mua nào đến hạn nhận hôm nay|dòng/.test(body)).toBe(
    true,
  );
});

test("M2 — màn kiểm kê mobile hiển thị đợt hoặc trạng thái trống", async ({
  page,
}) => {
  await page.goto(mobileUrl("/count"));
  await expect(
    page.getByRole("heading", { name: "Đợt kiểm kê" }),
  ).toBeVisible();
});

test("M3 — màn minibar mobile tải được", async ({ page }) => {
  const response = await page.goto(mobileUrl("/minibar"));
  expect(response?.status(), "GET /m/minibar").toBe(200);
  await expect(page.locator("main")).toBeVisible();
  expect(await page.locator("main h1, main h2").count()).toBeGreaterThan(0);
});

test("M4 — Dexie offline DB tồn tại sau khi mở màn hiện trường", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  const databases = (await page.evaluate(() => indexedDB.databases())) as {
    name?: string;
  }[];
  const names = databases.map((d) => d.name);
  expect(names).toContain("erp-hotel-offline");
});

test("M5 — service worker đã đăng ký + cache shell có mặt", async ({
  page,
}) => {
  await page.goto(propertyUrl(""));
  const swState = await page.evaluate(async () => {
    const registration = await navigator.serviceWorker.getRegistration();
    const keys = await caches.keys();
    return {
      registered: Boolean(registration),
      active: Boolean(registration?.active),
      scope: registration?.scope ?? null,
      caches: keys,
    };
  });
  expect(swState.registered, "service worker phai dang ky duoc").toBe(true);
  expect(swState.active, "service worker phai active").toBe(true);
  expect(swState.caches).toContain("erp-shell-v1");
});
