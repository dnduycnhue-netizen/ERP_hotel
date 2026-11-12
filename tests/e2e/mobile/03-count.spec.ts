import { test, expect } from "@playwright/test";
import {
  TEST_PROPERTY_ID,
  loginAs,
  mobileUrl,
  requireMobileLive,
} from "../helpers";
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

/**
 * M-C4 (R30) — đếm một mã về 0, nộp, dòng hiện variance = 0 − tồn sổ.
 * Luồng đầy đủ cần chuẩn bị trước trên TEST47 (xem tests/e2e/README.md):
 * - 2 tài khoản người đếm (count.perform tại kho, SoD độc lập) + PIN
 *   từng người: TEST_COUNTER1_EMAIL/PASSWORD/PIN,
 *   TEST_COUNTER2_EMAIL/PASSWORD/PIN.
 * - 1 tài khoản xem chênh lệch (count.view_variance, không phải người
 *   đếm): TEST_VARIANCE_VIEWER_EMAIL/PASSWORD.
 * - 1 đợt kiểm kê monthly_full đang đếm (trạng thái counting/recount)
 *   có dòng của mã TEST_COUNT_ITEM_CODE (mặc định NVL0388) với tồn sổ
 *   đã biết TEST_COUNT_BOOK_QTY (vd sau khi nhận hàng brief 01).
 * Thiếu bất kỳ điều kiện nào thì test tự skip với lý do rõ ràng.
 */
test("M-C4 — đếm một mã về 0, nộp, dòng hiện variance = 0 − tồn sổ", async ({
  page,
}) => {
  const counter1 = {
    email: process.env.TEST_COUNTER1_EMAIL ?? "",
    password: process.env.TEST_COUNTER1_PASSWORD ?? "",
    pin: process.env.TEST_COUNTER1_PIN ?? "",
  };
  const counter2 = {
    email: process.env.TEST_COUNTER2_EMAIL ?? "",
    password: process.env.TEST_COUNTER2_PASSWORD ?? "",
    pin: process.env.TEST_COUNTER2_PIN ?? "",
  };
  const viewer = {
    email: process.env.TEST_VARIANCE_VIEWER_EMAIL ?? "",
    password: process.env.TEST_VARIANCE_VIEWER_PASSWORD ?? "",
  };
  const itemCode = process.env.TEST_COUNT_ITEM_CODE ?? "NVL0388";
  const bookQty = Number(process.env.TEST_COUNT_BOOK_QTY ?? "");
  if (
    !counter1.email ||
    !counter1.password ||
    !counter1.pin ||
    !counter2.email ||
    !counter2.password ||
    !counter2.pin ||
    !viewer.email ||
    !viewer.password ||
    !Number.isFinite(bookQty)
  ) {
    test.skip(
      true,
      "Cần TEST_COUNTER1/2_EMAIL/PASSWORD/PIN + TEST_VARIANCE_VIEWER_EMAIL/PASSWORD + TEST_COUNT_BOOK_QTY (tồn sổ đã biết của mã đếm) — xem tests/e2e/README.md.",
    );
  }
  const expectedVariance = 0 - bookQty;

  async function recordZero(
    account: { email: string; password: string },
    countId: string,
  ): Promise<void> {
    await loginAs(page, account);
    await page.goto(mobileUrl(`/count/${countId}`));
    await page
      .getByPlaceholder("Tìm theo mã hoặc tên hàng…")
      .fill(itemCode);
    const lineButton = page.getByRole("button", {
      name: new RegExp(itemCode.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")),
    });
    await lineButton.first().click();
    // Nhập 0 bằng NumPad: nút "0" phải cho lưu (R30), tổng hiện 0 và
    // hiện gợi ý "hết hàng".
    await page.getByRole("button", { name: "Số 0", exact: true }).click();
    await expect(
      page.getByText("Số 0 nghĩa là hết hàng — dòng này vẫn được ghi nhận."),
    ).toBeVisible();
    await page
      .getByRole("button", { name: "Lưu số đếm", exact: true })
      .click();
    await expect(page.getByText("Đã ghi số đếm.")).toBeVisible();
  }

  // Vòng 1: người đếm 1 ghi 0.
  await loginAs(page, counter1);
  await page.goto(mobileUrl("/count"));
  const roundLink = page.locator("main ul li a, main ul li button").first();
  if ((await roundLink.count()) === 0) {
    test.skip(
      true,
      "Chưa có đợt kiểm kê nào trên TEST47 — mở đợt trước (cần count.open).",
    );
  }
  const href = await roundLink.first().getAttribute("href");
  const countId = href?.split("/").filter(Boolean).pop();
  if (!countId) {
    test.skip(true, "Không đọc được id đợt kiểm kê từ danh sách.");
    return;
  }
  await recordZero(counter1, countId);
  // Vòng 1: người đếm 2 ghi 0 (cùng mã, độc lập).
  await recordZero(counter2, countId);

  // Nộp đợt bằng cả 2 PIN (R25 đang bật: cần đủ PIN mọi người đếm).
  await loginAs(page, counter1);
  await page.goto(mobileUrl(`/count/${countId}`));
  await page
    .getByRole("button", { name: "Nộp đợt", exact: true })
    .click();
  await page.getByLabel("Mã PIN người đếm 1").fill(counter1.pin);
  await page.getByLabel("Mã PIN người đếm 2").fill(counter2.pin);
  await page
    .getByRole("button", { name: "Nộp đợt", exact: true })
    .last()
    .click();
  await expect(page.getByText("Đã nộp đợt kiểm kê.")).toBeVisible();

  // Người xem chênh lệch kiểm tra dòng: variance = 0 − tồn sổ.
  await loginAs(page, viewer);
  await page.goto(`/${TEST_PROPERTY_ID}/inventory/counts/${countId}`);
  const row = page.locator("tr", { hasText: itemCode }).first();
  await expect(row).toBeVisible();
  const varianceText = new Intl.NumberFormat("vi-VN", {
    maximumFractionDigits: 4,
  }).format(expectedVariance);
  await expect(row).toContainText(varianceText);
});
