import { test as setup } from "@playwright/test";
import fs from "node:fs";
import path from "node:path";

const AUTH_FILE = path.join(__dirname, ".auth", "user.json");

/**
 * Dang nhap 1 lan bang UI roi luu session cho cac project readonly.
 * Khong co TEST_USER_EMAIL/TEST_USER_PASSWORD thi ghi state rong —
 * cac test can auth se tu skip (helpers.requireTestUser).
 * File .auth/ KHONG commit (xem .gitignore).
 */
setup("authenticate", async ({ page }) => {
  const email = process.env.TEST_USER_EMAIL;
  const password = process.env.TEST_USER_PASSWORD;
  fs.mkdirSync(path.dirname(AUTH_FILE), { recursive: true });
  if (!email || !password) {
    fs.writeFileSync(AUTH_FILE, JSON.stringify({ cookies: [], origins: [] }));
    return;
  }
  await page.goto("/login");
  await page.getByLabel("Email tài khoản").fill(email);
  await page.getByLabel("Mật khẩu").fill(password);
  await page.getByRole("button", { name: "Đăng nhập", exact: true }).click();
  await page.waitForURL((url) => !url.pathname.startsWith("/login"), {
    timeout: 20000,
  });
  await page.context().storageState({ path: AUTH_FILE });
});
