import { defineConfig, devices } from "@playwright/test";

/**
 * Playwright — kiem thu nghiem thu thi diem (T-047).
 *
 * 2 tang (xem tests/e2e/README.md):
 * - Doc (mac dinh): chi GET + dieu huong tren production live, KHONG ghi
 *   du lieu. Can TEST_USER_EMAIL/TEST_USER_PASSWORD de dang nhap; thieu
 *   thi cac test can auth tu skip (test public + PWA tinh van chay).
 * - Ghi: thu muc tests/e2e/write, chi chay khi TEST_WRITE_ENABLED=1 va
 *   TEST_PROPERTY_ID la property test rieng (khong phai SONHOIAN).
 *
 * Browser: dung Chrome for Testing co san qua PLAYWRIGHT_CHROME_PATH
 * (VD /home/hatch/workspace/.chrome-tmp/chrome-linux64/chrome tren VM);
 * khong dat thi Playwright dung Chromium cua no (npx playwright install).
 */
const baseURL = process.env.TEST_BASE_URL ?? "https://erphotel.vercel.app";
const chromePath = process.env.PLAYWRIGHT_CHROME_PATH;

/**
 * VM chay sau egress proxy co xac thuc (env HTTPS_PROXY): curl tu hieu
 * nhung Node/Chromium thi khong — phai truyen proxy vao Playwright
 * (ca browser lan API request). URL proxy (kem token) CHI doc tu env,
 * khong ghi cung vao repo. Chay local (TEST_BASE_URL=localhost) thi
 * NO_PROXY se bypass.
 */
const proxyServer = process.env.HTTPS_PROXY ?? process.env.https_proxy;
const proxyBypass = process.env.NO_PROXY ?? process.env.no_proxy;
/**
 * Chromium khong tu gui Proxy-Authorization khi user:pass nam trong URL
 * (CONNECT tunnel fail) — tach rieng username/password de Playwright
 * xu ly thu thach 407 cho ca browser lan API request.
 */
const proxyOption = (() => {
  if (!proxyServer) return undefined;
  try {
    const url = new URL(proxyServer);
    return {
      server: `${url.protocol}//${url.host}`,
      ...(url.username
        ? {
            username: decodeURIComponent(url.username),
            password: decodeURIComponent(url.password),
          }
        : {}),
      bypass: proxyBypass,
    };
  } catch {
    return { server: proxyServer, bypass: proxyBypass };
  }
})();

export default defineConfig({
  testDir: "./tests/e2e",
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL,
    trace: "retain-on-failure",
    screenshot: "only-on-failure",
    ...(proxyOption ? { proxy: proxyOption } : {}),
    launchOptions: chromePath ? { executablePath: chromePath } : {},
  },
  projects: [
    { name: "setup", testMatch: /auth\.setup\.ts/ },
    {
      name: "public",
      testMatch: /readonly\/public\.spec\.ts/,
    },
    {
      name: "readonly-desktop",
      testMatch: /readonly\/(smoke|reports)\.spec\.ts/,
      dependencies: ["setup"],
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1280, height: 800 },
        storageState: "tests/e2e/.auth/user.json",
      },
    },
    {
      name: "readonly-roles",
      testMatch: /readonly\/roles\.spec\.ts/,
      dependencies: ["setup"],
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1280, height: 800 },
        storageState: "tests/e2e/.auth/user.json",
      },
    },
    {
      name: "readonly-mobile",
      testMatch: /readonly\/(mobile-pwa|mobile-overflow)\.spec\.ts/,
      dependencies: ["setup"],
      use: {
        viewport: { width: 390, height: 844 },
        hasTouch: true,
        isMobile: true,
        storageState: "tests/e2e/.auth/user.json",
      },
    },
    {
      name: "write",
      testMatch: /write\/.*\.spec\.ts/,
      dependencies: ["setup"],
      use: {
        ...devices["Desktop Chrome"],
        viewport: { width: 1280, height: 800 },
      },
    },
    {
      name: "mobile-local",
      testMatch: /mobile\/00-local\.spec\.ts/,
      use: {
        viewport: { width: 390, height: 844 },
        hasTouch: true,
        isMobile: true,
      },
    },
    {
      name: "mobile-live",
      testMatch: /mobile\/(0[1-6])-.*\.spec\.ts/,
      dependencies: ["setup"],
      use: {
        viewport: { width: 390, height: 844 },
        hasTouch: true,
        isMobile: true,
        storageState: "tests/e2e/.auth/user.json",
      },
    },
  ],
});
