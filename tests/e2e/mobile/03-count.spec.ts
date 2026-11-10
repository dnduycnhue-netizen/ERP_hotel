import { test, expect } from "@playwright/test";
import { mobileUrl, requireMobileLive } from "../helpers";
import {
  expectMinTouchTargets,
  expectNoHorizontalOverflow,
} from "./mobile-helpers";

/**
 * Tang LIVE-DATA (W5) — man kiem ke mobile (W1/T-033).
 * Chi chay tren may Mac sau khi seed xong (doi dieu phoi vien bao).
 *
 * Dieu kien: TEST_PROPERTY_ID=<id TEST47> + TEST_USER_EMAIL/TEST_USER_PASSWORD
 * (email TEST02). Spec nay KHONG mo dot that (chi mo form) — mo dot
 * that la thao tac ghi, de luong kiem tay / task kiem ke sau.
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

test.beforeAll(() => {
  requireMobileLive();
});

test("M-C1 — danh sách đợt kiểm kê: tiêu đề + trạng thái trống hoặc dòng đợt", async ({
  page,
}) => {
  await page.goto(mobileUrl("/count"));
  await expect(
    page.getByRole("heading", { name: "Đợt kiểm kê" }),
  ).toBeVisible();
  const body = await page.locator("main").innerText();
  expect(
    body.includes("Chưa có đợt kiểm kê nào.") ||
      (await page.locator("main ul li").count()) > 0,
  ).toBe(true);
  await expectNoHorizontalOverflow(page);
});

test("M-C2 — nút mở đợt dẫn tới form mở đợt (chỉ mở form, không gửi)", async ({
  page,
}) => {
  await page.goto(mobileUrl("/count"));
  const openButton = page.getByRole("button", {
    name: "Mở đợt kiểm kê",
    exact: true,
  });
  if ((await openButton.count()) === 0) {
    test.skip(
      true,
      "TEST02 không có quyền count.open trên TEST47 — kiểm lại gán vai trò (xem README).",
    );
  }
  await openButton.click();
  await expect(
    page.getByRole("heading", { name: "Mở đợt kiểm kê" }),
  ).toBeVisible();
  // Form mo dot: co chon kho (KHO-T047) — chua gui gi.
  await expect(page.locator("select").first()).toBeVisible();
  await expectNoHorizontalOverflow(page);
  await expectMinTouchTargets(page);
});

test("M-C3 — dòng đợt (nếu có) đủ lớn để chạm", async ({ page }) => {
  await page.goto(mobileUrl("/count"));
  const rows = page.locator("main ul li button");
  if ((await rows.count()) === 0) {
    test.skip(true, "Chưa có đợt kiểm kê nào trên TEST47.");
  }
  const box = await rows.first().boundingBox();
  expect(box?.height).toBeGreaterThanOrEqual(44);
});
