# ADR-006 — Vỏ app kiểu ClickUp: sidebar + tokens + pattern dùng chung (UI giai đoạn 1)

- Ngày: 10/11/2026
- Trạng thái: Đã chấp nhận (giai đoạn 1; Duy chốt mẫu ClickUp 10/11 10:13)
- Liên quan: chỉ thị Duy 10/11 07:34 (giao diện chưa đẹp, khó dùng — làm đợt riêng sau MVP-D, trước go-live), AGENTS.md §2/§3 (Tailwind + shadcn/ui + lucide; kiểm quyền không kiểm vai trò; chuỗi tiếng Việt trong `vi.ts`), docs/06-UI-UX.md §1 (màu trạng thái chứng từ), T-047 (test smoke S1–S3/R1–R5 — vỏ mới phải giữ các test này xanh)

## Bối cảnh

### Mẫu tham chiếu: app ClickUp 3.0 (không phải trang marketing clickup.com)

Đã nghiên cứu ảnh chụp giao diện thật của app (2 ảnh đã xem trực tiếp:
`clickup.com/blog` List view 2024-12 + dashboard ClickUp 3.0; cộng tài liệu
help.clickup.com về List/Board view và status). Ngôn ngữ thiết kế rút ra:

- **Bố cục 3 vùng:** sidebar trái (logo + Home/Inbox + Spaces với ô chữ cái
  màu + Dashboards/Docs + avatar cuối) + thanh view phía trên nội dung
  (List/Board/Calendar + Search + Customize) + vùng nội dung trắng.
- **Danh sách kiểu List:** nhóm theo trạng thái, tiêu đề nhóm là nhãn màu
  đặc (ISSUES FOUND hồng, REVIEW vàng, READY tím); cột tiêu đề viết hoa
  nhỏ, chữ xám; mỗi dòng ~48px: ô vuông màu, tên, avatar người phụ trách,
  pill trạng thái (nền nhạt + chữ đậm màu: INITIATION hồng, PLANNING tím,
  EXECUTION vàng), cờ ưu tiên (Urgent đỏ, High vàng, Low xám).
- **Pill trạng thái:** bo tròn hoàn toàn (9999px), chữ ngắn, màu là tín
  hiệu chính — luôn kèm chữ, không chỉ dùng màu.
- **Màu:** nền trắng, chữ gần đen (#202020), chữ phụ xám (#646464/#838383),
  viền nhạt (#E8E8E8), tím nhấn #7B68EE (brand ClickUp; tài liệu style
  ghi #6647F0 cho bản web marketing — app dùng #7B68EE làm mốc), xanh
  dương #0091FF cho link, nút hành động chính tô đen đặc.
- **Chữ:** 14px thân bài, tiêu đề đậm sát nhau, khoảng trắng vừa phải,
  không gradient trang trí.

### Điểm khó dùng của UI hiện tại (kiểm kê 10/11/2026, 84 route)

- Header: 11 link text xếp ngang trong flex-wrap — trên laptop hẹp nó
  gãy thành 2–3 hàng; không icon, không nhóm theo luồng nghiệp vụ, không
  trạng thái active (trừ Báo cáo/Cảnh báo), thứ tự không theo quy trình
  làm việc (Thu mua → Nhận hàng → Kho → Tài chính).
- Không có sidebar: vào trang sâu (vd chi tiết PO) thì mất bối cảnh đang
  ở khu nào; quay lại phải dùng nút trình duyệt.
- Tổng quan: banner hero gradient, icon module bằng emoji (📦🏢👥⚙️)
  thay vì lucide, trạng thái hiện dạng chữ thô "● Đang hoạt động", thẻ
  KPI chú thích 11px, thẻ module mô tả dài như tờ rơi, mục "Bảo mật"
  đọc như brochure — không cho thấy việc cần làm.
- Danh sách (PR/PO mẫu): input/select lọc trần không icon, tiêu đề bảng
  `bg-muted/50` chữ thường, dòng bảng py-2 chật, không có thanh view
  (List/Board) hay tiêu đề trang thống nhất.
- Không có tìm kiếm toàn cục; bộ chọn khách sạn chiếm 3 phần tử
  (label + select + nút) trong header; không có nút đăng xuất trong
  header khu khách sạn (chỉ có ở màn tài khoản chưa kích hoạt + trang
  chọn khách sạn).
- Trang tổng quan hard-code chuỗi tiếng Việt trong file (vi phạm AGENTS.md
  quy tắc 11 — chuỗi phải nằm trong `src/i18n/vi.ts`).

## Quyết định

1. **Vỏ app mới (giai đoạn 1):** sidebar trái + topbar + vùng nội dung.
   Sidebar rộng 264px, thu gọn được còn 68px chỉ icon (mặc định MỞ trên
   desktop, nút thu gọn ở cuối sidebar, nhớ lựa chọn bằng localStorage;
   xem Q118). Mobile (<1024px): sidebar ẩn, mở bằng nút hamburger ở
   topbar dưới dạng drawer phủ. Màn hiện trường `/m/*` GIỮ NGUYÊN
   MobileNav của chúng (không phá); `/admin/*` giữ layout riêng của nó
   trong giai đoạn 1 (xem Q122).
2. **Sidebar là `<header>`** (chứa logo + điều hướng chính): vừa đúng
   ngữ nghĩa landmark, vừa giữ test smoke T-047 S2 xanh (test này yêu
   cầu `header` chứa ≥ 8 link, trong đó có link Nhận hàng và link về
   trang tổng quan).
3. **Tokens (giữ nền shadcn oklch, chỉ thêm màu nhấn):**
   `--brand: #7B68EE` (tím ClickUp) + `--brand-foreground: #ffffff`
   (dark: `#8B7CFF`); `--sidebar-primary` đổi sang brand; nút hành động
   chính GIỮ màu gần đen `#171717` (theo ClickUp: CTA tô đen, tím chỉ
   làm màu nhấn cho nav active, tab view active, link, focus). Viền giữ
   bone `#E8E8E8` (đã có sẵn `oklch(0.922 0 0)`). Xem Q119.
4. **Font giữ nguyên** stack Arial/system (`--font-geist-sans: Arial...`
   trong `:root`; Geist được import ở root layout nhưng đã bị override
   thành Arial). Không thêm webfont: app chạy offline-first (PWA), font
   ngoài sẽ hỏng khi mất mạng và thêm dependency không cần thiết.
5. **Điều hướng là 1 nguồn sự thật duy nhất** (`src/components/shell/nav-items.ts`):
   nhóm Tổng quan / Nghiệp vụ (Thu mua, Nhận hàng, Kho, Tài chính) /
   Buồng phòng & Lễ tân (Lễ tân, Số liệu PMS ngày, Buồng phòng) /
   Báo cáo & Cảnh báo (Báo cáo, Cảnh báo) / Hệ thống (Danh mục, Quản trị).
   Mỗi mục ghi đúng tập mã quyền như 11 component `*Link` cũ (đã xóa);
   mục nào người dùng không có quyền nào trong tập thì ẩn — kiểm bằng
   `useCan`/`usePermissions`, KHÔNG kiểm tên vai trò (AGENTS.md quy tắc 10).
   Tập quyền từng mục (chép 1-1 từ component cũ, đã đối chiếu file):
   - Tổng quan: không cần quyền (mọi người có khách sạn đều vào được).
   - Thu mua: pr.create / pr.approve / po.create / po.view /
     service.contract.manage / service.accept.
   - Nhận hàng: receiving.view / supplier_return.post.
   - Kho: requisition.create / requisition.approve / requisition.issue /
     requisition.receive / transfer.send / transfer.receive /
     purpose_issue.post / purpose_issue.reverse / waste.propose /
     waste.approve / waste.approve.large / stock.view_qty /
     stock.view_value.
   - Tài chính: invoice.manage / invoice.approve / ap.view /
     payment.request / payment.approve / payment.mark_paid /
     advance.settle.
   - Lễ tân: minibar.request_check / minibar.charge.confirm /
     minibar.waive.request / minibar.waive.approve.
   - Số liệu PMS ngày: pms.input.
   - Buồng phòng: minibar.check / minibar.refill /
     minibar.price.manage / minibar.reconcile / report.view.rpt_minibar.
   - Báo cáo: bất kỳ report.view.rpt_* nào (10 mã).
   - Cảnh báo: bất kỳ alert.receive.* nào.
   - Danh mục: item.view / item.manage / warehouse.manage / room.manage /
     supplier.view / price.view.
   - Quản trị: admin.roles.manage / admin.users.manage.
6. **Topbar:** nút hamburger (chỉ mobile) + ô tìm kiếm nhảy nhanh tới
   chức năng + bộ chọn khách sạn gọn (select tự nộp khi đổi) + menu
   người dùng (avatar + Đăng xuất — dùng server action `signOut` sẵn
   có; không hiện email vì layout khu khách sạn không có email mà không
   gọi thêm `getUser()` một lần nữa — xem Q123).
   Tìm kiếm là index tĩnh client (28 đích: 12 mục nav + 16 trang tạo
   mới hay dùng), khớp không dấu/không phân biệt hoa thường, Enter vào đích
   đầu tiên — KHÔNG có backend tìm kiếm nên không giả vờ tìm dữ liệu
   nghiệp vụ (xem Q121).
7. **Pattern dùng chung:**
   - `PageHeader`: tiêu đề + mô tả + nút hành động bên phải + slot
     tab view / bộ lọc bên dưới. Áp dụng cho Tổng quan + danh sách PR/PO.
   - `DocStatusBadge` restyle tại chỗ: chữ hoa 11px semibold tracking
     rộng, giữ nguyên ánh xạ màu theo docs/06-UI-UX.md §1 (nháp xám, chờ
     duyệt vàng, đã duyệt xanh dương, đã ghi sổ xanh lá, từ chối/đảo/hủy
     đỏ) + icon kèm theo (không dùng màu làm tín hiệu duy nhất).
   - `DataTable` restyle tại chỗ: tiêu đề cột viết hoa 11px xám, dòng
     cao 48px (py-3), viền hairline, hover nền nhạt. Không đổi API props.
   - Nội dung rộng tối đa 1440px (cũ 1280px) — danh sách là mặt làm việc
     chính, cần chỗ thở; form vẫn tự giới hạn bề rộng bên trong.
8. **Giai đoạn 1 CHỈ restyle mẫu:** Tổng quan + danh sách PR/PO
   (màn dùng nhiều nhất). Các màn còn lại chạy dưới vỏ mới (kế thừa
   sidebar/topbar) nhưng CHƯA restyle chi tiết — danh sách ở báo cáo
   giai đoạn 1. Board view CHƯA làm ở giai đoạn 1: chỉ List (xem Q120).
9. **Không đổi logic nghiệp vụ, không đổi quyền, không migration, không
   thêm dependency.** Icon lucide, không emoji (icon emoji ở Tổng quan
   đổi sang lucide trong ô màu kiểu ClickUp). Chuỗi mới vào `vi.ts`
   mục `shell` + bổ sung mục `property` cho các chuỗi Tổng quan đang
   hard-code.

## Hệ quả

- 11 component `*Link` trong `src/components/common/` bị xóa (chỉ dùng
  ở layout khu khách sạn cũ); logic quyền của chúng chuyển vào
  `nav-items.ts` — rủi ro ghi sai tập quyền được giảm bằng đối chiếu
  1-1 ở mục 5 + smoke test S2/S3 chạy bằng owner (thấy đủ mục).
  Kiểm tay bằng tài khoản ít quyền (vd hk_attendant, receiver) là việc
  của Manual AC giai đoạn 1.
- Test smoke T-047 phải giữ xanh: S1 (h1 tên khách sạn, chữ "Đang hoạt
  động", "Mã khách sạn:", FIFO/bình quân), S2 (header ≥ 8 link, có link
  Nhận hàng + link tổng quan), S3 (12 khu trả 200 + `<main>` + h1/h2).
- `--primary` KHÔNG đổi nên nút chính toàn app vẫn đen; tím chỉ xuất
  hiện ở nav active, tab view active, link hover, focus — nếu Duy muốn
  nút chính tím thì đổi 1 token ở giai đoạn 2 (xem Q119).
- `pnpm-lock.yaml` có sẵn 2 khối `lockfileVersion` (từ trước, không phải
  do task này) — giữ nguyên.
