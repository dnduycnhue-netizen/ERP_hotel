import { test, expect } from "@playwright/test";
import {
  mobileUrl,
  propertyUrl,
  requireTest47,
  requireTestUser,
} from "../helpers";

/**
 * Khong tran ngang o viewport mobile 390px (M11, M15).
 *
 * Moi man chinh (desktop + /m/*) phai co documentElement.scrollWidth
 * <= innerWidth (390): noi dung rong chi duoc cuon trong container
 * rieng (VD bang co overflow-x-auto), khong duoc day ca trang.
 * Chi GET — khong ghi du lieu. Can tai khoan owner (mo duoc het man).
 */

test.beforeAll(() => {
  requireTest47();
  requireTestUser();
});

const SCREENS: { path: string; name: string }[] = [
  { path: propertyUrl(""), name: "tong quan" },
  { path: propertyUrl("/procurement/pr"), name: "danh sach yeu cau mua" },
  { path: propertyUrl("/procurement/po"), name: "danh sach don mua" },
  { path: propertyUrl("/inventory/stock"), name: "ton kho" },
  { path: propertyUrl("/inventory/counts"), name: "dot kiem ke" },
  { path: propertyUrl("/finance/invoices"), name: "hoa don NCC" },
  { path: propertyUrl("/reports"), name: "bao cao" },
  { path: propertyUrl("/restaurant"), name: "nha hang" },
  { path: propertyUrl("/frontdesk/minibar"), name: "minibar le tan" },
  { path: propertyUrl("/housekeeping/minibar"), name: "minibar buong phong" },
  // Route /admin/* khong co uuid property (xem ma tran M9).
  { path: "/admin/users", name: "quan ly nguoi dung" },
  { path: mobileUrl("/receive"), name: "nhan hang mobile" },
  { path: mobileUrl("/count"), name: "kiem ke mobile" },
  { path: mobileUrl("/minibar"), name: "minibar mobile" },
  // Man chung tu kho moi Q270 (V10): form lap + trang chi tiet phieu linh.
  { path: propertyUrl("/inventory/waste/new"), name: "lap phieu huy hang" },
  {
    path: propertyUrl("/inventory/requisitions/new"),
    name: "lap phieu linh",
  },
  {
    path: propertyUrl("/inventory/transfers/new"),
    name: "lap phieu dieu chuyen",
  },
  { path: propertyUrl("/inventory/issues/new"), name: "lap phieu xuat muc dich" },
  {
    path: propertyUrl(
      "/inventory/requisitions/d220983d-acf9-484f-9a6c-2c3aae12a930",
    ),
    name: "chi tiet phieu linh REQ-0002",
  },
];

for (const screen of SCREENS) {
  test(`O-${screen.name} — khong tran ngang o 390px`, async ({ page }) => {
    const response = await page.goto(screen.path);
    expect(response?.status(), `GET ${screen.name}`).toBe(200);
    // Doi loading boundary bien mat (luc dang tai co 2 <main>).
    await expect(page.locator('main[aria-busy="true"]')).toHaveCount(0, {
      timeout: 20000,
    });
    await expect(page.locator("main").last()).toBeVisible();
    const widths = await page.evaluate(() => ({
      innerWidth: window.innerWidth,
      docScrollWidth: document.documentElement.scrollWidth,
      bodyScrollWidth: document.body.scrollWidth,
    }));
    expect(
      widths.docScrollWidth,
      `${screen.name}: documentElement.scrollWidth ${widths.docScrollWidth} > innerWidth ${widths.innerWidth}`,
    ).toBeLessThanOrEqual(widths.innerWidth);
    expect(
      widths.bodyScrollWidth,
      `${screen.name}: body.scrollWidth ${widths.bodyScrollWidth} > innerWidth ${widths.innerWidth}`,
    ).toBeLessThanOrEqual(widths.innerWidth);
  });
}
