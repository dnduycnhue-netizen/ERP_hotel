import { test, expect } from "@playwright/test";
import {
  LIVE_PROPERTY_ID,
  expectNoPageError,
  propertyUrl,
  requireTestUser,
} from "../helpers";

/**
 * Smoke tang doc (owner): tong quan + dieu huong cac khu chinh.
 * Chi GET — khong ghi du lieu. Can tai khoan (skip neu thieu env).
 */

test.beforeAll(() => {
  requireTestUser();
});

test("S1 — trang tổng quan hiển thị tên khách sạn", async ({ page }) => {
  await page.goto(propertyUrl(""));
  await expect(
    page.getByRole("heading", { name: "Son Hoi An Boutique Hotel & Spa" }),
  ).toBeVisible();
  await expect(page.getByText("Đang hoạt động")).toBeVisible();
  await expect(page.getByText("Mã khách sạn:")).toBeVisible();
  // Trang tong quan hien cach dinh gia cua phap nhan (Q58: FIFO se loi
  // minibar) — ghi nhan de doi chieu, khong ep 1 gia tri cu the.
  const costing = page.getByText(/Bình quân gia quyền|FIFO/);
  await expect(costing).toBeVisible();
  await expectNoPageError(page);
});

test("S2 — header có đủ link điều hướng các khu", async ({ page }) => {
  await page.goto(propertyUrl(""));
  const header = page.locator("header");
  await expect(header).toBeVisible();
  const links = header.locator("a[href]");
  expect(await links.count()).toBeGreaterThanOrEqual(8);
  // Link nhan hang (desktop) tro ve danh sach phieu tra — da kiem chung.
  await expect(
    header.locator(`a[href="/${LIVE_PROPERTY_ID}/receiving/returns"]`),
  ).toBeVisible();
  await expect(header.locator(`a[href="/${LIVE_PROPERTY_ID}"]`)).toBeVisible();
});

const SECTIONS: { path: string; heading?: string }[] = [
  { path: "/procurement" },
  { path: "/receiving/returns" },
  { path: "/inventory" },
  { path: "/inventory/stock", heading: "Tồn kho" },
  { path: "/finance" },
  { path: "/reports" },
  { path: "/alerts", heading: "Lịch sử cảnh báo & gửi thông báo" },
  { path: "/frontdesk/minibar" },
  { path: "/housekeeping/minibar" },
  { path: "/frontdesk/pms-daily" },
  { path: "/master/items" },
  { path: "/admin/roles" },
];

for (const section of SECTIONS) {
  test(`S3 — khu ${section.path} tải được`, async ({ page }) => {
    const response = await page.goto(propertyUrl(section.path));
    expect(response?.status(), `GET ${section.path}`).toBe(200);
    await expect(page.locator("main")).toBeVisible();
    if (section.heading) {
      await expect(
        page.getByRole("heading", { name: section.heading }),
      ).toBeVisible();
    } else {
      expect(await page.locator("main h1, main h2").count()).toBeGreaterThan(0);
    }
    await expectNoPageError(page);
  });
}
