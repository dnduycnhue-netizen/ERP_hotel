import { test, expect } from "@playwright/test";
import { creatorAccount, loginAs, propertyUrl, requireWrite } from "../helpers";
import { TEST_SEED } from "../fixtures/real-data";
import { readFlowState, saveFlowState, todayVn } from "./flow-state";

/**
 * Tang ghi — hoa don khop 3 chieu + de nghi thanh toan (T-047).
 * Hoa don lay dong tu PO da nhan du (gia = gia tran = gia PO) nen khop
 * du 3 chieu; duyet hoa don ghi cong no; de nghi thanh toan chi tao
 * (duyet de nghi can quyen payment.approve — chi owner co — nen de tay).
 */

test.beforeAll(() => {
  requireWrite();
});

test("W7 — nhập hóa đơn từ PO, khớp 3 chiều rồi duyệt", async ({ page }) => {
  const state = readFlowState();
  test.skip(!state?.poId, "Thiếu flow state từ W4 (cần PO đã gửi NCC).");
  await loginAs(page, creatorAccount());
  await page.goto(
    propertyUrl(
      `/finance/invoices/new?supplierId=${TEST_SEED.supplierId}&poId=${state?.poId}`,
    ),
  );
  await expect(
    page.getByRole("heading", { name: "Nhập hóa đơn mới" }),
  ).toBeVisible();
  await expect(page.getByLabel("Nhà cung cấp")).toHaveValue(
    TEST_SEED.supplierId,
  );
  await page.getByLabel("Ký hiệu").fill("T047");
  await page.getByLabel("Số hóa đơn").fill("0000001");
  await page.getByLabel("Ngày hóa đơn").fill(todayVn());
  await page.locator("form button[type='submit']").click();
  await page.waitForURL(/\/finance\/invoices\/[0-9a-f-]{36}/, {
    timeout: 20000,
  });
  const invoiceId = page.url().split("/finance/invoices/")[1] ?? "";
  expect(invoiceId).not.toBe("");

  await page.getByRole("button", { name: "Khớp 3 chiều" }).click();
  await expect(page.getByText("Đã khớp đủ 3 chiều.")).toBeVisible({
    timeout: 20000,
  });
  await page.getByRole("button", { name: "Duyệt hóa đơn" }).click();
  await expect(page.getByText("Đã duyệt hóa đơn và ghi công nợ.")).toBeVisible({
    timeout: 20000,
  });
  saveFlowState({ ...(state as NonNullable<typeof state>), invoiceId });
});

test("W8 — tạo đề nghị thanh toán cho hóa đơn đã duyệt", async ({ page }) => {
  const state = readFlowState();
  test.skip(!state?.invoiceId, "Thiếu flow state từ W7 (cần hóa đơn).");
  await loginAs(page, creatorAccount());
  await page.goto(
    propertyUrl(
      `/finance/payment-requests/new?supplierId=${TEST_SEED.supplierId}`,
    ),
  );
  await expect(
    page.getByRole("heading", { name: "Đề nghị thanh toán" }),
  ).toBeVisible();
  await expect(page.getByText("0000001")).toBeVisible({ timeout: 20000 });
  // Nhap so tien cho hoa don vua duyet (10 kg x 100.000 = 1.000.000).
  const amountInput = page.locator("table input").first();
  await amountInput.fill("1000000");
  await page.locator("form button[type='submit']").click();
  await page.waitForURL(/\/finance\/payment-requests\/[0-9a-f-]{36}/, {
    timeout: 20000,
  });
  const paymentRequestId =
    page.url().split("/finance/payment-requests/")[1] ?? "";
  expect(paymentRequestId).not.toBe("");
  saveFlowState({
    ...(state as NonNullable<typeof state>),
    paymentRequestId,
  });
});

test("W9 — báo cáo trên property test thấy dữ liệu vừa ghi", async ({
  page,
}) => {
  const state = readFlowState();
  test.skip(!state?.invoiceId, "Thiếu flow state từ W7.");
  await loginAs(page, creatorAccount());
  await page.goto(
    propertyUrl(`/reports/stock-card?from=${todayVn()}&to=${todayVn()}`),
  );
  await expect(
    page.getByRole("heading", { name: "Thẻ kho", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("NVL0388")).toBeVisible({ timeout: 20000 });
  await page.goto(propertyUrl(`/reports/ap-aging?as_of=${todayVn()}`));
  await expect(
    page.getByRole("heading", { name: "Tuổi nợ & dòng tiền chi", exact: true }),
  ).toBeVisible();
  await expect(page.getByText("NCC T047")).toBeVisible({ timeout: 20000 });
});

test("W10 — minibar, kiểm kê, PMS ngày trên property test mở được", async ({
  page,
}) => {
  requireWrite();
  await loginAs(page, creatorAccount());
  for (const path of [
    "/housekeeping/minibar",
    "/inventory/counts/new",
    "/frontdesk/pms-daily",
  ]) {
    const response = await page.goto(propertyUrl(path));
    expect(response?.status(), `GET ${path}`).toBe(200);
    await expect(page.locator("main")).toBeVisible();
    expect(await page.locator("main h1, main h2").count()).toBeGreaterThan(0);
  }
});
