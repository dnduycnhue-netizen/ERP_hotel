import {
  BarChart3,
  BedDouble,
  Bell,
  Boxes,
  CalendarDays,
  ClipboardList,
  Hotel,
  LayoutDashboard,
  Package,
  PackageCheck,
  Settings,
  Wallet,
  UtensilsCrossed,
  type LucideIcon,
} from "lucide-react";
import { vi } from "@/i18n/vi";
import { REPORT_CODES, getReportMeta } from "@/features/report/definitions";

/**
 * Điều hướng chính của app (ADR-006): 1 nguồn sự thật duy nhất.
 * Tập mã quyền của từng mục được chép 1-1 từ 11 component `*Link` cũ
 * (đã xóa khi thay header bằng sidebar). Mục nào người dùng không có
 * quyền nào trong tập thì ẩn — kiểm bằng mã quyền, KHÔNG kiểm tên vai
 * trò (AGENTS.md quy tắc 10).
 */

export type NavGroupId =
  "overview" | "operations" | "housekeeping" | "insights" | "system";

export type NavItem = {
  key: string;
  group: NavGroupId;
  label: string;
  href: (propertyId: string) => string;
  /** Tiền tố đường dẫn để đánh dấu mục đang mở. */
  matchPrefix: (propertyId: string) => string;
  icon: LucideIcon;
  visible: (permissions: ReadonlySet<string>) => boolean;
};

const hasAny =
  (...codes: string[]) =>
  (permissions: ReadonlySet<string>): boolean =>
    codes.some((code) => permissions.has(code));

const REPORT_PERMISSIONS = REPORT_CODES.map(
  (code) => getReportMeta(code).permission,
);

export const NAV_GROUPS: { id: NavGroupId; label: string }[] = [
  { id: "overview", label: vi.shell.groups.overview },
  { id: "operations", label: vi.shell.groups.operations },
  { id: "housekeeping", label: vi.shell.groups.housekeeping },
  { id: "insights", label: vi.shell.groups.insights },
  { id: "system", label: vi.shell.groups.system },
];

export const NAV_ITEMS: NavItem[] = [
  {
    key: "dashboard",
    group: "overview",
    label: vi.property.dashboard,
    href: (propertyId) => `/${propertyId}`,
    matchPrefix: (propertyId) => `/${propertyId}`,
    icon: LayoutDashboard,
    visible: () => true,
  },
  {
    key: "procurement",
    group: "operations",
    label: vi.procurement.title,
    href: (propertyId) => `/${propertyId}/procurement/pr`,
    matchPrefix: (propertyId) => `/${propertyId}/procurement`,
    icon: ClipboardList,
    visible: hasAny(
      "pr.create",
      "pr.approve",
      "po.create",
      "po.view",
      "service.contract.manage",
      "service.accept",
    ),
  },
  {
    key: "receiving",
    group: "operations",
    label: vi.receiving.receivingTitle,
    href: (propertyId) => `/${propertyId}/receiving/returns`,
    matchPrefix: (propertyId) => `/${propertyId}/receiving`,
    icon: PackageCheck,
    visible: hasAny("receiving.view", "supplier_return.post"),
  },
  {
    key: "inventory",
    group: "operations",
    label: vi.inventory.title,
    href: (propertyId) => `/${propertyId}/inventory/requisitions`,
    matchPrefix: (propertyId) => `/${propertyId}/inventory`,
    icon: Boxes,
    visible: hasAny(
      "requisition.create",
      "requisition.approve",
      "requisition.issue",
      "requisition.receive",
      "transfer.send",
      "transfer.receive",
      "purpose_issue.post",
      "purpose_issue.reverse",
      "waste.propose",
      "waste.approve",
      "waste.approve.large",
      "stock.view_qty",
      "stock.view_value",
    ),
  },
  {
    key: "finance",
    group: "operations",
    label: vi.finance.title,
    href: (propertyId) => `/${propertyId}/finance`,
    matchPrefix: (propertyId) => `/${propertyId}/finance`,
    icon: Wallet,
    visible: hasAny(
      "invoice.manage",
      "invoice.approve",
      "ap.view",
      "payment.request",
      "payment.approve",
      "payment.mark_paid",
      "advance.settle",
    ),
  },
  {
    key: "restaurant",
    group: "operations",
    label: vi.restaurant.title,
    href: (propertyId) => `/${propertyId}/restaurant/kitchen`,
    matchPrefix: (propertyId) => `/${propertyId}/restaurant`,
    icon: UtensilsCrossed,
    visible: hasAny(
      "restaurant.view",
      "restaurant.dish.manage",
      "restaurant.sale.record",
      "restaurant.buffet.manage",
      "restaurant.banquet.manage",
    ),
  },
  {
    key: "frontdesk",
    group: "housekeeping",
    label: vi.minibar.frontdeskTitle,
    href: (propertyId) => `/${propertyId}/frontdesk/minibar`,
    matchPrefix: (propertyId) => `/${propertyId}/frontdesk/minibar`,
    icon: Hotel,
    visible: hasAny(
      "minibar.request_check",
      "minibar.charge.confirm",
      "minibar.waive.request",
      "minibar.waive.approve",
    ),
  },
  {
    key: "pms-daily",
    group: "housekeeping",
    label: vi.pmsDaily.title,
    href: (propertyId) => `/${propertyId}/frontdesk/pms-daily`,
    matchPrefix: (propertyId) => `/${propertyId}/frontdesk/pms-daily`,
    icon: CalendarDays,
    visible: hasAny("pms.input"),
  },
  {
    key: "housekeeping",
    group: "housekeeping",
    label: vi.minibar.housekeepingTitle,
    href: (propertyId) => `/${propertyId}/housekeeping/minibar`,
    matchPrefix: (propertyId) => `/${propertyId}/housekeeping`,
    icon: BedDouble,
    visible: hasAny(
      "minibar.check",
      "minibar.refill",
      "minibar.price.manage",
      "minibar.reconcile",
      "report.view.rpt_minibar",
    ),
  },
  {
    key: "reports",
    group: "insights",
    label: vi.reports.title,
    href: (propertyId) => `/${propertyId}/reports`,
    matchPrefix: (propertyId) => `/${propertyId}/reports`,
    icon: BarChart3,
    visible: hasAny(...REPORT_PERMISSIONS),
  },
  {
    key: "alerts",
    group: "insights",
    label: vi.alerts.title,
    href: (propertyId) => `/${propertyId}/alerts`,
    matchPrefix: (propertyId) => `/${propertyId}/alerts`,
    icon: Bell,
    visible: (permissions) =>
      [...permissions].some((p) => p.startsWith("alert.receive.")),
  },
  {
    key: "master",
    group: "system",
    label: vi.master.title,
    href: (propertyId) => `/${propertyId}/master/items`,
    matchPrefix: (propertyId) => `/${propertyId}/master`,
    icon: Package,
    visible: hasAny(
      "item.view",
      "item.manage",
      "warehouse.manage",
      "room.manage",
      "supplier.view",
      "price.view",
    ),
  },
  {
    key: "admin",
    group: "system",
    label: vi.admin.title,
    href: () => "/admin/roles",
    matchPrefix: () => "/admin",
    icon: Settings,
    visible: hasAny("admin.roles.manage", "admin.users.manage"),
  },
];

export type JumpDestination = {
  label: string;
  groupLabel: string;
  href: (propertyId: string) => string;
  /** Chỉ hiện khi người dùng thấy được mục cha. */
  visible: (permissions: ReadonlySet<string>) => boolean;
};

/**
 * Index tìm kiếm nhảy nhanh ở topbar (ADR-006): chỉ là các đích điều
 * hướng có sẵn, không tìm dữ liệu nghiệp vụ. Nhãn lấy từ `vi.ts`.
 */
export function buildJumpDestinations(propertyId: string): JumpDestination[] {
  const byKey = (key: string): NavItem =>
    NAV_ITEMS.find((item) => item.key === key) as NavItem;
  const item = (key: string, label: string, path: string): JumpDestination => {
    const parent = byKey(key);
    return {
      label,
      groupLabel: parent.label,
      href: () => `/${propertyId}${path}`,
      visible: parent.visible,
    };
  };
  return [
    ...NAV_ITEMS.map((navItem) => ({
      label: navItem.label,
      groupLabel:
        NAV_GROUPS.find((group) => group.id === navItem.group)?.label ?? "",
      href: () => navItem.href(propertyId),
      visible: navItem.visible,
    })),
    item("procurement", vi.procurement.nav.pr, "/procurement/pr"),
    item("procurement", vi.procurement.nav.po, "/procurement/po"),
    item("procurement", vi.procurement.pr.createTitle, "/procurement/pr/new"),
    item("procurement", vi.procurement.nav.approvals, "/procurement/approvals"),
    item("procurement", vi.procurement.nav.market, "/procurement/market/new"),
    item("procurement", vi.procurement.nav.advances, "/procurement/advances"),
    item(
      "procurement",
      vi.procurement.nav.serviceContracts,
      "/procurement/service-contracts",
    ),
    item(
      "procurement",
      vi.service.schedulesTitle,
      "/procurement/service-contracts/schedules",
    ),
    item("receiving", vi.receiving.returnsListTitle, "/receiving/returns"),
    item("inventory", vi.inventory.nav.requisitions, "/inventory/requisitions"),
    item("inventory", vi.inventory.nav.transfers, "/inventory/transfers"),
    item("inventory", vi.inventory.nav.issues, "/inventory/issues"),
    item("inventory", vi.inventory.nav.waste, "/inventory/waste"),
    item("inventory", vi.inventory.nav.stock, "/inventory/stock"),
    item("inventory", vi.inventory.nav.counts, "/inventory/counts"),
    item("inventory", vi.count.openTitle, "/inventory/counts/new"),
    item("restaurant", vi.restaurant.navDishes, "/restaurant/dishes"),
    item("restaurant", vi.restaurant.navKitchen, "/restaurant/kitchen"),
    item("restaurant", vi.restaurant.navSales, "/restaurant/sales"),
    item("restaurant", vi.restaurant.navBuffet, "/restaurant/buffet"),
    item("restaurant", vi.restaurant.navBanquets, "/restaurant/banquets"),
    item("finance", vi.finance.navInvoices, "/finance/invoices"),
    item("finance", vi.finance.newInvoice, "/finance/invoices/new"),
    item("finance", vi.finance.navPayables, "/finance/payables"),
    item("finance", vi.finance.navAdvances, "/finance/advances"),
    item("finance", vi.finance.navPaymentRequests, "/finance/payment-requests"),
    item(
      "finance",
      vi.finance.newPaymentRequest,
      "/finance/payment-requests/new",
    ),
    item(
      "finance",
      vi.finance.navNoInvoiceListings,
      "/finance/no-invoice-listings",
    ),
    item("frontdesk", vi.minibar.frontdeskTitle, "/frontdesk/minibar"),
    item("pms-daily", vi.pmsDaily.frontdeskTitle, "/frontdesk/pms-daily"),
    item("housekeeping", vi.minibar.housekeepingTitle, "/housekeeping/minibar"),
    ...REPORT_CODES.map((code) => {
      const parent = byKey("reports");
      return {
        label: getReportMeta(code).title,
        groupLabel: parent.label,
        href: () => `/${propertyId}/reports/${getReportMeta(code).slug}`,
        visible: (permissions: ReadonlySet<string>) =>
          permissions.has(getReportMeta(code).permission),
      };
    }),
    item("master", vi.master.nav.items, "/master/items"),
    item("master", vi.master.nav.itemGroups, "/master/item-groups"),
    item("master", vi.master.nav.uoms, "/master/uoms"),
    item("master", vi.master.nav.warehouses, "/master/warehouses"),
    item("master", vi.master.nav.rooms, "/master/rooms"),
    item("master", vi.master.nav.outlets, "/master/outlets"),
    item(
      "master",
      vi.master.nav.expenseCategories,
      "/master/expense-categories",
    ),
    item("master", vi.master.nav.suppliers, "/master/suppliers"),
    item("master", vi.master.nav.prices, "/master/prices"),
    item("master", vi.master.nav.import, "/master/import"),
    item("admin", vi.admin.roles, "/admin/roles"),
    item("admin", vi.admin.users, "/admin/users"),
    item("admin", vi.admin.approvalRules, "/admin/approval-rules"),
    item("admin", vi.admin.alertRules, "/admin/alert-rules"),
    item("admin", vi.admin.settings, "/admin/settings"),
    {
      label: vi.password.changePasswordTitle,
      groupLabel: vi.auth.account,
      href: () => "/settings/password",
      visible: () => true,
    },
  ];
}

/** Khớp không dấu, không phân biệt hoa thường (tìm kiếm nhảy nhanh). */
export function normalizeSearchText(text: string): string {
  return text
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase();
}
