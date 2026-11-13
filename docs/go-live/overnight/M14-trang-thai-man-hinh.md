# M14 — 4 trạng thái mỗi màn hình

- Trạng thái: **Đạt (phần sửa được); còn danh sách rà soát để Claude Code xem tiếp**
- Thời gian: 13/11/2026 ~22:55–23:05
- Phạm vi: 122 file `page.tsx` dưới `src/app/(app)/[property]/**` (87), `src/app/m/**` (20), `src/app/admin/**` (15)
- Lệnh đã chạy: `pnpm lint`, `pnpm typecheck`, `pnpm test` — đều xanh (285/285)

## Kết luận rà soát

1. **Trạng thái đang tải / lỗi được xử lý ở cấp segment (theo mẫu Next.js), không phải ở từng page.** `src/app/(app)/loading.tsx` (hiện "Đang tải dữ liệu…", `aria-busy` + `aria-live`) và `src/app/(app)/error.tsx` (tiêu đề + mô tả + nút "Thử lại") bao phủ toàn bộ 87 trang desktop. Các page server chỉ `await` query rồi render — lỗi render rơi vào boundary của segment. Đây là thiết kế có chủ ý, không phải thiếu sót.
2. **Trạng thái rỗng được xử lý qua component dùng chung.** `src/components/common/data-table.tsx` tự render `EmptyState` khi hết dòng (và 3 dòng skeleton khi đang tải); `EmptyState` được dùng ở 47 file. Các trang danh sách (vật tư, PR, PO, hóa đơn…) đều render qua `DataTable` nên có trạng thái rỗng. Bằng chứng live (đợt M9 cùng đêm): kiểm kê "Chưa có đợt kiểm kê nào.", tồn kho "Không có mặt hàng nào tồn kho theo bộ lọc hiện tại.", hóa đơn "Chưa có dòng nào phù hợp với bộ lọc hiện tại.", xe đẩy "Chưa có ca xe đẩy nào.".
3. **Trang hub không cần trạng thái rỗng** (chỉ có thẻ liên kết: `/receiving`, `/restaurant`, `/procurement`, `/inventory`, `/finance`, `/master`, `/m/.../restaurant`) và **trang form (new/edit) không cần trạng thái rỗng** — các trang này chiếm phần lớn số trang mà grep thô gắn cờ "thiếu rỗng".

## Lỗi thật tìm thấy và đã sửa

**Thiếu boundary loading/error cho 2 segment `/m` và `/admin`.** Trước M14, chỉ `(app)` và `(auth)` có `loading.tsx`/`error.tsx`; 20 trang mobile và 15 trang admin không có boundary riêng — lỗi render ở các trang này rơi về trang lỗi mặc định của Next.js (không có nút "Thử lại" tiếng Việt, không có tiêu đề theo mẫu), và chuyển trang trong `/m` hoặc `/admin` không hiện trạng thái đang tải.

Đã thêm 4 file, sao đúng mẫu của `(app)` (dùng chuỗi `vi.common.loading`, `vi.errors.pageTitle`, `vi.errors.pageDescription`, `vi.common.tryAgain`, không thêm chuỗi mới):
- `src/app/m/loading.tsx`, `src/app/m/error.tsx`
- `src/app/admin/loading.tsx`, `src/app/admin/error.tsx`

`notFound()` (dùng cho chặn quyền ở các trang hub) không bị ảnh hưởng — nó render `not-found`, không đi qua `error.tsx`.

## Giới hạn của đợt rà này (ghi rõ, không giấu)

- Grep thô trên `page.tsx` cho ra 79 trang "không có nhánh rỗng" và 30 trang "không xử lý lỗi" — **đa số là dương tính giả**: chuỗi rỗng/lỗi nằm trong `vi.ts` hoặc trong component con (`DataTable`, `ItemsList`…), và các trang hub/form/detail không cần nhánh rỗng. Tau đã kiểm chứng bằng cách đọc mẫu (`master/items/page.tsx` ủy quyền rỗng cho `DataTable`; `receiving/page.tsx` là hub 3 thẻ) thay vì sửa bừa 79 trang.
- **Chưa kiểm chứng từng trang một bằng tay trên trình duyệt** — chỉ kiểm chứng mẫu code + bằng chứng live từ đợt M9. Danh sách 122 trang đã phân loại sơ bộ theo loại (hub/list/form/detail) nhưng chưa có bảng từng trang đầy đủ; Claude Code có thể chạy tiếp bằng cách mở từng trang với dữ liệu rỗng.
- Chưa thêm `loading.tsx`/`error.tsx` cho `(auth)` — đã có `error.tsx`, thiếu `loading.tsx`; trang đăng nhập tải nhanh nên mức ưu tiên thấp, ghi lại đây để Claude Code quyết.

## Việc chưa làm

- Không sửa từng trang riêng lẻ (không cần thiết sau khi xác định mẫu segment + DataTable đã bao phủ).
- Không thêm skeleton riêng cho từng trang (mẫu hiện tại chỉ có 1 dòng "Đang tải dữ liệu…" ở cấp segment).
