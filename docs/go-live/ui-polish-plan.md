# Kế hoạch đợt redesign ClickUp (UI polish) — CHỈ KẾ HOẠCH, KHÔNG CODE

> **Trạng thái:** Kế hoạch chuẩn bị. Chưa làm — đợt này làm **sau khi xong
> hết chức năng, trước go-live** (chỉ thị Duy 10/11 07:34).
> Mẫu tham chiếu Duy chốt 10/11 10:13: app ClickUp 3.0.
> Nguồn: `docs/decisions/ADR-006-ui-clickup.md`,
> `docs/decisions/ADR-008-ui-polish-2.md`, `docs/06-UI-UX.md`,
> `docs/OPEN-QUESTIONS.md` (Q118–Q139), báo cáo audit §1/§3.

## 0. Mẫu ClickUp đã chốt (ngôn ngữ thiết kế)

- **Bố cục 3 vùng:** sidebar trái (logo + Home/Inbox + Spaces với ô chữ
  cái màu + Dashboards/Docs + avatar cuối) + thanh view phía trên nội
  dung (List/Board/Calendar + Search + Customize) + vùng nội dung trắng.
- **Danh sách kiểu List:** nhóm theo trạng thái, tiêu đề nhóm là nhãn màu
  đặc; cột tiêu đề viết hoa nhỏ, chữ xám; mỗi dòng ~48px: ô vuông màu,
  tên, avatar người phụ trách, pill trạng thái (nền nhạt + chữ đậm màu),
  cờ ưu tiên (Urgent đỏ, High vàng, Low xám).
- **Pill trạng thái:** bo tròn hoàn toàn (9999px), chữ ngắn, màu là tín
  hiệu chính — luôn kèm chữ, không chỉ dùng màu.
- **Màu:** nền trắng, chữ gần đen (#202020), chữ phụ xám (#646464 /
  #838383), viền nhạt (#E8E8E8), tím nhấn **#7B68EE**, xanh dương #0091FF
  cho link, **nút hành động chính tô đen đặc #171717**.
- **Chữ:** 14px thân bài, tiêu đề đậm sát nhau, khoảng trắng vừa phải,
  không gradient trang trí. Icon `lucide-react`, không emoji.
- **Chuỗi tiếng Việt** nằm trong `src/i18n/vi.ts` (AGENTS.md quy tắc 11);
  kiểm quyền bằng `useCan`, không kiểm tên vai trò.

## 1. UI-1 + UI-2 đã làm gì (không làm lại)

| Giai đoạn | Nội dung | Commit |
|---|---|---|
| UI-1 (ADR-006) | Vỏ app: sidebar trái 264px, thu gọn còn 68px chỉ icon (mặc định MỞ trên desktop, nhớ lựa chọn bằng localStorage; mobile <1024px sidebar ẩn, mở bằng hamburger dạng drawer); topbar + jump search; tokens màu/chữ; `PageHeader` / `DocStatusBadge` / `DataTable` / jump search; restyle mẫu Tổng quan + danh sách PR/PO | cdea736 |
| UI-2 (ADR-008) | `PageHeader` cho mọi màn desktop khu khách sạn (tiêu đề giữ nguyên từng chữ — test S3 kiểm đúng chuỗi); **34 bảng đọc restyle tại chỗ theo đúng class của `DataTable`** (thead `bg-muted/40`, đầu cột viết hoa 11px semibold, dòng `py-3` cao 48px, khung `rounded-lg border bg-card`, bỏ `shadow-sm`/`rounded-xl`); Board view cho PR/PO — chỉ đọc, nhóm trang hiện tại (`ViewToggle` + `BoardView` mới trong `src/components/shell/`); jump search mở rộng | (xem ADR-008) |

**Đã kiểm chứng ngày 10/11 (đợt verify-prep):**

- `src/app` có **103 file `page.tsx`**.
- `PageHeader` được dùng trong **32 file** (các màn còn lại là màn chi
  tiết/form dùng `PageHeader` qua component con, hoặc màn chưa chuyển —
  xem §2 bước 1).
- Component `DataTable` chỉ được dùng trong `src/app/dev/components/page.tsx`
  (trang demo dev) — **đúng thiết kế** theo ADR-008 quyết định 2: các
  danh sách kho/tài chính/trả hàng/kiểm kê dùng server-component + phân
  trang bằng link URL, KHÔNG chuyển sang `DataTable` client (đổi cơ chế
  phân trang là vượt phạm vi "visual/layout only"). Đợt polish **không**
  được "sửa" điểm này thành chuyển sang `DataTable`.

## 2. Còn lệch gì — thứ tự làm

### Bước 1 — Rà soát từng màn (audit pass, làm đầu tiên)

Đối chiếu 103 trang trong `src/app/(app)/[property]/` (10 khu: alerts,
finance, frontdesk, housekeeping, inventory, master, procurement,
receiving, reports, restaurant) + trang chọn khách sạn + màn admin với
bảng kiểm sau, ghi kết quả vào 1 file theo dõi (không sửa code trong bước
này):

| Hạng mục kiểm tra | Chuẩn ClickUp |
|---|---|
| Tiêu đề trang | `PageHeader` (tiêu đề + mô tả + nút hành động); 1 `h1` duy nhất; không còn `text-xl`/`text-2xl` rời rạc |
| Bảng đọc | thead `bg-muted/40`, đầu cột viết hoa 11px semibold, dòng 48px `py-3`, khung `rounded-lg border bg-card` |
| Trạng thái | `DocStatusBadge` / pill bo tròn 9999px, nền nhạt + chữ đậm màu, luôn kèm chữ |
| Search + filter | Thanh tìm kiếm + bộ lọc trên cùng mỗi danh sách (không còn input/select lọc trần không icon) |
| Sub-nav mỗi khu | 1 kiểu thống nhất (hiện mỗi khu một kiểu: pill đen / pill tím / pill trắng) |
| Nút hành động chính | Tô đen đặc #171717; nút phụ outline; tím #7B68EE chỉ làm màu nhấn |
| Chuỗi hiển thị | Nằm trong `src/i18n/vi.ts`, không hard-code trong component |
| Icon | `lucide-react`, không emoji |

### Bước 2 — Restyle các màn sinh sau UI-2 (ưu tiên cao)

Các màn do wave completion-2 xây (sau UI-2) chưa qua chuẩn UI-2 — restyle
theo tokens, không rebuild logic:

- Màn khóa ngày (C1), màn duyệt ảnh (C2), màn xuất tài chính (C4),
  màn org/property (C5), màn housekeeping/minibar bổ sung (C7),
  màn báo cáo/matview (C10).
- PO PDF (C3): đầu phiếu dùng tên pháp nhân + logo/màu chuẩn khi in.

### Bước 3 — Search + filter trên cùng cho các danh sách còn thiếu

Danh sách nào còn input/select lọc trần không icon (kiểm kê ADR-006:
PR/PO mẫu trước UI-1) thì bổ sung thanh search + filter thống nhất theo
mẫu ClickUp. Không đổi cơ chế lọc/phân trang (giữ link URL).

### Bước 4 — Board view cho các module khác (nếu Duy chốt)

Board hiện chỉ có cho PR/PO (Q120: LÀM, chỉ đọc, nhóm trang hiện tại).
Nếu Duy muốn Board cho nhận hàng / kho / tài chính thì làm cùng pattern
(`ViewToggle` + `BoardView`, chỉ đọc, ghi rõ chỉ nhóm trang hiện tại).
Không làm Board ghi (kéo-thả đổi trạng thái) trong đợt này — đó là tính
năng, không phải polish.

### Bước 5 — Admin layout + user menu (Q122, Q123)

- Q122: admin hiện giữ layout riêng — chốt có đưa admin vào vỏ ClickUp
  không, hay giữ riêng.
- Q123: user menu hiện không có email — bổ sung hiển thị email/tên người
  dùng vào menu.
- Q118: sidebar thu gọn nhớ lựa chọn bằng localStorage — kiểm tra đã
  hoạt động đúng chưa.

### Bước 6 — Smoke + Duy duyệt

- Chạy lại Playwright smoke S1–S3/R1–R5 (T-047) — **phải xanh** sau mọi
  thay đổi (ADR-006/008 đều ràng buộc).
- Duy xem thử trên laptop + điện thoại, chốt từng khu trước khi go-live.

## 3. Cái gì KHÔNG đụng (ranh giới cứng)

| Không đụng | Lý do |
|---|---|
| Màn mobile `/m/*` (nhận hàng, kiểm kê, xe đẩy, minibar) | ADR-006: màn hiện trường GIỮ NGUYÊN; wave mobile đang sở hữu |
| Logic nghiệp vụ, RPC, quyền, SoD | Polish là visual/layout only |
| Cơ chế phân trang server-component (link URL) | ADR-008 quyết định 2 — không chuyển sang `DataTable` client |
| Bảng trong form nhập liệu (giữ `py-2` gọn) | ADR-008 quyết định 3 / Q137 — dòng 48px làm form dài gấp rưỡi mà không thêm giá trị đọc |
| Code của wave mobile + completion-2 đang chạy | Chỉ restyle SAU KHI các wave đó merge xong; không sửa trên nhánh của họ |
| Test S1–S3/R1–R5 (chuỗi tiêu đề kiểm đúng từng chữ) | Đổi tiêu đề là vỡ test — giữ nguyên từng chữ khi chuyển sang `PageHeader` |
| Màu/token đã chốt (#7B68EE, #171717) | Không tự chế palette mới |

## 4. Câu hỏi mở về UI (Duy chốt cùng đợt C1–C10)

- Q118 — sidebar thu gọn nhớ lựa chọn (đã làm ở UI-1, cần kiểm chứng).
- Q120 — Board PR/PO: **ĐÃ LÀM** (ADR-008).
- Q122 — admin có vào vỏ ClickUp không?
- Q123 — user menu hiển thị email?
- Q133–Q139 — (xem `docs/OPEN-QUESTIONS.md` — các câu hỏi UI còn lại,
  gồm Q137 form `py-2` đã chốt giữ nguyên).
