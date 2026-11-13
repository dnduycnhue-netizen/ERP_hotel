# Checklist go-live ERP_hotel — 1 bảng duy nhất

> **Trạng thái:** cập nhật 13/11/2026 (đọc lại số liệu production lúc cập nhật); bản trước 12/11/2026 (tối) bởi Claude Code, thay bản 10/11. Mọi dòng
> "đã kiểm chứng" nghĩa là đã đọc lại từ production (project ERP_hotel
> `ufxcjfntesafmqzsjsyr`) hoặc chạy thật trong phiên này; mục nào chưa kiểm chứng
> được ghi rõ **chưa kiểm chứng**. Không bịa trạng thái.
> Chủ sở hữu: **Duy** = chỉ Duy làm/quyết được; **Claude** = Claude Code; **Muse** = agent UI.

## Tóm tắt một dòng

**CHẾ ĐỘ DEMO (Duy chốt 13/11/2026: hệ thống đang xây dựng, chưa cần dữ liệu thật).** Production chạy với dữ liệu **GIẢ LẬP**
để thao tác thử: 30 phòng + 3 loại phòng + 2 xe đẩy + bếp/nhà hàng (Q261), 16 nhà cung cấp (Q256), 82 công thức và 668 vật tư từ file Excel
mẫu, giá minibar hiện hành (từ 11/11), 7 vai trò gọn đã gán cho tài khoản UAT (Q260). **Chưa phải vận hành thật**: các cổng dưới đây
(tài khoản nhân viên thật, tồn đầu kỳ thật, tên pháp nhân, tắt tài khoản test, kiểm tay điện thoại) **vẫn chặn go-live thật**. Tồn kho demo = 0:
tạo tồn bằng 1 chu trình mua → nhận hàng qua giao diện (mua hàng bằng tài khoản `uat.purchaser`, duyệt bằng `uat.gm`, nhận bằng `uat.receiver`).
Số liệu bên dưới là bản đọc trước khi tạo dữ liệu demo phòng.

Mã nguồn và cơ sở dữ liệu **sẵn sàng cho UAT** (test có kiểm soát) và đã deploy production (13/11).
**CHƯA đủ điều kiện vận hành thật** — số liệu production đọc lại 13/11 (chiều): **0 phòng, 0 loại phòng**, **17 nhà cung cấp (16 là GIẢ LẬP, Q256)**,
**7 dòng giá minibar hết hạn**, **23 tài khoản đang hoạt động, toàn bộ là test/UAT/quản trị** (mật khẩu yếu), 0 tài khoản nhân viên thật,
tồn đầu kỳ chưa kiểm đếm (tồn = 0), tên pháp nhân vẫn là tên mẫu. Đã xong thêm 13/11: module bật/tắt theo khách sạn (Q254), 7 vai trò gọn + gán cho tài khoản UAT (Q257/Q260), công tắc tự duyệt (Q258), duyệt PO 2 bậc. Cron 0 lỗi/7 ngày. Xem **Cổng go-live** ở mục G.

## A. Cổng kỹ thuật

| # | Cổng | Trạng thái | Chủ | Ghi chú |
|---|---|---|---|---|
| A1 | pgTAP | **XANH: 53/54 suite, 2.210/2.220 ca** (12/11) | Claude | Còn lại `bootstrap_initial_org_test` chỉ đạt trên DB trống (cần staging/Docker). Chạy lại: `python3 scripts/pgtap-rehearse.py` (docs/11-TESTING.md §12) |
| A2 | Lint + typecheck + Vitest | **XANH 13/11**: eslint sạch, `tsc` sạch, 20 file / 160 test | Claude | ESLint có thêm luật chặn chuỗi tiếng Việt hard-code (Q243) |
| A3 | `database.types.ts` | **XONG, cập nhật 13/11** sau migration 565000–567000: sinh lại từ ERP_hotel (~9.500 dòng; bản cũ 2.554 dòng, dừng ở T-012) | Claude | Checklist cũ ghi "chỉ Duy làm được" — sai, CLI đã link |
| A4 | Playwright tầng ghi | **Chưa chạy** | Duy | Chỉ chạy được trên máy Duy. `.env.local` đã sửa về ERP_hotel (12/11); còn thiếu `SUPABASE_SECRET_KEY` (dán từ Dashboard → API Keys → Secret) |
| A5 | Kiểm tay trên điện thoại thật (Q110, 7 mục) | **Chưa kiểm chứng (0/7)** | Duy | Đếm mù end-to-end, đối chiếu Excel với `v_count_result`, test offline kiểm kê/nhận hàng |
| A6 | Bản deploy khớp mã nguồn | **XONG 12/11**: production = commit `e1db99b0c` (mục H) | Claude | |

## B. Bảo mật và kiểm soát (mục mới — đã kiểm chứng trên production)

| # | Cổng | Trạng thái |
|---|---|---|
| B1 | RLS | **103/103 bảng** bật RLS; 5 bảng không policy (settings, approval_rules, alert_rules, doc_sequences, item_code_sequences) là thiết kế (chỉ qua RPC) |
| B2 | Hàm `SECURITY DEFINER` | Tất cả có `search_path`; **0 hàm** `anon` gọi được (đã thu hồi 24 hàm, migration 562000) |
| B3 | Audit | Trigger audit phủ mọi bảng nghiệp vụ trừ sổ cái/cache (536000); `pin_hash` không vào log (557000); cờ `rule.*` tắt/bật → alert `RULE_TOGGLED` |
| B4 | SoD | Thêm `SOD_INVOICE_GR` + `SOD_PAYMENT_APPROVER` (563000). `SOD_GRANT` **không áp dụng** (Duy chốt). `SOD_YIELD` chờ P2 |
| B5 | Ràng buộc đã nới (cờ, mặc định BẬT) | R25 (PIN nộp kiểm kê), R18 (PIN nhận hàng), R32 (đóng kỳ) — chưa tắt cờ nào; R26 ngưỡng đếm lại theo nhóm hàng; R30 cho nhập số 0 |
| B6 | **Tài khoản test mật khẩu yếu** | **PHẢI xử lý trước khi dùng thật.** TEST01–05 (mật khẩu yếu, đã thu hẹp về TEST47 ngày 12/11) và 16 tài khoản `uat.<vai trò>@erp.internal` (mật khẩu yếu do Duy đặt, chỉ TEST47, tự hết hạn **26/11/2026**, không có `sys_admin`). Vô hiệu hóa hoặc xóa trước ngày vận hành thật |
| B7 | Tài khoản quản trị | `0001` giữ đủ 17 vai trò toàn chuỗi, chưa đặt PIN; 1 tài khoản owner+sys_admin riêng. Nên tạo tài khoản nhân viên thật theo từng vai trò rồi hạ quyền `0001` (SoD sẽ chặn chính nó ở nhiều chứng từ) |
| B8 | Danh mục dùng chung | Vật tư/NCC dùng chung cấp chuỗi: ai có `item.manage`/`supplier.manage` ở bất kỳ khách sạn nào sửa được danh mục của cả chuỗi (kể cả tài khoản test ở TEST47) |

## C. Dữ liệu và cấu hình (cần Duy cung cấp/chốt)

| # | Cổng | Trạng thái (đọc từ production 12/11) | Chủ |
|---|---|---|---|
| C1 | Tồn đầu kỳ SONHOIAN (Q157) | Đã **dọn dữ liệu test**: 28 bút toán `adjust_count` giá 0 (đợt `CNT-SONHOIAN-2611-0001`) đã đảo bằng bút toán đảo; tồn = 0, giá vốn = 0 (Q244). Chờ **kiểm đếm thật ngày cutover** theo `opening-stock-runbook.md` | Duy + Claude |
| C2 | Phòng | **DEMO 13/11: SONHOIAN có 30 phòng/3 loại (giả lập, Q261)**; TEST47 vẫn 0 phòng trong bảng `rooms`. Ban đầu: **0 phòng** ở cả 2 khách sạn → buồng phòng, minibar chưa dùng được. Cần danh sách phòng + loại phòng | Duy |
| C3 | Nhà cung cấp | **17 NCC, trong đó 16 GIẢ LẬP** (seed Q256, đánh dấu `external_codes.source=synthetic`) — thay bằng NCC thật trước khi vận hành; 0 hợp đồng khung, 2 giá trần. PO không có nguồn giá phải qua duyệt thủ công | Duy |
| C4 | Minibar | 14 dòng giá: 7 dòng lịch sử 2018–2019 (hết hạn, bình thường) **+ 7 dòng giá hiện hành từ 11/11/2026** (giá tham khảo 2018, cần chốt lại khi vận hành thật) | Duy |
| C5 | Công thức món (Q168) | **82 công thức, 427 dòng định lượng đã có**; 0 dòng bán (`dish_sales`). Chưa kiểm chứng 18 dòng "[CẦN XÁC NHẬN]" của bản nháp | Duy |
| C6 | Tên pháp nhân thật (B2 cũ) | **Chưa đổi** — vẫn "Son Hoi An Boutique Hotel & Spa". Đã có màn sửa (migration 535000, Q209) | Duy |
| C7 | Thông báo email/push (Q98/Q99) | **Chưa cấu hình sender** (0 cấu hình, 0 thuê bao push). Duy đã chọn dùng chuông cảnh báo trong app (Q208). Bản tin 8h gửi email cần Resend + VAPID (`notification-sender-setup.md`) | Duy |
| C8 | Tài khoản nhân viên thật | Chưa có (chỉ `0001`, owner riêng, TEST01–05, UAT) | Duy |
| C9 | Cron | 8 job, **0 lỗi trong 7 ngày** | — |

## D. Quyết định nghiệp vụ

| Câu hỏi | Trạng thái |
|---|---|
| Q58 (FIFO + minibar) | Giữ `moving_avg`; **đã kiểm chứng** cả 2 pháp nhân dùng `moving_avg` |
| Q60 (`item.view` cho lễ tân/owner/gm) | **Xong** (migration 420000; đã kiểm chứng trên production) |
| Q73 (timeline duyệt thanh toán), Q81 (ghi chú nghiệm thu) | **Xong** |
| T-022A / Q171 (PO chợ không giá) | **Đã chốt phương án A** (miễn kiểm giá). Còn mở Q172 (dòng giá 0 vào nhận hàng/hóa đơn) và Q173 (bậc duyệt bị tính thấp) — chờ khách |
| Q233 (ngày giao PO) | **Xong** (561000): PO từ PR có `expected_date = order_date`; NULL coi là đến hạn |
| Q71, Q76, Q83, Q101, Q31, Q42, Q80 | Chờ khách |
| Chờ khách, ảnh hưởng vận hành | Q152/Q199 (minibar offline), Q161 (bản tin 8h), Q165 + Q132 (tạo user, độ dài mật khẩu), Q174 (nội dung chuyển khoản) |

## E. Giao diện và hiệu năng

| # | Cổng | Trạng thái |
|---|---|---|
| E1 | Vỏ giao diện ClickUp, 34 bảng (UI-1/UI-2) | Xong |
| E2 | Chuỗi tiếng Việt hard-code | **Xong (Q243)**: chỉ có 50 chuỗi ở 10 file (không phải 222 như ghi nhầm trước đó), đã chuyển vào `vi.ts` + luật ESLint chặn tái phát |
| E3 | Tốc độ tải (Q124–126) | **Đo một phần 13/11:** `/login` TTFB ~0,16–0,17 s (5 lần, qua edge hkg1), `vercel.json` đã đặt `bom1`. **Chưa đo trang sau đăng nhập** (cần phiên đăng nhập thật; đo trên máy Duy bằng DevTools → Network) |
| E4 | Đợt UI polish theo `ui-polish-plan.md` | Chưa làm (không chặn go-live) |

## F. Các wave

Mobile UI, Completion-2, Verify-prep: **đã merge vào `main`** (bản deploy ngày 12/11 chứa chúng).

## F2. Đã làm thêm 13/11 (đã áp production + deploy)

| Mã | Việc | Trạng thái |
|---|---|---|
| Q249 | Màn `/admin/health` (sức khỏe hệ thống), quyền `admin.health.view` (migration 565000) | Xong, chưa kiểm tay giao diện |
| Q173 | Tổng ước tính cho PO chợ, bậc duyệt theo số lớn hơn (566000) | Xong |
| Q152/Q199 | Hàng đợi offline cho kiểm minibar | Xong code, **chưa kiểm tay trên điện thoại** |
| Q34 | Nạp file POS của ca + `count_open` shift_key cần file POS (567000), màn `/inventory/pos-import` | Xong, **định dạng CSV là giả định** (file mẫu giả lập), cần file POS thật |
| Q161, Q165 | Chốt giữ tính live; xác nhận đã sửa | Xong |
| Q172 | Giá 0 của PO chợ: nhập giá lúc đối chiếu hóa đơn | **Chưa code** — cần kế toán duyệt cách điều chỉnh giá vốn |
| Staging | Project Supabase riêng | **Chưa tạo** (chờ Duy đồng ý chi phí) |

## G. Thứ tự làm từ bây giờ

**Cổng go-live (tất cả phải đạt trước khi vận hành thật):**
- [ ] C2 có phòng thật; C3 có nhà cung cấp/giá thật; C4 giá minibar hiện hành
- [ ] C8 có tài khoản nhân viên thật (mật khẩu mạnh, PIN)
- [ ] C1 kiểm đếm tồn đầu kỳ thật + khóa kỳ
- [ ] B6 tắt/xóa 21 tài khoản test/UAT, hạ quyền `0001` (B7)
- [ ] A5 kiểm tay trên điện thoại (7 mục)
- [ ] Cập nhật tên pháp nhân thật (C6)


1. ~~Deploy bản mới nhất~~ **xong** → UAT bằng tài khoản `uat.*` ở TEST47. *(Duy)*
2. Duy kiểm tay A5 (điện thoại thật) + chạy A4 (Playwright) sau khi dán `SUPABASE_SECRET_KEY`. *(Duy)*
3. Cung cấp dữ liệu thật C2–C6, C8. *(Duy)*
4. Kiểm đếm cutover (C1) theo runbook → khóa kỳ → import công thức/dữ liệu còn thiếu. *(Duy + Claude)*
5. **Tắt/xóa tài khoản test và UAT (B6)**, hạ quyền `0001` (B7). *(Duy + Claude)*
6. Cấu hình sender nếu muốn bản tin email (C7); đo tốc độ (E3). *(Duy + Claude)*
7. Tạo project staging để chạy `bootstrap_initial_org_test` và thử migration an toàn hơn. *(Duy)*
8. Vận hành thật.

## H. Ghi chú deploy

Việc deploy đi qua Vercel CLI (không có tích hợp git tự động), project `erp_hotel`,
địa chỉ production `https://erphotel.vercel.app`. Trước ngày 12/11 21:xx bản đang chạy là
commit `ec4c7be` (sửa Q235), trước toàn bộ thay đổi code của Q241–Q246.

**Trạng thái 12/11 tối: ĐÃ deploy** bản `main` commit `e1db99b0c` lên production
(`erphotel-7e8a3q31w-dnduys-projects.vercel.app`, Ready, gắn `erphotel.vercel.app`), theo lệnh của Duy.
Đã push `main` lên GitHub (`ec4c7be7e..53213cb3b`, 23 commit) theo lệnh Duy; bản deploy `e1db99b0c` cũ hơn đầu `main` đúng các commit chỉ sửa tài liệu.

Kiểm tra sau deploy (smoke): `/login` trả 200; đăng nhập `uat.gm@erp.internal` thấy đúng 1 khách sạn
(TEST47); `uat.storekeeper` gọi `receiving_list_tasks` trên TEST47 được, trên SONHOIAN bị `ERR_FORBIDDEN`;
`anon` gọi RPC bị 401.

**13/11 (Q249–Q250):** đã áp migration 565000 (màn `/admin/health`) và 566000 (tổng ước tính PO chợ) lên production, deploy lại `main` (merge `4efa1e6c3`), `/login` 200. Q152 minibar offline đã code, chưa kiểm tay trên điện thoại. Q172 chưa code (chờ phương án điều chỉnh giá vốn).

**13/11 (Q251):** đã áp migration 567000 (nạp file POS, `count_open` shift_key cần file POS) lên production và deploy lại. Định dạng CSV là GIẢ ĐỊNH — cần file POS thật để chỉnh.
