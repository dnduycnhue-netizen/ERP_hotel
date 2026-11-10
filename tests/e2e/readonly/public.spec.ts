import { test, expect } from "@playwright/test";

/**
 * Tang doc, khong can dang nhap: trang cong khai + tai nguyen PWA.
 * Chay duoc ngay tren VM (khong can tai khoan).
 */

test("P1 — trang đăng nhập hiển thị form", async ({ page }) => {
  await page.goto("/login");
  await expect(page.getByRole("heading", { name: "Đăng nhập" })).toBeVisible();
  await expect(page.getByLabel("Email tài khoản")).toBeVisible();
  await expect(page.getByLabel("Mật khẩu")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Đăng nhập", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByText("Dùng tài khoản được quản trị viên cấp"),
  ).toBeVisible();
});

test("P2 — chưa đăng nhập thì / chuyển về /login", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveURL(/\/login/);
  await expect(page.getByRole("heading", { name: "Đăng nhập" })).toBeVisible();
});

test("P3 — manifest hợp lệ, đủ icon PWA", async ({ request }) => {
  const res = await request.get("/manifest.webmanifest");
  expect(res.status()).toBe(200);
  const manifest = (await res.json()) as {
    name?: string;
    short_name?: string;
    display?: string;
    start_url?: string;
    icons?: { src: string; sizes: string; purpose?: string }[];
  };
  expect(manifest.name).toBe("Mini-ERP Chuỗi khách sạn");
  expect(manifest.short_name).toBe("Mini-ERP");
  expect(manifest.display).toBe("standalone");
  expect(manifest.start_url).toBe("/");
  const icons = manifest.icons ?? [];
  expect(icons.some((i) => i.sizes === "192x192")).toBe(true);
  expect(icons.some((i) => i.sizes === "512x512")).toBe(true);
  expect(icons.some((i) => i.purpose === "maskable")).toBe(true);
  for (const icon of icons) {
    const iconRes = await request.get(icon.src);
    expect(iconRes.status(), `icon ${icon.src}`).toBe(200);
  }
});

test("P4 — service worker phục vụ được, đúng cache shell", async ({
  request,
}) => {
  const res = await request.get("/sw.js");
  expect(res.status()).toBe(200);
  const body = await res.text();
  // Ten cache ghep tu template (`erp-shell-${CACHE_VERSION}`) nen chi
  // khang dinh duoc tien to + CACHE_VERSION, khong phai chuoi day du.
  expect(body).toContain("erp-shell-");
  expect(body).toContain("erp-pages-");
  expect(body).toContain('CACHE_VERSION = "v1"');
  expect(body).toContain("/manifest.webmanifest");
});

test("P5 — trang /offline hiển thị được", async ({ page }) => {
  await page.goto("/offline");
  const main = page.locator("main");
  await expect(main).toBeVisible();
  await expect(main).not.toBeEmpty();
});
