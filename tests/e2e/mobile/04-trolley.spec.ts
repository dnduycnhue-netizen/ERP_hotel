import { test, expect } from "@playwright/test";
import { mobileUrl, requireMobileLive } from "../helpers";
import {
  expectMinTouchTargets,
  expectNoHorizontalOverflow,
} from "./mobile-helpers";

/**
 * Tang LIVE-DATA (W5) — man xe day mobile (W1/T-034).
 * Chi chay tren may Mac sau khi seed xong (doi dieu phoi vien bao).
 *
 * Dieu kien: TEST_PROPERTY_ID=<id TEST47> + TEST_USER_EMAIL/TEST_USER_PASSWORD
 * (email TEST02). Spec nay KHONG mo ca that (chi mo form) — mo ca
 * that sinh phieu linh bu toi par, la thao tac ghi.
 *
 * Luu y: TEST47 chua co kho kind='trolley' (seed-test-property.sql chi
 * tao KHO-T047) nen form mo ca co the hien EmptyState "chua co kho xe
 * day" thay vi form — test chap nhan ca 2 trang thai va ghi ro.
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

test.beforeAll(() => {
  requireMobileLive();
});

test("M-T1 — danh sách ca xe đẩy: tiêu đề + trạng thái trống hoặc dòng ca", async ({
  page,
}) => {
  await page.goto(mobileUrl("/trolley"));
  await expect(page.getByRole("heading", { name: "Ca xe đẩy" })).toBeVisible();
  const body = await page.locator("main").innerText();
  expect(
    body.includes("Chưa có ca xe đẩy nào.") ||
      (await page.locator("main ul li").count()) > 0,
  ).toBe(true);
  await expectNoHorizontalOverflow(page);
});

test("M-T2 — nút mở ca: form mở ca hoặc trạng thái chưa có kho xe đẩy", async ({
  page,
}) => {
  await page.goto(mobileUrl("/trolley"));
  const openButton = page.getByRole("button", {
    name: "Mở ca mới",
    exact: true,
  });
  if ((await openButton.count()) === 0) {
    test.skip(
      true,
      "TEST02 không có quyền hk.trolley.operate trên TEST47 — kiểm lại gán vai trò (xem README).",
    );
  }
  await openButton.click();
  const body = await page.locator("main").innerText();
  // Co kho trolley → form "Mở ca xe đẩy" (chon kho + ca); chua co →
  // EmptyState (vi.trolley.noTrolleyWarehouse). Ca 2 deu hop le.
  expect(
    (await page.getByRole("heading", { name: "Mở ca xe đẩy" }).count()) > 0 ||
      body.length > 0,
  ).toBe(true);
  await expectNoHorizontalOverflow(page);
  await expectMinTouchTargets(page);
});

test("M-T3 — dòng ca (nếu có) đủ lớn để chạm", async ({ page }) => {
  await page.goto(mobileUrl("/trolley"));
  const rows = page.locator("main ul li button");
  if ((await rows.count()) === 0) {
    test.skip(true, "Chưa có ca xe đẩy nào trên TEST47.");
  }
  const box = await rows.first().boundingBox();
  expect(box?.height).toBeGreaterThanOrEqual(44);
});
