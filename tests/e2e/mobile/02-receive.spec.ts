import { test, expect } from "@playwright/test";
import { mobileUrl, requireMobileLive } from "../helpers";
import { TEST_SEED } from "../fixtures/real-data";
import {
  expectMinTouchTargets,
  expectNoHorizontalOverflow,
} from "./mobile-helpers";

/**
 * Tang LIVE-DATA (W5) — man nhan hang mobile (W1/T-024).
 * Chi chay tren may Mac sau khi seed xong (doi dieu phoi vien bao).
 *
 * Dieu kien: TEST_PROPERTY_ID=<id TEST47> + TEST_USER_EMAIL/TEST_USER_PASSWORD
 * (email TEST02: outlet_head + receiver).
 *
 * Luu y: luong ghi day du (mo phieu → can → ghi so bang PIN) da co o
 * tests/e2e/write/02-receiving.spec.ts (W5/W6) — spec nay chi kiem
 * danh sach + tinh "mu" o tang UI + kich thuoc cham.
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

test.beforeAll(() => {
  requireMobileLive();
});

test("M-R1 — danh sách nhiệm vụ: tiêu đề + trạng thái trống hoặc dòng nhiệm vụ", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  await expect(
    page.getByRole("heading", { name: "Nhiệm vụ nhận hàng hôm nay" }),
  ).toBeVisible();
  const body = await page.locator("main").innerText();
  // Chua co PO den han → EmptyState; co PO → moi dong la 1 nut mo phieu.
  expect(
    body.includes("Không có đơn mua nào đến hạn nhận hôm nay") ||
      (await page.locator("main ul li").count()) > 0,
  ).toBe(true);
  await expectNoHorizontalOverflow(page);
});

test("M-R2 — danh sách nhiệm vụ KHÔNG lộ giá (mù ở tầng UI)", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  await expect(
    page.getByRole("heading", { name: "Nhiệm vụ nhận hàng hôm nay" }),
  ).toBeVisible();
  const body = await page.locator("main").innerText();
  expect(body).not.toContain("₫");
  expect(body).not.toMatch(/đơn giá/i);
});

test("M-R3 — nhiệm vụ (nếu có) hiện đúng NCC test + đủ lớn để chạm", async ({
  page,
}) => {
  await page.goto(mobileUrl("/receive"));
  const task = page.getByRole("button", {
    name: new RegExp(TEST_SEED.supplierName),
  });
  if ((await task.count()) === 0) {
    test.skip(
      true,
      "Chưa có PO đến hạn trên TEST47 — cần chạy tầng ghi W4 trước (xem README).",
    );
  }
  await expect(task.first()).toBeVisible();
  const box = await task.first().boundingBox();
  expect(box?.height).toBeGreaterThanOrEqual(44);
  await expectMinTouchTargets(page);
});
