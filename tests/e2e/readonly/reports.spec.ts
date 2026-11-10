import { test, expect, type Page } from "@playwright/test";
import { expectNoPageError, propertyUrl, requireTestUser } from "../helpers";

/**
 * Smoke bao cao (T-044): mo duoc + co so lieu hoac trang thai rong,
 * khong loi. Doi chieu so lieu voi truy van doc lap la viec cua pgTAP
 * (da co bo test T-044) — Playwright chi khang dinh man hinh render.
 */

test.beforeAll(() => {
  requireTestUser();
});

const REPORT_TITLES = [
  "Thẻ kho",
  "Chất lượng nhận hàng",
  "Đơn mua mở & hóa đơn treo",
  "Tuổi nợ & dòng tiền chi",
  "Tạm ứng chưa quyết toán",
  "Hủy hàng",
  "Chi phí vận hành",
  "Minibar",
  "Amenities — chi phí / đêm phòng",
  "Bản tin 8h",
];

test("R1 — trang báo cáo liệt kê đủ 10 báo cáo", async ({ page }) => {
  await page.goto(propertyUrl("/reports"));
  const viewButtons = page.getByRole("link", { name: "Xem báo cáo" });
  await expect(viewButtons).toHaveCount(10);
  for (const title of REPORT_TITLES) {
    await expect(
      page.getByRole("heading", { name: title, exact: true }),
    ).toBeVisible();
  }
});

async function expectReportRenders(
  page: Page,
  slug: string,
  title: string,
  query: string,
): Promise<void> {
  await page.goto(propertyUrl(`/reports/${slug}${query}`));
  await expect(
    page.getByRole("heading", { name: title, exact: true }),
  ).toBeVisible();
  // Bo loc hien (tu ngay / den ngay / tinh den ngay / thang / ngay).
  await expect(page.getByRole("button", { name: "Áp dụng" })).toBeVisible();
  const main = page.locator("main");
  const hasTable = (await main.locator("table").count()) > 0;
  const body = await main.innerText();
  const hasEmptyState =
    /không có dữ liệu|chưa có dữ liệu|không có .* trong/i.test(body);
  expect(
    hasTable || hasEmptyState,
    "Bao cao phai render bang hoac trang thai rong",
  ).toBe(true);
  await expectNoPageError(page);
}

test("R2 — thẻ kho mở được với khoảng ngày", async ({ page }) => {
  await expectReportRenders(
    page,
    "stock-card",
    "Thẻ kho",
    "?from=2026-11-01&to=2026-11-10",
  );
});

test("R3 — tuổi nợ mở được với ngày chốt", async ({ page }) => {
  await expectReportRenders(
    page,
    "ap-aging",
    "Tuổi nợ & dòng tiền chi",
    "?as_of=2026-11-10",
  );
});

test("R4 — bản tin 8h mở được theo ngày", async ({ page }) => {
  await page.goto(propertyUrl("/reports/daily-brief?date=2026-11-10"));
  await expect(
    page.getByRole("heading", { name: "Bản tin 8h", exact: true }),
  ).toBeVisible();
  await expect(page.locator("main")).not.toBeEmpty();
  await expectNoPageError(page);
});

test("R5 — đổi bộ lọc rồi Áp dụng thì cập nhật kết quả", async ({ page }) => {
  await page.goto(propertyUrl("/reports/stock-card"));
  await page.getByLabel("Từ ngày").fill("2026-11-01");
  await page.getByLabel("Đến ngày").fill("2026-11-10");
  await page.getByRole("button", { name: "Áp dụng" }).click();
  await expect(page).toHaveURL(/from=2026-11-01/);
  await expect(page).toHaveURL(/to=2026-11-10/);
  await expect(
    page.getByRole("heading", { name: "Thẻ kho", exact: true }),
  ).toBeVisible();
  await expectNoPageError(page);
});
