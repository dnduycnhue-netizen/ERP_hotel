# Giao việc cho Muse — kiểm chứng Trung tâm hướng dẫn (14/11/2026)

> Người giao: Claude Code (theo yêu cầu Duy). Làm **tuần tự, một mình**. Xong báo lại.
> Đọc trước: `AGENTS.md`, `docs/go-live/muse-handoff-cycle.md` (luật vẫn áp dụng), `CHANGELOG.md` Q279–Q280, `src/i18n/help/*.ts` (nội dung 45 bài).
> Mật khẩu chung và PIN **Duy dán riêng**. Không ghi PIN/mật khẩu vào file/commit/log/ảnh chụp.

## Mục tiêu

Trung tâm hướng dẫn trong app vừa ra mắt (Q279) kèm nút "?" theo màn hình và bản mobile (Q280). Việc của bạn: **đối chiếu hướng dẫn với giao diện và hành vi thật**, tìm chỗ **hướng dẫn sai/thiếu/gây hiểu lầm** và lỗi hiển thị. Hướng dẫn mô tả hệ thống "đang chạy" — nếu bài nói A mà app làm B, đó là lỗi cần báo (hoặc sửa bài).

## Luật

1. Chỉ giao diện web, tài khoản `uat.*`/TEST, khách sạn TEST47 (`b0000000-0000-4000-8000-000000000002`); không supabase/migration/vercel/RPC/SQL trực tiếp; không đổi cấu hình/tài khoản/PIN/khóa kỳ. Không làm thao tác ghi dữ liệu thật **chỉ để thử hướng dẫn** nếu thao tác không cần thiết — ưu tiên đọc/mở màn hình; khi cần chạy một bước SOP để xác minh, làm trên dữ liệu thử có sẵn và ghi lại.
2. **Được sửa nội dung bài** ở `src/i18n/help/*.ts` và code giao diện trang hướng dẫn khi lỗi rõ ràng (nhánh `feat/muse-help` từ `main` mới nhất có commit Q280; mỗi task một commit `T-Hxx:`; `pnpm lint && pnpm typecheck && pnpm test` xanh — test `help-content` phải xanh; chuỗi giao diện vào `src/i18n/vi.ts`, nội dung bài ở `src/i18n/help/`). Không thêm thư viện. Lỗi DB/RPC/quyền → ghi vào "Chuyển Claude Code", không tự sửa.
3. Không merge/push `main`; được push nhánh `feat/muse-help`. Không bịa kết quả.
4. Báo cáo: `docs/go-live/help-verify/Hxx-*.md` + tổng `docs/go-live/muse-report-help.md`.

## Thứ tự

### H1. Giao diện trang Hướng dẫn (desktop)
- Mở `/<P>/help` bằng 3 tài khoản khác vai trò (ví dụ `uat.owner`, `uat.purchaser`, `uat.hk_attendant`): trang tải được; ô tìm kiếm hoạt động **không dấu, nhiều từ** ("nhan hang mu", "kiem ke", "hoa don"); 5 tab loại; bài **"Dành cho bạn"** xuất hiện và đứng đầu đúng theo vai trò (purchaser thấy bài Thu mua/mua hàng; hk_attendant thấy Buồng phòng/minibar; owner thấy Chủ đầu tư/duyệt…). Ghi bài nào "Dành cho bạn" sai/thiếu so với công việc thật của vai trò.
- Bài viết: mở **ít nhất 12 bài** (mỗi loại ≥ 2). Kiểm: tiêu đề, bảng, bước đánh số, ô ghi chú, nút "Mở màn hình" mở **đúng trang** (không 404, đúng khách sạn), liên kết "Bài liên quan" hoạt động, nút quay lại.
- Khung 1280 px và 390 px (không tràn ngang, bảng cuộn được, nút ≥ 44 px trên mobile).
- Module tắt: **không bật/tắt module**; chỉ đọc code (`visibleArticles`) và xác nhận bài `restaurant`/`hk_frontdesk` ẩn khi module tắt (có test).

### H2. Nút "?" theo màn hình (Q280)
- Trên desktop, nút "?" ở thanh trên cùng (cạnh chuông). Mở từ các màn: `/procurement/po`, `/procurement/approvals`, `/inventory/waste`, `/inventory/counts`, `/inventory/locks`, `/inventory/stock`, `/finance/invoices`, `/restaurant/dishes`, `/frontdesk/minibar`, `/housekeeping/trolleys`, `/reports`, `/master/items`. Mỗi lần: bấm "?" → trang Hướng dẫn có khối **"Gợi ý cho màn hình bạn vừa xem"** với 2–5 bài **đúng chủ đề màn hình**. Ghi màn nào gợi ý lệch chủ đề hoặc không có gợi ý.
- Trên mobile (`/m/<P>/receive`, `/count`, `/minibar`, `/trolley`, `/restaurant`): nút "?" ở góc phải header; mở ra bản mobile `/m/<P>/help?ctx=...` với gợi ý đúng.

### H3. Bản mobile
`/m/<P>/help` và một bài: header đúng tiêu đề, nút back về danh sách, nội dung đọc được ở 390 px, **không có nút "Mở màn hình"** (cố ý), chạm được. Tài khoản `uat.receiver` và `uat.hk_attendant` (người dùng mobile chính) mở được không; menu đáy hiển thị bình thường.

### H4. Đối chiếu nội dung với hệ thống thật (quan trọng nhất)
Với mỗi bài sau, đi qua từng bước trên giao diện (đọc/mở màn hình; chạy thật bước nào cần thiết trên dữ liệu thử có sẵn) và ghi **bước nào sai tên nút/sai thứ tự/sai ai làm/sai điều kiện/thiếu bước**:
1. **SOP-01 Nhận hàng mù** + bài vai trò "Người nhận hàng" (màn nhận hàng mobile: tên nút, ô tích không camera ở từng dòng và ở nút Ghi sổ, ô "Số lượng hỏng", cân lại lần 2, PIN).
2. **SOP-02 Kiểm kê cuối tháng** (mở đợt, nhãn "Người đếm độc lập", đóng băng, nộp bằng PIN, duyệt điều chỉnh, khóa).
3. **SOP-03 Hủy hàng** và **luồng lĩnh kho/điều chuyển/xuất mục đích/hủy** (tên nút, cost center + khoản mục bắt buộc ở xuất mục đích, ảnh bắt buộc ở hủy hàng).
4. **SOP-04 Thanh toán NCC** (tên nút "Nhập hóa đơn mới", "Khớp 3 chiều", "Tạo đề nghị mới", "Đã thanh toán"; ai duyệt từng bước **trên thực tế** — ghi chính xác vì bài viết chung chung về bước duyệt thanh toán).
5. **SOP-05 Kiểm minibar** và **luồng minibar** (Yêu cầu kiểm, tick "Phòng không dùng món nào", cảnh báo > 20, Đã thu + folio).
6. **Luồng mua hàng → thanh toán** (bảng 13 bước: đúng màn/ai/trạng thái?).
7. **Quy tắc**: dung sai & cân lại, giá trần/giá tay, đối chiếu 3 bên (dung sai 1%?), duyệt nhiều bước (đơn mua từ 100 triệu cần Chủ đầu tư?), ảnh & ngoại lệ không camera, bật/tắt module.
8. **Bài vai trò** Quản lý, Kế toán, Thu mua & Thủ kho, Lễ tân, Buồng phòng, Bếp: "bạn thấy/không thấy gì", menu, việc hằng ngày có đúng với tài khoản thật.
Đối với mỗi lỗi nội dung: **sửa bài** (commit riêng, nhỏ) nếu bạn chắc; nếu không chắc nguồn sự thật (quy tắc/ngưỡng) thì ghi vào "Cần Duy/Claude xác nhận", đừng đoán.

### H5. Tìm thiếu
Liệt kê **chủ đề người dùng cần mà chưa có bài** (ví dụ: nhập danh mục, kiểm kê theo ca, ca xe đẩy chi tiết, hợp đồng dịch vụ, tạm ứng, cảnh báo, đổi PIN/mật khẩu, xử lý khi mất mạng). Đề xuất tối đa 10 bài, mỗi bài một dòng + lý do. Không tự viết bài mới trừ khi được yêu cầu.

## Báo cáo cuối

Bảng H1–H5 Đạt/Không đạt/Không kiểm được + lý do + commit; **danh sách lỗi nội dung** (bài, bước, sai gì, đúng là gì, đã sửa chưa); lỗi giao diện (UI/quyền/dữ liệu); đề xuất bài thiếu; **Cần xác nhận**; lệnh đã chạy + kết quả thật; việc bỏ dở và vì sao.
