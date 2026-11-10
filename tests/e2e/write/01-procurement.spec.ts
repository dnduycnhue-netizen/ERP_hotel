import { test, expect } from "@playwright/test";
import {
  approverAccount,
  creatorAccount,
  loginAs,
  logout,
  propertyUrl,
  requireWrite,
} from "../helpers";
import { TEST_SEED } from "../fixtures/real-data";
import { flowTag, readFlowState, saveFlowState, todayVn } from "./flow-state";

/**
 * Tang ghi — luong thu mua tren property test (T-047).
 * PR (nguoi tao) -> duyet (nguoi duyet) -> PO -> duyet -> gui NCC.
 * Chi chay khi TEST_WRITE_ENABLED=1 + property test + du 2 tai khoan.
 * Thu tu file: 01 -> 02 -> 03 (workers: 1, chay tuan tu theo ten file).
 */

test.beforeAll(() => {
  requireWrite();
});

const TAG = flowTag();

test("W1 — dữ liệu seed có mặt trên property test", async ({ page }) => {
  await loginAs(page, creatorAccount());
  await page.goto(propertyUrl(""));
  await expect(
    page.getByRole("heading", { name: TEST_SEED.propertyName }),
  ).toBeVisible();
  await page.goto(propertyUrl("/master/suppliers"));
  await expect(
    page.getByText(TEST_SEED.supplierName, { exact: false }),
  ).toBeVisible();
  await page.goto(propertyUrl("/master/items"));
  await expect(page.getByText("NVL0388")).toBeVisible();
  await expect(page.getByText("NVL0561")).toBeVisible();
});

test("W2 — người tạo lập PR và gửi duyệt", async ({ page }) => {
  await loginAs(page, creatorAccount());
  await page.goto(propertyUrl("/procurement/pr/new"));
  await expect(
    page.getByRole("heading", { name: "Tạo yêu cầu mua" }),
  ).toBeVisible();

  await page.getByLabel("Loại").selectOption({ label: "Vật tư" });
  const outlet = page.getByLabel("Outlet");
  await expect(outlet).toBeVisible();
  await outlet.selectOption({ label: TEST_SEED.outletName });
  await page.getByLabel("Ngày cần").fill(todayVn());
  await page.getByLabel("Ghi chú").fill(`Kiểm thử nghiệm thu ${TAG}`);

  await page.getByRole("button", { name: "+ Thêm dòng" }).click();
  await page.getByPlaceholder("Gõ tên hoặc mã vật tư để tìm…").fill("NVL0388");
  await page.getByText("NVL0388").first().click({ timeout: 10000 });
  await page.getByLabel("Số lượng").first().fill("10");

  await page.getByRole("button", { name: "Lưu nháp" }).click();
  await page.waitForURL(/\/procurement\/pr\/[0-9a-f-]{36}/, {
    timeout: 20000,
  });
  const prId = page.url().split("/procurement/pr/")[1] ?? "";
  expect(prId).not.toBe("");

  await page.getByRole("button", { name: "Gửi duyệt" }).click();
  await expect(page.getByText("Chờ duyệt").first()).toBeVisible({
    timeout: 20000,
  });
  saveFlowState({
    tag: TAG,
    prId,
    poId: "",
    supplierName: TEST_SEED.supplierName,
    expectedDate: todayVn(),
  });
});

test("W3 — người duyệt duyệt PR (SoD: người tạo không tự duyệt)", async ({
  page,
}) => {
  const state = readFlowState();
  test.skip(!state, "Thiếu flow state từ W2.");
  await loginAs(page, approverAccount());
  await page.goto(propertyUrl(`/procurement/pr/${state?.prId}`));
  await expect(page.getByText("Chờ duyệt").first()).toBeVisible();
  await page.getByRole("button", { name: "Duyệt", exact: true }).click();
  await expect(page.getByText("Đã duyệt").first()).toBeVisible({
    timeout: 20000,
  });
  // Hop thu cho duyet phai mo duoc (khong ep ten dong o day).
  await page.goto(propertyUrl("/procurement/approvals"));
  await expect(page.locator("main")).toBeVisible();
});

test("W4 — tạo PO từ PR, duyệt rồi gửi cho NCC", async ({ page }) => {
  const state = readFlowState();
  test.skip(!state, "Thiếu flow state từ W2.");
  await loginAs(page, creatorAccount());
  await page.goto(propertyUrl(`/procurement/pr/${state?.prId}`));
  await page.getByRole("button", { name: "Tạo đơn mua từ yêu cầu" }).click();
  await expect(
    page.getByRole("heading", { name: "Tạo đơn mua" }),
  ).toBeVisible();
  await page.getByLabel("Nhà cung cấp").selectOption({
    label: TEST_SEED.supplierName,
  });
  await page.getByLabel("Ngày dự kiến nhận").fill(todayVn());
  await page.getByRole("button", { name: "Lưu nháp" }).click();
  await page.waitForURL(/\/procurement\/po\/[0-9a-f-]{36}/, {
    timeout: 20000,
  });
  const poId = page.url().split("/procurement/po/")[1] ?? "";
  expect(poId).not.toBe("");

  await page.getByRole("button", { name: "Gửi duyệt" }).click();
  await expect(page.getByText("Chờ duyệt").first()).toBeVisible({
    timeout: 20000,
  });

  await logout(page);
  await loginAs(page, approverAccount());
  await page.goto(propertyUrl(`/procurement/po/${poId}`));
  await page.getByRole("button", { name: "Duyệt", exact: true }).click();
  await expect(page.getByText("Đã duyệt").first()).toBeVisible({
    timeout: 20000,
  });
  // PO hop dong chi nhan duoc khi da gui NCC (xem _receiving_po_eligible).
  await page.getByRole("button", { name: "Gửi cho nhà cung cấp" }).click();
  await expect(page.getByText("Đã gửi NCC").first()).toBeVisible({
    timeout: 20000,
  });
  saveFlowState({ ...(state as NonNullable<typeof state>), poId });
});
