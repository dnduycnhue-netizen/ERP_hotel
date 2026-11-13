import { test, expect, type Page } from "@playwright/test";
import {
  loginAs,
  logout,
  mobileUrl,
  propertyUrl,
  requireTest47,
  type TestAccount,
} from "../helpers";

/**
 * Ma tran quyen theo vai tro — tang doc (M9, M11).
 *
 * Kiem chung tren TEST47 bang 9 tai khoan uat.*: moi vai tro mo 1 man
 * duoc phep (tai duoc, tieu de tieng Viet, khong loi console/pageerror)
 * va 1 man bi chan (hien thong bao 404 hoac khong co quyen).
 * Chi GET + dieu huong — khong ghi du lieu.
 *
 * Chay:
 *   TEST_PROPERTY_ID=<id TEST47> TEST_ROLE_PASSWORD=<mat khau chung uat.*>
 *   TEST_USER_EMAIL=uat.owner@erp.internal TEST_USER_PASSWORD=<mat khau>
 *   npx playwright test --project=readonly-roles
 *
 * Email moi vai tro mac dinh `uat.<vai tro>@erp.internal`, doi duoc qua
 * TEST_ROLE_<VAI TRO>_EMAIL (VD TEST_ROLE_OWNER_EMAIL). Khong co
 * TEST_ROLE_PASSWORD thi toan bo test skip (khong hardcode mat khau).
 * Ket qua ky vong lay tu bao cao M9 (docs/go-live/overnight/M9-*.md).
 */

test.beforeAll(() => {
  requireTest47();
  test.skip(
    !process.env.TEST_ROLE_PASSWORD,
    "Thieu TEST_ROLE_PASSWORD — mat khau chung cua cac tai khoan uat.*.",
  );
});

function roleAccount(role: string): TestAccount {
  const override = process.env[`TEST_ROLE_${role.toUpperCase()}_EMAIL`];
  return {
    email: override ?? `uat.${role}@erp.internal`,
    password: process.env.TEST_ROLE_PASSWORD ?? "",
  };
}

/** Dau tieng Viet — tieu de man hinh phai co dau (AGENTS.md §3.11). */
const VI_DIACRITIC =
  /[àáảãạăắằẳẵặâấầẩẫậđèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵ]/i;

type CollectedErrors = { pageerrors: string[]; consoleErrors: string[] };

function collectErrors(page: Page): CollectedErrors {
  const collected: CollectedErrors = { pageerrors: [], consoleErrors: [] };
  page.on("pageerror", (err) => collected.pageerrors.push(String(err)));
  page.on("console", (msg) => {
    if (msg.type() === "error") collected.consoleErrors.push(msg.text());
  });
  return collected;
}

function expectNoErrors(collected: CollectedErrors, where: string): void {
  expect(
    collected.pageerrors,
    `pageerror o ${where}: ${collected.pageerrors.join(" | ")}`,
  ).toEqual([]);
  expect(
    collected.consoleErrors,
    `console error o ${where}: ${collected.consoleErrors.join(" | ")}`,
  ).toEqual([]);
}

async function expectVietnameseHeading(
  page: Page,
  where: string,
): Promise<void> {
  const headings = page.locator("main").last().locator("h1, h2");
  expect(await headings.count(), `khong co h1/h2 trong main o ${where}`).toBeGreaterThan(0);
  const text = (await headings.first().innerText()).trim();
  expect(
    VI_DIACRITIC.test(text),
    `tieu de "${text}" o ${where} khong co dau tieng Viet`,
  ).toBe(true);
}

/** Doi segment loading.tsx bien mat roi moi dung locator('main').
 * Luc dang tai, app render 2 <main>: 1 <main aria-busy> cua loading
 * boundary + 1 <main> noi dung. Trang 404 cung render 2 <main> (main
 * layout cu + main cua trang 404) — phat hien a11y, xem bao cao M11.
 * Dung .last() de lay main cua trang dang hien. */
async function waitForMain(page: Page): Promise<void> {
  await expect(page.locator('main[aria-busy="true"]')).toHaveCount(0, {
    timeout: 20000,
  });
  await expect(page.locator("main").last()).toBeVisible();
}

/** Man duoc phep: 200 + main + tieu de tieng Viet + khong loi console. */
async function expectOpenScreen(
  page: Page,
  path: string,
  where: string,
): Promise<void> {
  const errors = collectErrors(page);
  const response = await page.goto(path);
  expect(response?.status(), `GET ${where}`).toBe(200);
  await waitForMain(page);
  await expectVietnameseHeading(page, where);
  // Cho loi client muon (neu co) xuat hien truoc khi khang dinh.
  await page.waitForTimeout(1000);
  expectNoErrors(errors, where);
}

/** Man bi chan: 200 + main + thong bao 404 hoac khong co quyen. */
async function expectBlockedScreen(
  page: Page,
  path: string,
  where: string,
): Promise<void> {
  const errors = collectErrors(page);
  const response = await page.goto(path);
  expect(response?.status(), `GET ${where}`).toBe(200);
  await waitForMain(page);
  const body = await page.locator("main").last().innerText();
  expect(
    /Không tìm thấy trang|không có quyền|chưa được cấp quyền/i.test(body),
    `man ${where} phai hien thong bao chan/quyen, thay: ${body.slice(0, 200)}`,
  ).toBe(true);
  await page.waitForTimeout(1000);
  // Chi khang dinh khong pageerror: trang bi chan co the log loi fetch
  // o console (VD /reports) — do la dau hieu can soi, khong phai loi
  // trang vo (xem M9 F.2); khong ep console sach o day.
  expect(
    errors.pageerrors,
    `pageerror o ${where}: ${errors.pageerrors.join(" | ")}`,
  ).toEqual([]);
}

const ROLES: {
  role: string;
  /** Man mo duoc (duong dan day du). */
  open: string;
  openName: string;
  /** Man bi chan (null = vai tro nay mo duoc het — kiem them 1 man mo). */
  blocked: string | null;
  blockedName: string | null;
  /** Man mo thu 2, chi dung khi blocked = null. */
  open2?: string;
  open2Name?: string;
}[] = [
  {
    role: "owner",
    open: propertyUrl("/procurement/pr"),
    openName: "danh sach yeu cau mua",
    blocked: null,
    blockedName: null,
    // Route /admin/* khong co uuid property (xem ma tran M9).
    open2: "/admin/users",
    open2Name: "quan ly nguoi dung",
  },
  {
    role: "gm",
    open: propertyUrl("/inventory/stock"),
    openName: "ton kho",
    blocked: propertyUrl("/receiving"),
    blockedName: "nhan hang (404)",
  },
  {
    role: "accountant",
    open: propertyUrl("/procurement/pr"),
    openName: "danh sach yeu cau mua",
    blocked: propertyUrl("/inventory/stock"),
    blockedName: "ton kho (khong quyen xem ton)",
  },
  {
    role: "purchaser",
    open: propertyUrl("/procurement/pr"),
    openName: "danh sach yeu cau mua",
    blocked: propertyUrl("/finance/payables"),
    blockedName: "cong no (khong quyen xem)",
  },
  {
    role: "chef",
    open: propertyUrl("/restaurant"),
    openName: "nha hang",
    blocked: propertyUrl("/procurement/po"),
    blockedName: "don mua hang (khong quyen)",
  },
  {
    role: "hk_supervisor",
    open: propertyUrl("/housekeeping/minibar"),
    openName: "minibar buong phong",
    blocked: propertyUrl("/inventory/stock"),
    blockedName: "ton kho (khong quyen xem ton)",
  },
  {
    role: "front_desk",
    open: propertyUrl("/frontdesk/minibar"),
    openName: "minibar le tan",
    blocked: propertyUrl("/procurement/pr"),
    blockedName: "yeu cau mua (404)",
  },
  {
    role: "receiver",
    open: mobileUrl("/receive"),
    openName: "nhan hang mobile",
    blocked: propertyUrl("/procurement/pr"),
    blockedName: "yeu cau mua (404)",
  },
  {
    role: "storekeeper",
    open: propertyUrl("/receiving"),
    openName: "nhan hang",
    blocked: propertyUrl("/procurement/pr"),
    blockedName: "yeu cau mua (404)",
  },
];

for (const spec of ROLES) {
  test(`R-${spec.role} — mo duoc ${spec.openName}, bi chan o ${spec.blockedName ?? spec.open2Name}`, async ({
    page,
  }) => {
    // Dang xuat session setup (TEST_USER) roi dang nhap dung vai tro.
    await logout(page);
    await loginAs(page, roleAccount(spec.role));
    await expectOpenScreen(page, spec.open, spec.openName);
    if (spec.blocked && spec.blockedName) {
      await expectBlockedScreen(page, spec.blocked, spec.blockedName);
    } else if (spec.open2 && spec.open2Name) {
      await expectOpenScreen(page, spec.open2, spec.open2Name);
    }
  });
}
