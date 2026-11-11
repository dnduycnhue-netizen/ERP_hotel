import { test, type Page } from "@playwright/test";

/**
 * Helper dung chung cho Playwright (T-047).
 *
 * Quy tac du lieu (cung):
 * - Tang doc chay tren property that SONHOIAN, chi GET/dieu huong.
 * - Tang ghi CHI chay khi TEST_WRITE_ENABLED=1 va TEST_PROPERTY_ID la
 *   property test rieng — neu trung SONHOIAN thi skip, khong ghi gi.
 * - Khong hardcode tai khoan/mat khau: tat ca qua env.
 */

/** Property that Son Hoi An Boutique Hotel & Spa (production). */
export const LIVE_PROPERTY_ID = "7e37858d-58ed-4924-bb8f-9d56be9c620b";

/** Property chay test: mac dinh SONHOIAN (chi doc); tang ghi doi rieng. */
export const TEST_PROPERTY_ID =
  process.env.TEST_PROPERTY_ID ?? LIVE_PROPERTY_ID;

export const hasTestUser = Boolean(
  process.env.TEST_USER_EMAIL && process.env.TEST_USER_PASSWORD,
);

export const hasWriteUsers = Boolean(
  process.env.TEST_CREATOR_EMAIL &&
  process.env.TEST_CREATOR_PASSWORD &&
  process.env.TEST_APPROVER_EMAIL &&
  process.env.TEST_APPROVER_PASSWORD,
);

/** Tang ghi du dieu kien chay: co property test + du 2 tai khoan. */
export function writeEnabled(): boolean {
  return (
    process.env.TEST_WRITE_ENABLED === "1" &&
    TEST_PROPERTY_ID !== LIVE_PROPERTY_ID &&
    hasWriteUsers
  );
}

export function requireTestUser(): void {
  test.skip(
    !hasTestUser,
    "Thieu TEST_USER_EMAIL/TEST_USER_PASSWORD — xem tests/e2e/README.md.",
  );
}

/**
 * Tang LIVE-DATA mobile (W5): chay tren property test rieng (TEST47),
 * khong chay tren SONHOIAN — tai khoan TEST02 chi co vai tro tren
 * TEST47, mo /m/SONHOIAN se 404 (property khong thuoc quyen).
 * Can: TEST_PROPERTY_ID=<id TEST47> + TEST_USER_EMAIL/TEST_USER_PASSWORD
 * (email TEST02) + seed mau da xong (doi dieu phoi vien bao).
 */
export function requireMobileLive(): void {
  test.skip(
    !hasTestUser || !process.env.TEST_PROPERTY_ID,
    "Tang LIVE-DATA mobile can TEST_PROPERTY_ID (property test, khong " +
      "phai SONHOIAN) + TEST_USER_EMAIL/TEST_USER_PASSWORD — xem " +
      "tests/e2e/README.md muc Mobile (W5).",
  );
}

export function requireWrite(): void {
  test.skip(
    !writeEnabled(),
    "Tang ghi can TEST_WRITE_ENABLED=1 + TEST_PROPERTY_ID (property test, " +
      "khong phai SONHOIAN) + TEST_CREATOR_* + TEST_APPROVER_*.",
  );
}

export type TestAccount = { email: string; password: string };

export function creatorAccount(): TestAccount {
  return {
    email: process.env.TEST_CREATOR_EMAIL ?? "",
    password: process.env.TEST_CREATOR_PASSWORD ?? "",
  };
}

export function approverAccount(): TestAccount {
  return {
    email: process.env.TEST_APPROVER_EMAIL ?? "",
    password: process.env.TEST_APPROVER_PASSWORD ?? "",
  };
}

/** Tai khoan quan tri cho test tao tai khoan (can admin.users.manage). */
export const hasAdminUser = Boolean(
  process.env.TEST_ADMIN_EMAIL && process.env.TEST_ADMIN_PASSWORD,
);

export function adminAccount(): TestAccount {
  return {
    email: process.env.TEST_ADMIN_EMAIL ?? "",
    password: process.env.TEST_ADMIN_PASSWORD ?? "",
  };
}

/** PIN ghi so cua nguoi nhan test (mac dinh 1234 theo quy uoc seed). */
export const RECEIVER_PIN = process.env.TEST_RECEIVER_PIN ?? "1234";

/** Dang nhap bang UI (form /login: Email tai khoan + Mat khau). */
export async function loginAs(page: Page, account: TestAccount): Promise<void> {
  await page.goto("/login");
  await page.getByLabel("Email tài khoản").fill(account.email);
  await page.getByLabel("Mật khẩu").fill(account.password);
  await page.getByRole("button", { name: "Đăng nhập", exact: true }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"), {
    timeout: 20000,
  });
}

/** Dang xuat (de doi tai khoan trong cung 1 test). */
export async function logout(page: Page): Promise<void> {
  await page.context().clearCookies();
  await page.goto("/login");
  await page.waitForURL(/\/login/);
}

/** Duong dan trong 1 property (VD "/procurement/pr"). */
export function propertyUrl(path: string): string {
  return `/${TEST_PROPERTY_ID}${path}`;
}

/** Duong dan man hien truong /m/<property>/... */
export function mobileUrl(path: string): string {
  return `/m/${TEST_PROPERTY_ID}${path}`;
}

/** Doc trang va khang dinh khong co banner loi chung. */
export async function expectNoPageError(page: Page): Promise<void> {
  const body = await page.locator("main").innerText();
  if (/Đã xảy ra lỗi|Something went wrong|Application error/i.test(body)) {
    throw new Error(`Trang co banner loi: ${body.slice(0, 300)}`);
  }
}
