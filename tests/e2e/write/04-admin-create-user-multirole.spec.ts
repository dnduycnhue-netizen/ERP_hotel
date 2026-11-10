import { test, expect } from "@playwright/test";
import { adminAccount, hasAdminUser, loginAs } from "../helpers";

/**
 * Tang ghi — tao tai khoan da vai tro qua /admin/users/new (luong 10).
 *
 * Hoi quy cho vu owner 10/11: tai khoan owner@sonhoianhotel.com duoc tao
 * (tick du 17 vai tro, pham vi toan chuoi) nhung DB chi co 1 dong
 * user_property_roles la sys_admin — sidebar chi co Tong quan + Quan tri
 * he thong, moi man nghiep vu 404. Duong tao da vai tro da duoc chung minh
 * chay duoc (TEST02: outlet_head + receiver du 2 dong), nen day la test
 * hoi quy de loi rot vai tro (neu tai dien) bi bat ngay.
 *
 * NGOAI LE so voi tang ghi thuong: tao tai khoan la pham vi chuoi
 * (auth + user_property_roles), khong can property test — chi can
 * TEST_WRITE_ENABLED=1 (cong cho phep ghi) + tai khoan quan tri co
 * admin.users.manage (TEST_ADMIN_EMAIL / TEST_ADMIN_PASSWORD).
 *
 * TAC DUNG PHU: moi lan chay tao 1 tai khoan auth that voi email duy nhat
 * (e2e-multirole-<timestamp>@example.com), vai tro purchaser +
 * storekeeper, pham vi toan chuoi. Khong co chuc nang xoa tai khoan nen
 * tai khoan nay o lai trong auth (giong TEST01–TEST05 Duy tao tay).
 * Chi chay khi TEST_WRITE_ENABLED=1 — khong bao gio chay vo tinh.
 */

test.beforeAll(() => {
  test.skip(
    process.env.TEST_WRITE_ENABLED !== "1" || !hasAdminUser,
    "Can TEST_WRITE_ENABLED=1 + TEST_ADMIN_EMAIL/TEST_ADMIN_PASSWORD " +
      "(tai khoan co admin.users.manage) — xem tests/e2e/README.md.",
  );
});

test("W11 — tạo tài khoản 2 vai trò thì trang quyền hiện đủ 2 dòng", async ({
  page,
}) => {
  const stamp = String(Date.now());
  const employeeCode = `E2E${stamp.slice(-6)}`;
  const email = `e2e-multirole-${stamp}@example.com`;
  const tempPassword = `Tmp-${stamp.slice(-8)}-e2e`;

  await loginAs(page, adminAccount());
  await page.goto("/admin/users/new");
  await expect(
    page.getByRole("heading", { name: "Tạo tài khoản mới" }),
  ).toBeVisible();

  await page.getByLabel("Mã nhân viên").fill(employeeCode);
  await page.getByLabel("Họ tên").fill("Kiểm thử đa vai trò");
  await page.getByLabel("Email (không bắt buộc)").fill(email);

  // Mac dinh preset "Nguoi tao mua hang" da tick san purchaser;
  // tick them storekeeper -> preset tu chuyen "Tuy chon".
  await expect(page.getByRole("checkbox", { name: "purchaser" })).toBeChecked();
  await page.getByRole("checkbox", { name: "storekeeper" }).check();
  await expect(page.getByRole("checkbox", { name: "purchaser" })).toBeChecked();
  await expect(
    page.getByRole("checkbox", { name: "storekeeper" }),
  ).toBeChecked();

  await page.getByRole("radio", { name: "Tự đặt mật khẩu" }).check();
  await page.getByLabel("Mật khẩu tạm").fill(tempPassword);

  await page.getByRole("button", { name: "Tạo tài khoản" }).click();

  // Man hinh thanh cong: mat khau tam chi hien 1 lan + link xem quyen.
  await expect(page.getByText("Đã tạo tài khoản.")).toBeVisible();
  await page.getByRole("link", { name: "Xem quyền của tài khoản này" }).click();
  await page.waitForURL(/\/admin\/users\/[^/]+\/access/);

  // Bang "Vai tro duoc gan" phai co DUNG 2 dong: purchaser + storekeeper,
  // pham vi "Toan chuoi". Neu chi con 1 dong (nhu vu owner) thi test rot.
  const rolesSection = page.locator("section", {
    has: page.getByRole("heading", { name: "Vai trò được gán" }),
  });
  const rolesTable = rolesSection.locator("table");
  await expect(
    rolesTable.getByText("purchaser", { exact: true }),
  ).toBeVisible();
  await expect(
    rolesTable.getByText("storekeeper", { exact: true }),
  ).toBeVisible();
  await expect(rolesTable.locator("tbody tr")).toHaveCount(2);
  await expect(
    rolesTable.getByText("Toàn chuỗi", { exact: true }).first(),
  ).toBeVisible();
});
