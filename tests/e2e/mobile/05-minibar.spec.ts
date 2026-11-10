import { test, expect } from "@playwright/test";
import { mobileUrl, requireMobileLive } from "../helpers";
import { MINIBAR_ITEM_NAMES } from "../fixtures/mobile-real-data";
import {
  expectMinTouchTargets,
  expectNoHorizontalOverflow,
} from "./mobile-helpers";

/**
 * Tang LIVE-DATA (W5) — man kiem minibar mobile (W1/T-035).
 * Chi chay tren may Mac sau khi seed xong (doi dieu phoi vien bao).
 *
 * Dieu kien: TEST_PROPERTY_ID=<id TEST47> + TEST_USER_EMAIL/TEST_USER_PASSWORD
 * (email TEST02). Spec nay KHONG nop phieu kiem that (chi mo form) —
 * nop that can phong + gia hien hanh (Q47/Q153), de luong kiem tay.
 *
 * Luu y du lieu: phieu kiem chi xuat hien khi phong da duoc tao +
 * setup (Q153) — tren TEST47 co the chi thay trang thai trong.
 * Kiem tra ten mon trong form chi ap dung khi co phieu: moi option
 * (tru placeholder "Chọn món…") phai la 1 trong 7 mon minibar that
 * (seed §3d) — khong chap nhan ten bia.
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

test.beforeAll(() => {
  requireMobileLive();
});

test("M-B1 — danh sách phòng chờ kiểm: tiêu đề + trạng thái trống hoặc dòng phòng", async ({
  page,
}) => {
  await page.goto(mobileUrl("/minibar"));
  await expect(
    page.getByRole("heading", { name: "Kiểm minibar" }),
  ).toBeVisible();
  const body = await page.locator("main").innerText();
  expect(
    body.includes("Không có phòng nào đang chờ kiểm minibar.") ||
      (await page.locator("main ul li").count()) > 0,
  ).toBe(true);
  await expectNoHorizontalOverflow(page);
});

test("M-B2 — form kiểm phòng: món thêm vào chỉ là 7 món minibar thật", async ({
  page,
}) => {
  await page.goto(mobileUrl("/minibar"));
  const rows = page.locator("main ul li button");
  if ((await rows.count()) === 0) {
    test.skip(
      true,
      "Chưa có phòng chờ kiểm trên TEST47 — cần tạo phòng + setup minibar (Q153).",
    );
  }
  await rows.first().click();
  await expect(
    page.getByRole("heading", { name: /Kiểm minibar — Phòng/ }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Thêm món" }).click();
  const select = page.getByLabel("Mặt hàng");
  await expect(select).toBeVisible();
  const options = await select
    .locator("option")
    .evaluateAll((els) =>
      els.map((el) => (el.textContent ?? "").trim()).filter(Boolean),
    );
  const names = options.filter((o) => o !== "Chọn món…");
  for (const name of names) {
    expect(
      MINIBAR_ITEM_NAMES,
      `mon "${name}" khong nam trong 7 mon minibar that (seed §3d)`,
    ).toContain(name);
  }
  await expectNoHorizontalOverflow(page);
  await expectMinTouchTargets(page);
});

test("M-B3 — dòng phòng (nếu có) đủ lớn để chạm", async ({ page }) => {
  await page.goto(mobileUrl("/minibar"));
  const rows = page.locator("main ul li button");
  if ((await rows.count()) === 0) {
    test.skip(true, "Chưa có phòng chờ kiểm trên TEST47.");
  }
  const box = await rows.first().boundingBox();
  expect(box?.height).toBeGreaterThanOrEqual(44);
});
