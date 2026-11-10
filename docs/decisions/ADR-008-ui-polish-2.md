# ADR-008 — UI polish giai đoạn 2: PageHeader + bảng chuẩn + Board PR/PO + jump search mở rộng

- Ngày: 10/11/2026
- Trạng thái: Đã chấp nhận (giai đoạn 2; tiếp ADR-006)
- Liên quan: chỉ thị Duy 10/11 07:34 (giao diện chưa đẹp, khó dùng — đợt riêng
  sau MVP-D, trước go-live), ADR-006 (vỏ ClickUp giai đoạn 1), AGENTS.md §3
  quy tắc 10/11 (kiểm quyền không kiểm vai trò; chuỗi tiếng Việt trong
  `vi.ts`), T-047 (test smoke S1–S3/R1–R5)

## Bối cảnh

Giai đoạn 1 (commit cdea736) dựng vỏ app ClickUp — sidebar, topbar, tokens,
`PageHeader` / `DocStatusBadge` / `DataTable` / jump search — và restyle mẫu
Tổng quan + danh sách PR/PO. Các màn còn lại vẫn chạy dưới vỏ mới nhưng giữ
ngôn ngữ cũ: tiêu đề `text-xl`/`text-2xl` rời rạc, bảng `px-4 py-3` đầu cột
chữ thường, chip lọc `bg-primary`, sub-nav mỗi khu một kiểu (pill đen,
pill tím, pill trắng), trạng thái hiện chữ thô ở nhiều danh sách tài chính,
`/master/items` không có h1/h2 nào (S3 chỉ kiểm `main h1, main h2`).

## Quyết định

1. **PageHeader cho mọi màn desktop khu khách sạn.** Mọi `h1` trong
   `src/app/(app)/[property]/**` và các component chi tiết/list của chúng
   đều chuyển sang `PageHeader` (tiêu đề + mô tả + nút hành động). Tiêu đề
   giữ nguyên từng chữ (vd "Tồn kho", "Lịch sử cảnh báo & gửi thông báo" —
   S3 kiểm đúng chuỗi này); trang chi tiết lấy `doc_no` làm tiêu đề, badge
   trạng thái làm mô tả. Hai trang detail tài chính (hóa đơn, đề nghị thanh
   toán) trước đây có 2 `h1` (tiêu đề trang + tiêu đề component) — bỏ `h1`
   cấp trang, component giữ `h1` duy nhất qua `PageHeader`.
2. **Bảng đọc chuẩn DataTable, restyle tại chỗ thay vì đổi sang component
   `DataTable`.** Các danh sách kho/tài chính/trả hàng/kiểm kê dùng
   server-component + phân trang bằng link URL; chuyển chúng sang
   `DataTable` (client + `router.push`) sẽ đổi cơ chế phân trang — vượt
   phạm vi "visual/layout only". Thay vào đó, mọi bảng đọc được restyle
   theo đúng class của `DataTable`: thead `bg-muted/40`, đầu cột viết hoa
   11px semibold tracking rộng, dòng `py-3` cao 48px, `border-t
   hover:bg-muted/40`, ô `px-3 py-3 align-middle`, khung `rounded-lg
   border bg-card` (bỏ `shadow-sm`/`rounded-xl`). Áp dụng cho 34 bảng
   (danh sách + chi tiết dòng) ở kho, nhận hàng, tài chính, kiểm kê,
   cảnh báo, minibar, hợp đồng, master. `DataTable` vẫn là component dùng
   cho các list client (PR/PO, tạm ứng, vật tư, báo cáo) — không đổi API.
3. **Bảng trong form nhập liệu GIỮ gọn.** Bảng dòng có ô input
   (`invoice-form`, `payment-request-form`, `pr-form`, `po-form`,
   `contract-form`, `market-order-form`, `advance-settle-form`,
   `no-invoice-form`, form đếm) giữ `py-2` — dòng 48px làm form nhập dài
   gấp rưỡi mà không thêm giá trị đọc. Xem Q137.
4. **Board view cho PR/PO — chỉ đọc, nhóm trang hiện tại (Q120: LÀM).**
   `ViewToggle` (List/Bảng) + `BoardView` mới (`src/components/shell/`):
   nhóm các dòng đã tải của trang hiện tại theo cột trạng thái, thẻ bấm
   vào mở chi tiết, ghi rõ trên màn hình là chỉ nhóm trang hiện tại.
   KHÔNG kéo-thả: kéo PR/PO sang cột khác phải gọi RPC duyệt/hủy/ghi sổ
   tương ứng, không phải đổi cột đơn thuần; phân trang server (20
   dòng/trang) cũng không đủ dữ liệu cho board toàn bộ. Kéo-thả ghi ở
   Q133. Mặc định vẫn List.
5. **Jump search mở rộng lên ~70 đích (Q121: làm phần khả thi).** Index
   tĩnh thêm mọi màn con còn lại: PR/PO, lịch kỳ dịch vụ, phiếu lĩnh/
   điều chuyển/xuất/hủy/kiểm kê/tồn kho, hóa đơn/công nợ/tạm ứng/đề nghị/
   bảng kê (kể cả trang tạo mới), minibar lễ tân + buồng phòng, PMS ngày,
   10 báo cáo (mỗi báo cáo là 1 đích, lọc theo đúng mã quyền
   `report.view.rpt_*`), toàn bộ danh mục, quy tắc duyệt/cảnh báo, đổi
   mật khẩu. Vẫn chỉ tìm chức năng, không tìm dữ liệu.
6. **Tìm theo số chứng từ/mã hàng/tên NCC (Q121 phần còn lại): KHÔNG
   làm.** Không thể phân giải `doc_no` → id ở client (index tĩnh, không
   có backend tìm kiếm); cần RPC tìm kiếm mới + quyết định phạm vi quyền
   xem kết quả. Ghi ở Q134.
7. **Sub-nav 5 khu thống nhất 1 kiểu tab.** `ProcurementNav` (đã chuẩn
   giai đoạn 1) làm mẫu: tab gạch chân `border-brand text-brand` khi
   active, cuộn ngang khi hẹp. `FinanceNav`, `MasterNav`, `ReportsNav`,
   `InventoryNav` đổi từ pill (đen/tím/trắng, mỗi khu một kiểu) sang đúng
   mẫu này. Không đổi logic ẩn/hiện theo quyền của từng nav.
8. **DocStatusBadge mở rộng sang 4 danh sách tài chính.** Hóa đơn,
   đề nghị thanh toán, tạm ứng (khu tài chính), bảng kê không hóa đơn:
   trạng thái chữ thô → `DocStatusBadge` (mọi mã của 4 danh sách này đã
   có trong map của badge). Trạng thái ngoài chứng từ — minibar
   (`charged`/`waived`/`late_charge`), hợp đồng
   (`active`/`suspended`/`expired`), lịch dịch vụ — KHÔNG có trong map
   nên giữ nhãn riêng (badge sẽ hiện "Không rõ trạng thái" nếu ép dùng).
   Xem Q136.
9. **Chip lọc trạng thái chuẩn brand.** `StatusFilter` (kho),
   chip phiếu trả, chip vật tư giữ nguyên hình chip tròn nhưng trạng thái
   đang chọn đổi từ `bg-primary` (đen) sang `border-brand/40
   bg-brand/10 text-brand` — cùng ngôn ngữ với nav active/tab active.
10. **Thanh lọc chuẩn h-9 + icon tìm kiếm.** `DocSearchForm` (kho),
    lọc tồn kho, lọc thẻ kho, lọc PMS ngày, lọc phiếu trả, tìm kiếm tạm
    ứng (khu thu mua) đổi sang mẫu của PR-list: input `h-9` có icon
    Search, select `h-9`, nút outline `h-9`, focus ring brand.
11. **Thẻ (card) chuẩn `rounded-lg`, bỏ `shadow-sm`.** 65 vị trí
    `rounded-xl border bg-card` trong khu khách sạn đổi sang `rounded-lg`
    (khớp `DataTable`); dialog giữ `rounded-xl` riêng của nó. Tổng quan
    (đã làm giai đoạn 1) không đụng.
12. **Link "Đổi mật khẩu" vào menu người dùng (Q130: LÀM theo khuyến
    nghị).** Topbar thêm mục "Đổi mật khẩu" (icon `KeyRound`) trỏ
    `/settings/password`, trên nút Đăng xuất. Link cũ trong nav
    `/admin/layout` giữ nguyên (không xóa — quản trị vẫn thấy ở đó).
13. **Không đổi:** `/m/*` (MobileNav + h1 riêng) và `/admin/*`
    (layout + bảng riêng) giữ nguyên; không migration, không dependency
    mới, không đổi quyền/logic/nghiệp vụ; tiền/số vẫn do Postgres tính.
    Chuỗi mới vào `vi.ts` (`shell.listView/boardView/boardNote`,
    `auth.account`); chuỗi hard-code có sẵn trong component (vd "Thiếu
    quy đổi", "★ Key Items" ở items-list) KHÔNG dọn trong đợt này — xem
    Q139.

## Hệ quả

- `/master/items` lần đầu có `h1` (`PageHeader` ở `ItemsList`) — trước
  đây trang không có h1/h2 nào ngoài dialog chưa mở, S3 kiểm
  `main h1, main h2` chỉ "may" qua nhờ dialog; nay chắc chắn xanh.
- Board PR/PO nhóm đúng trang hiện tại (20 dòng) — người dùng lọc theo
  trạng thái rồi bật Board sẽ thấy đủ cột của bộ lọc đó; Board không
  thay thế phân trang, không đổi trạng thái.
- Jump search giờ bao phủ toàn bộ route desktop; đích nào cũng lọc theo
  quyền của mục cha (báo cáo lọc theo từng mã `report.view.rpt_*`).
- Rủi ro chính của đợt này là restyle hàng loạt bằng script (614 lần
  thay class bảng + 65 bo tròn): đã kiểm bằng `git diff` từng nhóm, chạy
  lại script cho kết quả 0 (idempotent), và verify ở mục dưới. Một lỗi
  thật đã bắt được khi rà diff: script header master sinh
  `title={{...}}` (double-brace) ở 8 file — đã sửa trước khi verify.

## Kiểm chứng (chạy trên worktree, trước commit)

- `eslint` exit 0 (0 lỗi, 0 cảnh báo — 2 warning `vi` thừa đã gỡ).
- `pnpm typecheck` (`next typegen && tsc --noEmit`) exit 0.
- `prettier --check .` exit 0.
- `next build` với env dummy exit 0.
- Playwright public (`tests/e2e/readonly/public.spec.ts`) 5/5 PASS trên
  local build (`next start -p 3100`, Chrome for Testing).
- Route check bằng curl trên local build: 37 route, tất cả trả 200,
  không có 404.
- `git merge-tree origin/main feat/ui-polish-2`: sạch, không conflict
  (trả về tree `bd2aeb1a756c5208db78bd4ad5c4a04fa55665a6`, không có mục
  conflict nào — `origin/main` không nhích từ lúc tách nhánh).
