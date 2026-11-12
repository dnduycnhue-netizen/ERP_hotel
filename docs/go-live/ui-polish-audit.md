# Audit UI polish — rà soát từng màn desktop (Bước 1)

- **Ngày audit:** 12/11/2026
- **Commit gốc:** `a2a8ccb` (`merge: fix/t013-q218-q219-verified`, branch `feat/ui-polish-audit` tách từ `origin/main`)
- **Phạm vi:** 87 file `page.tsx` trong `src/app/(app)/[property]/` (10 khu) + trang chọn khách sạn + 6 màn `/admin` + `/settings/password`
- **Chuẩn đối chiếu:** `docs/go-live/ui-polish-plan.md` §2 bước 1, ADR-006, ADR-008, `docs/06-UI-UX.md`
- **Phương pháp:** grep + đọc file (không sửa code, không chạy runtime — xem §8 giới hạn). Mỗi màn được đối chiếu qua `page.tsx` + file cùng thư mục route + component con import trực tiếp (tầng 1). Số liệu grep có thể chạy lại — xem Phụ lục.
- **Kết quả ngắn:** vỏ ClickUp đã phủ tốt (PageHeader 64/84 màn, bảng chuẩn 52/87, sub-nav 5/6 khu đã thống nhất). Lệch tập trung ở **khu Nhà hàng (13/13 màn lệch gần như mọi hạng mục)** và **7 màn Thu mua (chi tiết/form thiếu PageHeader)**; còn lại là filter trần rải rác (Bước 3) và vài trạng thái chữ thô.

## 1. Số liệu tổng

| Hạng mục (plan §2 bước 1) | Đạt | Lệch / chưa đạt | Ghi chú |
|---|---|---|---|
| (a) Tiêu đề — `PageHeader` | **64/84** màn thật (76%) | **20 màn** không có | 13 nhà hàng + 7 thu mua (§2). 3 màn redirect không tính. `reports/[code]` chỉ có PageHeader chung của layout, tiêu đề riêng vẫn là `h2` |
| (a) `h1` thô `text-xl`/`text-2xl` ngoài `PageHeader` | — | **13 màn** (nhà hàng) + 6 màn admin + `/settings/password` | `PageHeader` tự render `h1 text-xl` (`page-header.tsx`) — đó là chuẩn, không tính là lệch |
| (b) Bảng đọc chuẩn (`bg-muted/40` hoặc `DataTable`) | **52/87** blob màn | **9 màn** còn thead `bg-muted/50` — toàn nhà hàng | Component `DataTable` tự nó đã chuẩn (`data-table.tsx:74/79/86/101/136`); 20 blob màn dùng `DataTable` |
| (c) Trạng thái `DocStatusBadge` | **35/87** blob màn | Chữ thô: alerts, payables; nhãn riêng (được phép theo ADR-008 QĐ8): minibar, hợp đồng, lịch dịch vụ | Xem §2 từng khu |
| (d) Search + filter có icon | **~19/87** blob màn | Filter trần (select/input không icon, không ô tìm kiếm): finance 5 danh sách, review, returns, nhà hàng, master (trừ items/suppliers) | Mẫu chuẩn: `DocListControls` (kho) + PR/PO list |
| (e) Sub-nav mỗi khu thống nhất kiểu tab gạch chân brand | **5/6 khu** | **Nhà hàng còn pill đen** `bg-primary`; 4 khu không có sub-nav (alerts, frontdesk, housekeeping, receiving) | Xem §3 |
| (f) Nút hành động chính đen `#171717` | ✅ toàn app (theo token) | Không phát hiện CTA tím | `Button` default = `bg-primary` (`button.tsx:10`); `--primary: oklch(0.205 0 0)` (`globals.css:62`); không có `bg-brand` làm nút CTA (chỉ logo sidebar + progress bar mobile) |
| (g) Chuỗi trong `src/i18n/vi.ts` | `vi.ts` được import ở **60/87** `page.tsx` | Hard-code còn nhiều ở component con (đếm thô: **116 dòng** chứa tiếng Việt có dấu trong 87 `page.tsx`; component con chứa phần lớn — vd review `[grId]` ~20 dòng, waste/issues/transfers/requisitions ~13–20 dòng mỗi màn) | ADR-008 QĐ13 đã chốt: chuỗi hard-code có sẵn KHÔNG dọn trong UI-2 — đợt này dọn hay không cần Duy chốt (xem §6) |
| (h) Icon `lucide-react`, không emoji | **0 emoji màu** trong toàn bộ khu khách sạn | **33 dòng** ký tự tượng hình `✓/✕/★/•/○/⚠/≠` thay icon lucide (~15 file component); **toàn bộ module nhà hàng: 0 file import `lucide-react`** (14 file route + 9 file `src/components/restaurant/`) | Xem §2 |

Chú thích ký hiệu dùng trong bảng §2: ✅ đạt · ❌ lệch · ◐ một phần / cần xác minh thêm · — không áp dụng (không có bảng/trạng thái/search ở màn đó).

## 2. Bảng tổng hợp theo từng màn

### 2.1 Tổng quan + Cảnh báo

| Màn | (a) Tiêu đề | (b) Bảng | (c) Trạng thái | (d) Search/Filter | (e) Sub-nav | (f) Nút | (g) Chuỗi | (h) Icon |
|---|---|---|---|---|---|---|---|---|
| `/[property]` (Tổng quan) | ✅ `PageHeader` | — (thẻ KPI) | — | — | — (sidebar) | ✅ | ✅ `vi.*` | ◐ chưa kiểm từng file |
| `/[property]/alerts` | ✅ `PageHeader` (`alerts/page.tsx:35`) | ✅ thead `bg-muted/40` (`alerts-history`) | ❌ chữ thô `statusLabel()` (`alerts-history.tsx:194`, `:20-25`) | ❌ không có search/filter (`Search=0, Input=0, select=0`) | — không có | — | ✅ | ◐ |
| ⚠️ Tổng quan: thẻ KPI dùng `text-2xl` (`page.tsx:185`) và 3 thẻ `rounded-xl … shadow-sm` (`:173, :212, :241`) — **đây là lệch đã được ADR-008 QĐ11 "grandfather"** ("Tổng quan không đụng"), chỉ sửa khi Duy chốt đụng Tổng quan. `finance/page.tsx` cũng có 4 số KPI `text-xl` (`:71, :83, :95, :106`) — là số liệu, không phải tiêu đề. |

### 2.2 Tài chính (11 màn)

| Màn | (a) | (b) | (c) | (d) | (e) | (f) | (g) | (h) |
|---|---|---|---|---|---|---|---|---|
| `finance` (hub) | ✅ | — cards | — | — | ✅ `FinanceNav` tab brand | ✅ | ✅ | ◐ |
| `finance/advances` | ✅ | ✅ thead40 | ✅ Badge | ❌ chỉ 1 select trần (`advance-list.tsx:39`), không ô tìm kiếm | ✅ | ✅ | ✅ | ◐ |
| `finance/advances/[advanceId]` | ✅ | ◐ bảng form (miễn `py-2` theo Q137) | ✅ Badge | — | ✅ | ✅ | ◐ ~27 dòng VN | ◐ |
| `finance/export` (C4) | ✅ | ✅ `DataTable` (`export-tables`) | ✅ Badge | ◐ `export-hub`: select + input ngày, `Search=0` — chưa rõ có ô tìm kiếm không | ✅ | ✅ | ◐ ~18 dòng VN | ◐ |
| `finance/invoices` | ✅ | ✅ thead40 | ✅ Badge | ❌ 2 select trần + input ngày, **không ô tìm kiếm** (`invoice-list.tsx:70-95`) | ✅ | ✅ | ✅ | ◐ |
| `finance/invoices/[invoiceId]` | ✅ qua `invoice-detail` | ✅ thead40 | ✅ Badge | — | ✅ | ✅ | ✅ | ◐ |
| `finance/invoices/new` | ✅ | — form | — | ◐ form có tìm vật tư | ✅ | ✅ | ✅ | ◐ |
| `finance/no-invoice-listings` | ✅ | ✅ thead40 | ✅ Badge | ❌ 1 select trần (`no-invoice-list.tsx:71`) | ✅ | ✅ | ✅ | ◐ |
| `finance/payables` | ✅ | ✅ thead40 (`payables-view`) | ❌ **không Badge, không thấy render trạng thái** trong `payables-view.tsx` | ❌ 1 select trần (`:64`) | ✅ | ✅ | ✅ | ◐ |
| `finance/payment-requests` | ✅ | ✅ thead40 | ✅ Badge | ❌ 2 select trần, không ô tìm kiếm | ✅ | ✅ | ✅ | ◐ |
| `finance/payment-requests/[requestId]` | ✅ qua `payment-request-detail` | ✅ thead40 | ✅ Badge | — | ✅ | ✅ | ◐ ~15 dòng VN | ◐ glyph `✓/•/○` (`payment-request-detail.tsx:190`) |
| `finance/payment-requests/new` | ✅ | — form | — | — | ✅ | ✅ | ✅ | ◐ |

### 2.3 Lễ tân / Buồng phòng (3 + 4 màn)

| Màn | (a) | (b) | (c) | (d) | (e) | (f) | (g) | (h) |
|---|---|---|---|---|---|---|---|---|
| `frontdesk/minibar` | ✅ | — **dạng card, không phải bảng** (`frontdesk-check-list.tsx` không có `<table>`; `hover:bg-muted/50` ở card `:212, :245` không phải thead) | ◐ nhãn riêng minibar (ADR-008 QĐ8 cho phép giữ nhãn riêng, không ép `DocStatusBadge`) | ❌ chỉ 1 select trần, không ô tìm kiếm | — không có sub-nav (layout chỉ chặn quyền) | ✅ | ✅ | ◐ |
| `frontdesk/minibar/[checkId]` | ✅ qua `frontdesk-check-detail` | ✅ thead40 | ◐ như trên | — | — | ✅ | ✅ | ◐ |
| `frontdesk/pms-daily` | ✅ | — form | — | — | — | ✅ | ◐ ~9 dòng VN | ◐ |
| `housekeeping/minibar` (C7) | ✅ | ✅ thead40 (panel đối soát/giá) | ◐ nhãn riêng minibar (QĐ8) | ❌ không có icon `Search` trong `office-price-manager.tsx` | — không có sub-nav | ✅ | ◐ ~22 dòng VN | ◐ |
| `housekeeping/standards` (C7) | ✅ qua `standards-manager` | ✅ `DataTable` (theo blob màn) | ◐ ô `✓` chữ thay icon (`standards-manager.tsx:171`) | ❌ không có `Search` trong manager | — | ✅ | ◐ | ◐ glyph `✓`, `✕` (`:290`) |
| `housekeeping/trolleys` (C7) | ✅ | ✅ `DataTable` (`trolleys-table.tsx`) | ✅ Badge | ◐ chỉ select lọc, không ô tìm kiếm | — | ✅ | ◐ | ◐ |
| `housekeeping/trolleys/[shiftId]` | ✅ | ✅ `DataTable` (`shift-detail-tables`) | ✅ Badge | — | — | ✅ | ◐ | ◐ |

### 2.4 Kho (14 màn thật + 1 redirect)

Mẫu chuẩn của khu: `PageHeader` + thead `bg-muted/40` + `DocStatusBadge` + `DocListControls` (ô tìm kiếm icon `Search`, `h-9`) + `InventoryNav` tab brand.

| Màn | (a) | (b) | (c) | (d) | (e) | (f) | (g) | (h) |
|---|---|---|---|---|---|---|---|---|
| `inventory/counts` | ✅ | ✅ | ✅ | ✅ `DocListControls` | ✅ | ✅ | ◐ | ◐ |
| `inventory/counts/[countId]` | ✅ qua `count-report-view` | ✅ | ✅ | — | ✅ | ✅ | ✅ | ◐ |
| `inventory/counts/new` | ✅ qua `count-open-form` | — form | — | — | ✅ | ✅ | ◐ | ◐ |
| `inventory/issues` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ | ◐ |
| `inventory/issues/[id]` | ✅ | ✅ | ✅ | — | ✅ | ✅ | ◐ | ◐ |
| `inventory/locks` (C1) | ✅ | ✅ thead40 (`locks-day-calendar`) | ✅ (`locks-period-panel`) | — (lịch, không phải danh sách tìm kiếm) | ✅ | ✅ | ◐ ~14 dòng VN | ◐ |
| `inventory/receipts` | ✅ | ✅ | ◐ **không thấy `DocStatusBadge` trong blob màn** (có pill/chip lọc) | ◐ có chuỗi `Search` + placeholder trong blob, chưa xác định là `DocListControls` hay input riêng | ✅ | ✅ | ✅ | ◐ |
| `inventory/requisitions` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ | ◐ |
| `inventory/requisitions/[id]` | ✅ | ✅ | ✅ | — | ✅ | ✅ | ◐ | ◐ |
| `inventory/stock` | ✅ | ✅ | — | ✅ | ✅ | ✅ | ◐ | ◐ |
| `inventory/stock/[warehouseId]` | ✅ | ✅ | — | ✅ | ✅ | ✅ | ◐ | ◐ |
| `inventory/stock/[warehouseId]/[itemId]` | ✅ | ✅ | — | — | ✅ | ✅ | ◐ | ◐ glyph `✓/⚠/≠` (`:187, :193`) |
| `inventory/transfers` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ | ◐ |
| `inventory/transfers/[id]` | ✅ | ✅ | ✅ | — | ✅ | ✅ | ◐ | ◐ |
| `inventory/waste` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ | ◐ |
| `inventory/waste/[id]` | ✅ | ✅ | ✅ | — | ✅ | ✅ | ◐ | ◐ |
| `inventory` (index) | — redirect → `inventory/requisitions` (`inventory/page.tsx:10`) | | | | | | | |

### 2.5 Danh mục (10 màn thật + 1 redirect)

Tất cả manager đều đã có `PageHeader` qua component con; bảng đều qua `DataTable` (chuẩn theo cấu tạo) hoặc thead `bg-muted/40`; `rounded-xl` còn lại chỉ ở **dialog** (`max-w-md/sm rounded-xl … shadow-lg` — ADR-008 QĐ11 giữ dialog `rounded-xl`, không phải lệch).

| Màn | (a) | (b) | (c) | (d) | (e) | (f) | (g) | (h) |
|---|---|---|---|---|---|---|---|---|
| `master/expense-categories` | ✅ | ✅ `DataTable` | — | ◐ không icon `Search` | ✅ `MasterNav` | ✅ | ✅ (~0 dòng VN) | ◐ glyph `✕` (`:191`) |
| `master/import` | ✅ qua `import-wizard` | ✅ thead40 | — | ◐ select | ✅ | ✅ | ✅ | ◐ |
| `master/item-groups` | ✅ | ✅ `DataTable` | — | ◐ không icon `Search` | ✅ | ✅ | ✅ | ◐ glyph `✕` (`:192`) |
| `master/items` | ✅ qua `items-list` | ✅ `DataTable` | — | ✅ có `Search` | ✅ | ✅ | ✅ | ◐ `★ Key Items` (`items-list.tsx:320`) |
| `master/outlets` | ✅ | ✅ `DataTable` | — | ◐ không icon `Search` | ✅ | ✅ | ✅ | ◐ glyph `✕` |
| `master/prices` | ✅ | ✅ thead40 + `DataTable` | — | ◐ không icon `Search` (`Input=8, select=7` — chưa phân biệt ô lọc vs input form) | ✅ | ✅ | ✅ | ◐ glyph `✕` ×4 |
| `master/rooms` | ✅ | ✅ `DataTable` | — | ◐ không icon `Search` | ✅ | ✅ | ✅ | ◐ glyph `✕` |
| `master/suppliers` | ✅ | ✅ thead40 + `DataTable` | — | ✅ có `Search` | ✅ | ✅ | ✅ | ◐ glyph `✕` ×3 |
| `master/uoms` | ✅ | ✅ `DataTable` | — | ◐ không icon `Search` | ✅ | ✅ | ✅ | ◐ glyph `✕` |
| `master/warehouses` | ✅ | ✅ `DataTable` | — | ◐ không icon `Search` | ✅ | ✅ | ✅ | ◐ glyph `✕` |
| `master` (index) | — redirect → `master/items` (`master/page.tsx:9`) | | | | | | | |

### 2.6 Thu mua (15 màn thật + 1 redirect)

| Màn | (a) | (b) | (c) | (d) | (e) | (f) | (g) | (h) |
|---|---|---|---|---|---|---|---|---|
| `procurement/advances` | ✅ qua `advance-list` | ✅ `DataTable` | ✅ Badge | ✅ `Search` | ✅ `ProcurementNav` | ✅ | ✅ | ◐ |
| `procurement/advances/[id]` | ❌ **không `PageHeader`** — chỉ `h2` số chứng từ (`advance-detail.tsx:137`) | — detail | ✅ Badge | — | ✅ | ✅ | ✅ | ◐ glyph `✕` (`:281`) |
| `procurement/approvals` | ✅ qua `approval-inbox` | — cards | ◐ (trạng thái duyệt trong inbox — chưa xác minh badge) | — | ✅ | ✅ | ◐ ~9 dòng VN | ◐ |
| `procurement/market` | ✅ qua `market-list` | ✅ `DataTable` | ✅ Badge | ✅ `Search` | ✅ | ✅ | ✅ | ◐ |
| `procurement/market/new` | ❌ **không `PageHeader`** (form) | — form | — | ◐ form có tìm vật tư | ✅ | ✅ | ✅ | ◐ |
| `procurement/po` | ✅ qua `po-list` | ✅ `DataTable` | ✅ Badge | ✅ `Search` + Board (`ViewToggle`/`BoardView`) | ✅ | ✅ | ✅ | ◐ |
| `procurement/po/[id]` | ❌ **không `PageHeader`** — chỉ `h2` số chứng từ (`po-detail.tsx:173`) | ✅ thead40 | ✅ Badge | — | ✅ | ✅ | ✅ | ◐ glyph `✕` (`:410`) |
| `procurement/po/[id]/edit` | ❌ **không `PageHeader`** (form) | — form | — | ◐ form có tìm vật tư | ✅ | ✅ | ✅ | ◐ |
| `procurement/pr` | ✅ qua `pr-list` | ✅ `DataTable` | ✅ Badge | ✅ `Search` + Board | ✅ | ✅ | ✅ | ◐ |
| `procurement/pr/[id]` | ❌ **không `PageHeader`** — chỉ `h2` số chứng từ (`pr-detail.tsx:167`) | ✅ thead40 (`bg-muted/50` ở `:384, :403` chỉ là `hover:` trên label, không phải thead) | ✅ Badge | — | ✅ | ✅ | ✅ | ◐ glyph `✕` ×2 (`:321, :367`) |
| `procurement/pr/new` | ❌ **không `PageHeader`** (form) | — form | — | ◐ form có tìm vật tư | ✅ | ✅ | ✅ | ◐ |
| `procurement/pr/[id]/edit` | ❌ **không `PageHeader`** (form) | — form | — | ◐ form có tìm vật tư | ✅ | ✅ | ✅ | ◐ |
| `procurement/service-contracts` | ✅ | ✅ thead40 | ◐ nhãn riêng hợp đồng (QĐ8) | ◐ chỉ select, không ô tìm kiếm | ✅ | ✅ | ✅ | ◐ |
| `procurement/service-contracts/[contractId]` | ✅ qua `contract-detail` | — detail | ◐ nhãn riêng + `★ rating` (`contract-detail.tsx:173`) | — | ✅ | ✅ | ✅ | ◐ glyph `★` |
| `procurement/service-contracts/[contractId]/edit` | ✅ | — form | — | — | ✅ | ✅ | ✅ | ◐ |
| `procurement/service-contracts/new` | ✅ | — form | — | — | ✅ | ✅ | ✅ | ◐ |
| `procurement/service-contracts/schedules` | ✅ | — list | ◐ `★ rating` (`schedule-list.tsx:204`) | ◐ chỉ select | ✅ | ✅ | ✅ | ◐ glyph `★` |
| `procurement` (index) | — redirect → `procurement/pr` (`procurement/page.tsx:10`) | | | | | | | |

> Lưu ý: `po-detail.tsx`/`pr-detail.tsx` còn `rounded-xl` ở **dialog** (`:398`, `:313, :359`) — giữ theo QĐ11, không phải lệch.

### 2.7 Nhận hàng (5 màn)

| Màn | (a) | (b) | (c) | (d) | (e) | (f) | (g) | (h) |
|---|---|---|---|---|---|---|---|---|
| `receiving` (index) | ✅ | — cards | — | ❌ không có ô tìm kiếm | — không có sub-nav | ✅ (1 thẻ `shadow-sm` — `receiving/page.tsx:64`, lệch nhỏ) | ✅ | ◐ |
| `receiving/returns` | ✅ | ✅ thead40 | ◐ chip lọc, không thấy `DocStatusBadge` trong blob | ❌ chỉ chip lọc, không ô tìm kiếm | — | ✅ | ✅ | ◐ |
| `receiving/returns/[retId]` | ✅ | ✅ thead40 | ◐ không thấy Badge trong blob | — | — | ✅ | ✅ | ◐ |
| `receiving/review` (C2) | ✅ | ✅ `DataTable` (`review-table.tsx`) | ✅ Badge | ❌ **không có search/filter** trong `review-table.tsx` (grep `Search|placeholder|Input` = 0) | — | ✅ | ◐ ~10 dòng VN | ◐ |
| `receiving/review/[grId]` (C2) | ✅ | ✅ thead40 | ✅ Badge | — (detail) | — | ✅ | ◐ ~20 dòng VN | ◐ |

### 2.8 Báo cáo (2 màn)

| Màn | (a) | (b) | (c) | (d) | (e) | (f) | (g) | (h) |
|---|---|---|---|---|---|---|---|---|
| `reports` (index) | ✅ qua `reports/layout.tsx:35` (`PageHeader` chung "Báo cáo") | — cards | — | — | ✅ `ReportsNav` tab brand | ✅ | ✅ | ◐ |
| `reports/[code]` (C10) | ◐ **chỉ có `PageHeader` chung "Báo cáo" của layout; tiêu đề riêng của từng báo cáo là `h2 text-xl` ×3 nhánh** (`[code]/page.tsx:37, :50, :89`) | ◐ blob màn có `DataTable` — **chưa xác minh thead từng mã báo cáo** (báo cáo render qua `report-view.tsx`) | — | ◐ `report-filters.tsx` có `Search=3, Input=5, select=2` (chủ yếu input ngày) — chưa xác minh có ô tìm kiếm icon không | ✅ | ✅ | ◐ ~17 dòng VN | ◐ |

### 2.9 Nhà hàng (13 màn — lệch nhiều nhất)

**Tất cả 13 màn:** (a) ❌ `h1 className="text-xl font-semibold"` thô, không `PageHeader`; (e) ❌ `RestaurantNav` còn kiểu pill (`restaurant-nav.tsx:49-52`: active = `bg-primary text-primary-foreground`, khác 5 khu còn lại); (d) ❌ input/select lọc trần, **không có icon `Search` trong toàn bộ module**; (h) ❌ **0/14 file route + 0/9 file `src/components/restaurant/` import `lucide-react`**; (g) ✅ chuỗi đã vào `vi.restaurant.*` (điểm sáng duy nhất của khu).

| Màn | (a) | (b) | (c) | (d) | (f) |
|---|---|---|---|---|---|
| `restaurant` (hub) | ❌ `h1 text-xl` (`page.tsx:60`) | — cards link | — | ❌ | ✅ |
| `restaurant/banquets` | ❌ `h1 text-xl` (`:62`) | ❌ thead `bg-muted/50` (`:131`) | ✅ Badge (page import `doc-status-badge`) | ❌ 2 input + 1 select trần (`:82, :91, :100`) | ✅ |
| `restaurant/banquets/[id]` | ❌ `h1 text-xl` (`:59`) | ❌ thead `bg-muted/50` (`:83`) | ✅ Badge | — | ✅ |
| `restaurant/banquets/new` | ❌ `h1 text-xl` (`:25`) | — form | — | — | ✅ |
| `restaurant/buffet` | ❌ `h1 text-xl` (`:57`) | ❌ thead `bg-muted/50` (`:107`) | ✅ Badge | ❌ 2 input trần (`:75, :84`) | ✅ |
| `restaurant/buffet/[id]` | ❌ `h1 text-xl` (`:62`) | ❌ thead `bg-muted/50` (`:80`) | ✅ Badge | — | ✅ |
| `restaurant/buffet/new` | ❌ `h1 text-xl` (`:22`) | — form | — | — | ✅ |
| `restaurant/dishes` | ❌ `h1 text-xl` (`:38`) | ❌ thead `bg-muted/50` (`:93`) | ❌ không Badge | ❌ select + input trần (`:56, :71`) | ✅ |
| `restaurant/dishes/[id]` | ❌ `h1 text-xl` (`:35`) | ❌ thead `bg-muted/50` (`:54`) | ❌ | — | ✅ |
| `restaurant/dishes/new` | ❌ `h1 text-xl` (`:28`) | — form | — | — | ✅ |
| `restaurant/halls` | ❌ `h1 text-xl` (`:28`) | ❌ thead `bg-muted/50` (`hall-manager.tsx:154`) | — | ❌ (xem `hall-manager`) | ✅ |
| `restaurant/kitchen` | ❌ `h1 text-xl` (`:41`) | ❌ thead `bg-muted/50` ×2 (`:77, :221`) | — (không có cột trạng thái) | ❌ input trần (`:51`) | ✅ nút `bg-primary` (`:205`) |
| `restaurant/sales` | ❌ `h1 text-xl` (`:67`) | ❌ thead `bg-muted/50` ×2 (`:163, :220`) | ✅ Badge | ❌ 2 input trần (`:76, :85`) | ✅ |

### 2.10 Trang chọn khách sạn + Admin + Đổi mật khẩu

| Màn | Kết quả |
|---|---|
| `src/app/(app)/page.tsx` (chọn KS) | Chỉ nhánh "không có quyền vào KS nào" mới render UI: `h1 text-xl` (`:27`) + thẻ `rounded-xl … shadow-sm` (`:26`); còn lại redirect về KS (`:48-52`). Mức ưu tiên thấp. |
| `/admin/*` — 6 màn (`roles`, `users`, `settings`, `organizations`, `approval-rules`, `alert-rules`) | ❌ **cả 6 đều `h1 className="text-2xl font-bold"` thô, không `PageHeader`** (`roles/page.tsx:36`, `users/page.tsx:23`, `settings/page.tsx:37`, `organizations/page.tsx:25`, `approval-rules/page.tsx:43` (+ `h2 text-xl` `:62`), `alert-rules/page.tsx:33`). Bảng: `organizations-table.tsx` dùng `DataTable` ✅; các bảng còn lại thead trần (`users/page.tsx:62-63`: `<thead><tr className="border-b text-left text-muted-foreground">` — không `bg-muted/40`, không uppercase 11px). Layout admin riêng (`admin/layout.tsx:89` header riêng). **Đây là phạm vi Q122 — chỉ ghi nhận, không sửa trước khi Duy chốt.** |
| `/settings/password` | ❌ `h1 className="mt-3 text-2xl font-semibold"` (`settings/password/page.tsx:32`), không `PageHeader`. Ưu tiên thấp (màn ít dùng). |

## 3. Màn lệch ưu tiên cao (top 10)

1. **Nhà hàng — cả 13 màn** (§2.9): lệch đồng loạt 4 hạng mục (tiêu đề, bảng, filter, icon) + sub-nav pill. Là khối lệch lớn nhất, nhưng pattern lặp lại nên sửa theo lô 1 mẫu.
2. **Thu mua — 3 màn chi tiết** `pr/[id]`, `po/[id]`, `advances/[id]`: thiếu `PageHeader` (ADR-008 QĐ1 yêu cầu chi tiết lấy `doc_no` làm tiêu đề qua `PageHeader`; hiện chỉ có `h2 text-lg font-mono`).
3. **Thu mua — 4 màn form** `pr/new`, `pr/[id]/edit`, `po/[id]/edit`, `market/new`: thiếu `PageHeader` (đối chiếu: `invoices/new`, `payment-requests/new` đã có `PageHeader` ở `page.tsx`).
4. **Báo cáo — `reports/[code]` (C10)**: tiêu đề riêng của báo cáo là `h2 text-xl`; `PageHeader` của layout chỉ mang tên chung "Báo cáo".
5. **Tài chính — 5 danh sách filter trần** (Bước 3): `invoices`, `payment-requests`, `advances`, `no-invoice-listings`, `payables` — chỉ select/input ngày trần, không ô tìm kiếm có icon.
6. **Nhận hàng — `receiving/review` (C2)**: bảng đã chuẩn (`DataTable`) nhưng không có search/filter.
7. **Cảnh báo — `alerts`**: trạng thái gửi hiện chữ thô (`statusLabel`, `alerts-history.tsx:194`) + không có search/filter.
8. **Danh mục — 7 manager** (trừ `items`, `suppliers` đã có search): `prices`, `warehouses`, `rooms`, `outlets`, `uoms`, `item-groups`, `expense-categories` — không icon `Search` (cần đọc từng file khi sửa để phân biệt ô lọc với input trong dialog).
9. **Tài chính — `payables`**: không có badge/trạng thái hiển thị + filter trần (kèm mục 5).
10. **Ký tự tượng hình thay icon lucide** (~15 file): `★ Key Items` (`items-list.tsx:320`), `★ rating` (`contract-detail.tsx:173`, `schedule-list.tsx:204`), `✓/•/○` (`payment-request-detail.tsx:190`), `✓` (`standards-manager.tsx:171`, `stock/[warehouseId]/[itemId]/page.tsx:187`), `✕` nút đóng dialog (nhiều manager + `po-detail.tsx:410`, `pr-detail.tsx:321, :367`, `advance-detail.tsx:281`).

### Trạng thái các màn C1/C2/C4/C5/C7/C10 (Bước 2)

| Màn | Kết luận |
|---|---|
| C1 `inventory/locks` (khóa ngày) | ✅ Gần đạt: `PageHeader` + thead40 + Badge đều có. Chỉ còn chuỗi hard-code ~14 dòng + không có search (không áp dụng cho lịch). **Sửa ít nhất.** |
| C2 `receiving/review` + `review/[grId]` (duyệt ảnh) | ✅ Gần đạt: `PageHeader` + `DataTable`/thead40 + Badge đều có. Còn thiếu: search/filter ở danh sách review + chuỗi ~10–20 dòng. |
| C4 `finance/export` (xuất tài chính) | ◐ `PageHeader` + `DataTable` + Badge có. Còn thiếu: xác minh search ở `export-hub` (hiện `Search=0`) + chuỗi ~18 dòng. |
| C5 `admin/organizations` (org/property) | ❌ Tiêu đề `h1 text-2xl` thô (chờ Q122); bảng ✅ `DataTable`. Không sửa trước khi Duy chốt Q122. |
| C7 `housekeeping/minibar`, `standards`, `trolleys` | ◐ `minibar`: PH + thead40 ✅, thiếu search. `standards`: PH + `DataTable` ✅, thiếu search + glyph `✓`. `trolleys`: PH + `DataTable` + Badge ✅, chỉ select lọc. |
| C10 `reports/[code]` (báo cáo/matview) | ◐ Tiêu đề riêng `h2 text-xl` (mục 4 top 10); thead từng mã báo cáo chưa xác minh. |

## 4. Gợi ý thứ tự sửa (đề xuất, chưa phải quyết định)

1. **Nhà hàng (13 màn)** — 1 pattern lặp lại: `PageHeader` + thead `bg-muted/40` + search/filter mẫu PR-list + `RestaurantNav` đổi sang tab gạch chân brand + thêm icon lucide. Làm trước vì khối lượng lệch lớn nhất và đồng nhất.
2. **Thu mua 7 màn thiếu `PageHeader`** — chi tiết lấy `doc_no` làm tiêu đề (đúng ADR-008 QĐ1), form thêm `PageHeader` như `invoices/new`. Giữ nguyên từng chữ tiêu đề (test S3 kiểm đúng chuỗi).
3. **`reports/[code]`** — đưa tên báo cáo vào `PageHeader` (thay `h2 text-xl`), xác minh thead từng mã báo cáo.
4. **Bước 3 — filter trần**: finance 5 danh sách → `receiving/review` + `returns` → nhà hàng → master 7 manager. Giữ nguyên cơ chế lọc/phân trang link URL (ADR-008 QĐ2).
5. **Trạng thái chữ thô**: `alerts` (pill cho trạng thái gửi), `payables` (xác minh có cần cột trạng thái không), nhãn minibar/hợp đồng giữ nguyên theo QĐ8.
6. **Glyph → lucide**: `★/✓/✕/•/○` ở ~15 file (§3 mục 10).
7. **Tổng quan + chọn KS + `/settings/password`**: chỉ khi Duy chốt đụng (Tổng quan đang được ADR-008 QĐ11 giữ nguyên).
8. **Admin (6 màn)**: chỉ sau khi Duy chốt Q122.

## 5. Bước 5 — kiểm tra bằng code (KHÔNG quyết thay Duy)

### Q118 — Sidebar thu gọn có nhớ lựa chọn bằng localStorage không?

**Kết luận bằng code: CÓ, cơ chế đã đầy đủ; không thấy lỗi rõ ràng. Chưa kiểm chứng bằng chạy thật.**

- Key: `erp-sidebar-collapsed` (`src/components/shell/app-shell.tsx:8`).
- Đọc qua `useSyncExternalStore`: `getCollapsedSnapshot()` đọc `localStorage.getItem(key) === "1"` (`:19-24`); `getServerSnapshot = () => false` — server render luôn mở (khớp ADR-006 "mặc định MỞ trên desktop", tránh lệch hydration).
- Ghi khi bấm nút thu gọn: `toggleCollapsed()` đọc snapshot mới rồi ghi `"1"`/`"0"` (`:59-68`), có `try/catch` khi localStorage không dùng được (chế độ riêng tư).
- Đồng bộ đa tab: listener `storage` + custom event `erp-sidebar-collapsed-change` (`:9, :35-44, :70`).
- Sidebar áp dụng đúng 2 cỡ: `w-66` (264px) / `w-[68px]` (`app-sidebar.tsx`), nút thu gọn chỉ hiện desktop (`hidden … lg:flex`), mobile dùng drawer riêng (`mobileOpen`).
- Điểm nhỏ (không phải lỗi): nếu localStorage đang lưu "thu gọn", lần render đầu sau hydration sidebar sẽ nháy từ mở → thu gọn (do `getServerSnapshot` luôn `false`). Chỉ là hiện tượng nháy, không sai trạng thái.
- **Cần Duy/chạy thật kiểm chứng:** bấm thu gọn → reload → còn thu gọn không; mở 2 tab, đổi ở tab này, tab kia có đổi theo không.

### Q123 — User menu hiện hiển thị gì, cần thêm gì?

**Kết luận bằng code: menu hiện chỉ có 2 mục, KHÔNG có email/tên người dùng.**

- `src/components/shell/app-topbar.tsx`: nút avatar là icon `UserRound` trong vòng tròn (`h-9 w-9 rounded-full`), không ảnh đại diện, không tên, không email.
- Menu dropdown (`w-44`): chỉ 2 mục — "Đổi mật khẩu" (`/settings/password`, icon `KeyRound`) và "Đăng xuất" (server action `signOut`).
- Nguyên nhân đã được ADR-006 QĐ6 ghi trước: layout khu khách sạn không có email vì không gọi thêm `getUser()` — `AppTopbar` hiện chỉ nhận props `propertyId, properties, canViewAlerts, unreadAlerts, onOpenMobile`, không nhận thông tin người dùng.
- **Cần thêm (đề xuất để Duy chốt):** truyền email + tên hiển thị từ server layout vào `AppTopbar`, thêm khối đầu menu (tên + email, không bấm được) trên mục "Đổi mật khẩu". Lưu ý nhỏ: `aria-label` của nút avatar hiện là `vi.auth.signOut` — khi menu có thêm mục thì nhãn này gây hiểu nhầm, nên đổi thành "Menu người dùng".

### Q122 + Bước 4 — đang chờ Duy chốt (không làm trong audit này)

- **Q122** (admin có vào vỏ ClickUp không?): chưa có quyết định. Hiện trạng ghi nhận ở §2.10: admin giữ layout riêng, 6 màn `h1 text-2xl` thô, bảng thead trần (trừ `organizations` dùng `DataTable`).
- **Bước 4** (Board cho module khác ngoài PR/PO): chưa có quyết định. Hiện trạng: Board chỉ có ở PR/PO (`ViewToggle` + `BoardView` dùng trong `pr-list.tsx`, `po-list.tsx`), chỉ đọc, nhóm trang hiện tại.

## 6. Câu hỏi cần Duy chốt trước khi sửa (gom lại)

1. Q122: admin vào vỏ ClickUp hay giữ riêng? (quyết định 6 màn admin + có restyle `h1 text-2xl` không)
2. Bước 4: có làm Board cho nhận hàng / kho / tài chính không (cùng pattern PR/PO, chỉ đọc)?
3. Chuỗi hard-code trong component (ADR-008 QĐ13 từng chốt "không dọn trong UI-2") — đợt này có dọn sang `vi.ts` không, hay vẫn để lại?
4. Tổng quan có đụng không (thẻ `rounded-xl`/`shadow-sm`, KPI `text-2xl`) — ADR-008 QĐ11 đang giữ nguyên.
5. 4 khu không có sub-nav (alerts, frontdesk, housekeeping, receiving) — có cần thêm sub-nav thống nhất không, hay giữ vậy?
6. Nhãn trạng thái riêng (minibar `charged`/`waived`, hợp đồng, lịch dịch vụ) — giữ nhãn riêng theo QĐ8 hay đưa vào `DocStatusBadge`?

## 7. Ranh giới đã giữ trong audit này

- Không sửa bất kỳ file code nào; chỉ tạo file audit này. Không đụng `/m/*`, không đụng logic/RPC/quyền.
- Bảng trong form nhập liệu giữ `py-2` gọn là **đúng chuẩn** (ADR-008 QĐ3 / Q137) — audit không tính đó là lệch.
- Dialog giữ `rounded-xl` là **đúng chuẩn** (ADR-008 QĐ11) — audit không tính đó là lệch.
- `DataTable` chỉ dùng ở trang demo dev là **đúng thiết kế** (plan §1); các danh sách server-component restyle tại chỗ, không chuyển sang `DataTable`.
- Không đổi tiêu đề nào (test S3 kiểm đúng từng chữ).

## 8. Giới hạn của audit này (đọc trước khi dùng số liệu)

- Đối chiếu ở mức `page.tsx` + file cùng thư mục route + component con import trực tiếp (tầng 1). Component tầng sâu hơn (vd panel lồng trong manager) có thể còn lệch mà audit chưa chạm tới — khi sửa từng màn nên đọc lại file đó.
- Cột (h) Icon: chỉ kiểm chắc 2 điểm — không có emoji màu trong khu khách sạn, và module nhà hàng 0 import `lucide-react`. Các màn khác ghi ◐ vì chưa kiểm import lucide từng file.
- Cột (g) Chuỗi: số "dòng VN" là đếm thô (dòng chứa ký tự tiếng Việt có dấu, trừ dòng import) — gồm cả chuỗi hard-code lẫn comment; dùng để so sánh tương đối, không phải số chuỗi cần dọn chính xác.
- Cột (d) ở một số màn ghi ◐ vì file có `<input>`/`<select>` nhưng chưa phân biệt được đâu là ô lọc, đâu là input trong form/dialog — cần đọc file khi làm Bước 3.
- Không chạy app thật (không có browser task trong đợt này): Q118/Q123 kết luận bằng code; mọi hạng mục visual khác kết luận bằng class trong code, chưa kiểm chứng bằng mắt trên trình duyệt.

## Phụ lục — lệnh grep dùng để đối chiếu (chạy từ gốc repo, commit `a2a8ccb`)

```bash
# Tổng số màn
find "src/app/(app)/[property]" -name page.tsx | wc -l   # 87
# PageHeader trong page.tsx: 40/87; cộng component con/layout => 64/84 màn thật
grep -rln "PageHeader" "src/app/(app)/[property]" --include=page.tsx | wc -l
# h1 thô text-xl/2xl trong file page (trừ PageHeader): 13, toàn nhà hàng
grep -rn "text-xl\|text-2xl" "src/app/(app)/[property]" --include=page.tsx
# thead cũ: bg-muted/50 ở thead/tr chỉ còn nhà hàng (9 màn)
grep -rn "bg-muted/50" "src/app/(app)/[property]" --include=*.tsx
# DataTable tự chuẩn: thead bg-muted/40, 11px uppercase, py-3
grep -n "bg-muted/40\|text-\[11px\]\|py-3\|rounded-lg border bg-card" src/components/common/data-table.tsx
# DocStatusBadge: 35/87 blob màn; Search icon + placeholder: ~19/87
# Sub-nav: 5 khu tab brand (border-brand) — restaurant-nav.tsx:49-52 còn pill bg-primary
# Không emoji màu trong khu khách sạn (python: regex [\U0001F300-\U0001FAFF\u2600-\u27BF]); 33 dòng glyph ✓/✕/★/•/○
# Restaurant 0 import lucide: grep -rln "lucide-react" "src/app/(app)/[property]/restaurant" src/components/restaurant/  # 0
# Q118: src/components/shell/app-shell.tsx:8,19-24,59-68 ; Q123: src/components/shell/app-topbar.tsx
```
