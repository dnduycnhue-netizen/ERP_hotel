import { test, expect } from "@playwright/test";
import {
  RECEIVER_PIN,
  approverAccount,
  loginAs,
  mobileUrl,
  propertyUrl,
  requireWrite,
} from "../helpers";
import { TEST_SEED } from "../fixtures/real-data";
import { readFlowState, saveFlowState } from "./flow-state";

/**
 * Tang ghi — nhan hang mu tren property test (T-047).
 * Nhan vien nhan (nguoi duyet, vai tro receiver) mo phieu tu PO da gui,
 * can gross/tare, QC Dat, ghi so bang PIN.
 * Vat tu seed thuoc nhom kind='other' + khong phai key item nen KHONG
 * bat buoc chup anh — tranh phu thuoc camera khi chay tu dong.
 */

test.use({
  viewport: { width: 390, height: 844 },
  hasTouch: true,
  isMobile: true,
});

test.beforeAll(() => {
  requireWrite();
});

test("W5 — nhận hàng mù: mở phiếu, cân, ghi dòng, ghi sổ bằng PIN", async ({
  page,
}) => {
  const state = readFlowState();
  test.skip(!state, "Thiếu flow state từ W4 (cần PO đã gửi NCC).");
  await loginAs(page, approverAccount());

  await page.goto(mobileUrl("/receive"));
  await expect(
    page.getByRole("heading", { name: "Nhiệm vụ nhận hàng hôm nay" }),
  ).toBeVisible();
  // Mu o tang UI: danh sach nhiem vu khong lo gia tien.
  const listText = await page.locator("main").innerText();
  expect(listText).not.toContain("₫");
  expect(listText).not.toMatch(/đơn giá/i);

  const task = page.getByRole("button", { name: /NCC T047/ });
  await expect(task).toBeVisible({ timeout: 20000 });
  await task.click();
  await expect(
    page.getByRole("heading", { name: "Mở phiếu nhận hàng" }),
  ).toBeVisible();
  await page.getByLabel("Kho nhận").selectOption({
    label: `${TEST_SEED.warehouseName} (${TEST_SEED.warehouseCode})`,
  });
  await page.getByRole("button", { name: "Mở phiếu nhận" }).click();
  await page.waitForURL(/\/m\/[^/]+\/receive\/[0-9a-f-]{36}/, {
    timeout: 20000,
  });
  const grId = page.url().split("/receive/")[1] ?? "";
  expect(grId).not.toBe("");

  // Form ghi dong: chi co can + QC, khong so PO / don gia.
  await expect(page.getByRole("button", { name: "Số cân" })).toBeVisible();
  await expect(page.getByText("Số thực nhận (net)")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Đạt", exact: true }),
  ).toBeVisible();
  const detailText = await page.locator("main").innerText();
  expect(detailText).not.toContain("₫");
  // Vat tu seed khong bat buoc anh — neu hien "Chua chup anh" nghia la
  // seed sai nhom, test phai dung lai ro ly do thay vi treo o nut Ghi.
  expect(detailText).not.toContain("Chưa chụp ảnh");

  // Can: gross 10 kg, tare 0 → net 10 kg (khop dung PO 10 kg).
  await page.getByRole("button", { name: "Số cân" }).click();
  await page.getByLabel("Số 1").click();
  await page.getByLabel("Số 0").click();
  await expect(page.getByText("10 kg")).toBeVisible();
  await page.getByRole("button", { name: "Bì" }).click();
  await page.getByLabel("Số 0").click();
  await page.getByRole("button", { name: "Ghi dòng" }).click();
  await expect(
    page.getByRole("button", { name: "Ghi sổ nhận hàng" }),
  ).toBeEnabled({ timeout: 20000 });

  // Ghi so: xac nhan hau qua -> nhap PIN (4 so, Enter de gui).
  await page.getByRole("button", { name: "Ghi sổ nhận hàng" }).click();
  await expect(
    page.getByText("Sau khi ghi sổ, người nhận không xem lại được phiếu này."),
  ).toBeVisible();
  await page.getByRole("button", { name: "Ghi sổ", exact: true }).click();
  await expect(
    page.getByRole("heading", { name: "Nhập mã PIN để ghi sổ" }),
  ).toBeVisible();
  await page.locator("input").first().click();
  await page.keyboard.type(RECEIVER_PIN);
  await page.keyboard.press("Enter");

  // Kiem chung phia server qua UI: PO chuyen "Da nhan du".
  await page.goto(propertyUrl(`/procurement/po/${state?.poId}`));
  await expect(page.getByText("Đã nhận đủ").first()).toBeVisible({
    timeout: 20000,
  });
  saveFlowState({ ...(state as NonNullable<typeof state>), grId });
});

test("W6 — tồn kho tăng đúng sau khi nhận (10 kg NVL0388)", async ({
  page,
}) => {
  const state = readFlowState();
  test.skip(!state?.grId, "Thiếu flow state từ W5 (cần phiếu đã ghi sổ).");
  await loginAs(page, approverAccount());
  await page.goto(propertyUrl("/inventory/stock"));
  await page.getByText(TEST_SEED.warehouseName).first().click();
  const row = page.locator("tr", { hasText: "NVL0388" });
  await expect(row).toBeVisible({ timeout: 20000 });
  await expect(row).toContainText("10");
});
