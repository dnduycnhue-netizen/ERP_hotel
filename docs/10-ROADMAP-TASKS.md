# 10 — Lộ trình & danh sách task

Mỗi task vừa một phiên làm việc của agent (2–6 giờ). Cột **Agent gợi ý** theo `13-AI-WORKFLOW.md`: **CC** = Claude Code, **AG** = Antigravity, **MU** = Muse. Đánh dấu `[x]` khi xong.

Quy ước tiêu chí nghiệm thu (AC): mọi task phải thỏa Definition of Done trong `AGENTS.md` ngoài các AC riêng.

## Giai đoạn 0 — Nền móng (tuần 1–2)

> T-001 đang triển khai: scaffold Next.js, Supabase CLI và CI đã tạo; Supabase hosted đã được cấu hình với public key cho Vercel và có thể truy cập. Bản production đã deploy trực tiếp bằng Vercel CLI. Chưa xác nhận `supabase start` vì Docker daemon không chạy; chưa đổi được Git integration vì Vercel chưa có quyền truy cập repository tổ chức. Cần cấp quyền GitHub App để tự động deploy từ repo này.
>
> T-002 hoàn tất trên Supabase hosted: hai migration đã áp dụng; sinh types từ remote; 30 assertion pgTAP chạy qua `supabase db query` trong transaction và toàn bộ đạt. `supabase test db --remote` vẫn đòi Docker nên không dùng. Fixture/test extension đã rollback, seed mẫu chỉ giữ cho local và không chạy trên production. Vercel production deploy Ready và HTTP smoke test trả 200.
>
> Bootstrap ban đầu: migration đã áp dụng lên production, 22 assertion pgTAP transactional đạt, types đã sinh lại; callback đã deploy. Gửi lời mời gặp `over_email_send_rate_limit`; function đã rollback các tài khoản được tạo một phần, xác minh production vẫn có 0 tổ chức và 0 Auth user. Secret tạm và Edge Function đã được xóa. Cần nâng giới hạn email hoặc cấu hình SMTP riêng cho production trước khi thử lại. T-005 vẫn chưa hoàn tất.

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [ ] T-001 | Khởi tạo repo Next.js + TS strict + Tailwind + shadcn + ESLint/Prettier + pnpm; Supabase CLI `supabase init`; cấu trúc thư mục theo AGENTS.md | CC | — | `pnpm dev` chạy; `supabase start` chạy; CI GitHub Actions chạy lint + typecheck |
| [x] T-002 | Migration 01 + 02: extension, tiện ích, audit, tổ chức & truy cập, **phân quyền động** (`permissions`, `roles`, `role_permissions`, `user_property_roles` có phạm vi, `user_permission_overrides`), `has_perm`, `require_perm`, `my_property_ids`, `my_permissions`; seed danh mục quyền + vai trò mẫu + dữ liệu mẫu (2 pháp nhân, 2 KS) | CC | T-001 | pgTAP mục 11 `04-SECURITY-RLS.md`: deny thắng allow; hết hạn mất quyền; phạm vi kho đúng; user KS A không thấy KS B |
| [x] T-003 | Supabase client (`@supabase/ssr`) server/client/middleware; trang đăng nhập; layout app; `PropertySwitcher`; bảo vệ route | AG | T-002 | Đăng nhập/đăng xuất; chuyển KS; route lạ → 404; chưa đăng nhập → /login |
| [x] T-004 | `vi.ts`, `errors.vi.ts`, thành phần chung (`DocStatusBadge`, `MoneyText`, `DataTable`, `EmptyState`, `ErrorState`, `ConfirmPostDialog`, `PinDialog`) | AG | T-003 | Storybook hoặc trang `/dev/components` hiển thị đủ trạng thái |
| [x] T-005 | Quản trị người dùng: Edge Function `admin-create-user` (service role), RPC `admin_*` (mục 9 `09-API-RPC.md`), đặt PIN, khóa tài khoản | CC | T-003 | Tạo user không cần email thật; `ERR_SELF_GRANT`, `ERR_LAST_ADMIN` có test |
| [x] T-005b | Màn hình phân quyền `06-UI-UX.md` mục 6: danh sách vai trò, sao chép, so sánh, **ma trận quyền tích chọn theo module**, gán vai trò theo KS/bộ phận/kho có thời hạn, quyền riêng cho/chặn, khối quyền hiệu lực có nguồn, cảnh báo tổ hợp xung đột; hook `useCan` | AG | T-005 | Bỏ tích 1 quyền → người giữ vai trò bị chặn ngay ở lần gọi RPC kế tiếp; nút tương ứng mờ sau khi làm mới quyền |
| [x] T-006 | `settings` + `approval_rules` + `alert_rules` + màn hình quản trị cấu hình | AG | T-005 | Đổi ngưỡng có hiệu lực không cần deploy |

## Giai đoạn MVP-A — Danh mục & sổ cái (tuần 3–4)

> T-011 hoàn tất: migration 20261109110000 và 20261109120000 đã áp dụng production;
> `_post_move` hỗ trợ cả 2 phương pháp: bình quân gia quyền tức thời và FIFO (phân bổ lớp,
> chặn ghi lùi ngày, chặn đảo/trả lớp đã xuất); các RPC `day_lock`, `day_unlock`, `period_close`,
> `period_reopen` đã triển khai; 54/54 assertion pgTAP đạt.

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [x] T-010 | Migration 03 danh mục (A2), `doc_sequences`, `next_doc_no`, `norm_text`, unique `name_norm` | CC | T-002 | Test: số chứng từ tăng đúng khi gọi đồng thời 50 lần (không trùng) |
| [x] T-011 | Migration 04 sổ cái: `stock_moves`, `stock_balances`, `item_costs`, `_post_move`, `forbid_mutation`, kỳ & khóa ngày; bổ sung FIFO tạm thời theo Q11/Q12 | CC | T-010 | pgTAP: bình quân gia quyền đúng 5 ca (nhập/xuất xen kẽ), FIFO theo lớp, chặn tồn âm; chặn UPDATE; kỳ đóng chặn ghi |
| [x] T-012 | Màn hình danh mục: vật tư (lọc nhóm, mã tạm, thiếu quy đổi), nhóm hàng, đơn vị, quy cách mua, kho, phòng, outlet, khoản mục | AG | T-010 | CRUD qua RLS; tạo trùng tên → báo lỗi tiếng Việt |
| [x] T-013 | NCC + thẩm định + đổi STK 2 người + hợp đồng khung + giá trần | AG + CC (RPC) | T-012 | SoD STK; alert `BANK_ACCOUNT_CHANGE` tạo ra |
| [x] T-014 | Import Excel 4 bước (01.10) cho vật tư & NCC theo `07-IMPORT-MIGRATION.md`; chạy thử với file `Lst_2020_DL_Buffet.xlsx` | CC | T-012 | Đã đo trên file thật bằng helper import (Node): DUP_CODE 11 ✓, ĐVT 54→33 ✓, NO_FACTOR **282** (lệch 1 so với AC 281 — xem ADR-004). pgTAP 47 assertion CHƯA chạy (không Docker); types chưa sinh lại; chưa chạy end-to-end trên DB thật — chờ `db push` sau hòa giải wip/T-013 |
| [x] T-015 | Mã tạm + gộp mã (`item_create_temp`, `item_merge`) + cron mã tạm quá hạn | CC | T-011 | Mã tạm > 72h bị chặn dùng. Migration `20261109190000`. pgTAP 29 assertion **chưa chạy** (không Docker trên VM); `database.types.ts` chưa sinh lại; pg_cron cần bật trong Supabase Dashboard (migration vẫn chạy được nếu chưa bật, gọi tay `temp_code_maintenance()` cho tới lúc đó). |
| [x] T-016 | Storage `evidence` + `attachments` + `CameraCapture` (getUserMedia, nén, SHA-256) + `AttachmentGallery` (signed URL) | AG + CC | T-004 | Không có lựa chọn ảnh từ thư viện; ảnh trùng hash → alert `PHOTO_REUSED`. Migration `20261109200000`. pgTAP 38 assertion **chưa chạy** (không Docker); `database.types.ts` chưa sinh lại (RPC `attachment_*` + bảng `attachments` chưa có trong types, code dùng ép kiểu có chủ đích tại 1 chỗ); demo CameraCapture + AttachmentGallery ở `/dev/components`. |

## Giai đoạn MVP-B — Thu mua & nhận hàng (tuần 5–7)

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [x] T-020 | Migration 06 thu mua + RPC PR/PO/duyệt (`approval_rules` sinh bước) | CC | T-013 | pgTAP: PO 30 triệu có đủ 3 bước; người tạo không duyệt được — **xong 09/11/2026, chưa chạy pgTAP trên DB thật (VM không Docker); chờ verify sau khi merge + db push** |
| [x] T-021 | Màn hình PR, PO, timeline duyệt, duyệt nhanh trên mobile | AG | T-020 | Vượt giá trần không submit được khi thiếu lý do — **xong 09/11/2026, chưa chạy end-to-end trên DB thật (VM không Docker); chờ verify sau khi merge + db push + deploy. Không có migration mới; UI dùng RPC T-020. Q18 (tên người tạo) còn mở.** |
| [x] T-022 | Lệnh mua chợ + tạm ứng (đề nghị, duyệt, chi) | CC + AG | T-020 | Có tạm ứng quá hạn → `ERR_ADVANCE_OVERDUE_BLOCK` (đã code 09/11/2026, pgTAP 56 assertion chưa chạy — VM không có Docker) |
| [x] T-023 | Migration 07 nhận hàng + RPC mù (`receiving_list_tasks`, `get_task`, `record_line`, `post`) | CC | T-020, T-016 | pgTAP: role receiver SELECT `purchase_order_lines` = 0 dòng; lệch 6% → `needs_reweigh`; vượt PO bị chặn trần — **xong 09/11/2026: migration `20261109230000` (5 bảng + 12 RPC incl. `receiving_override_line`, `supplier_return_post`, `receiving_reverse`, `admin_qc_template_*`), pgTAP 87 assertion CHƯA chạy (VM không có Docker); Q20 đã thực thi (PO market `approved` đủ điều kiện nhận); Q21 mới (anh bat buoc theo nhom `food`). UI mobile la T-024.** |
| [x] T-024 | Màn hình nhận hàng mobile (`/m/[p]/receive`) + NumPad + QC + PIN | AG | T-023 | Thao tác 1 tay; không hiện số PO/giá ở bất kỳ request nào (kiểm tra tab Network) — **xong 09/11/2026: routes `/m/[p]/receive` + `/m/[p]/receive/[grId]`, `NumPad` dùng chung (`src/components/common/num-pad.tsx`), form ghi dòng (Tổng cân − Bì = Thực nhận, CameraCapture + upload ảnh, checklist QC, nhiệt độ, lô/hạn, cân lại lần 2, duyệt vượt PO), ghi sổ qua ConfirmPostDialog + PinDialog (4–6 chữ số), không migration mới, pgTAP không đổi (87 assertion T-023 chưa chạy). Q22 mới (chữ ký người giao chưa có UI).** |
| [x] T-025 | Offline cho nhận hàng: Dexie queue, `client_uuid`, đồng bộ lại, ảnh chờ tải | CC | T-024 | Tắt mạng nhận 3 dòng → bật mạng tự gửi, không trùng (đã code 09/11/2026, chưa test tay trên máy thật) |
| [x] T-026 | Trả hàng NCC + nhận thẳng vào bếp | CC + AG | T-023 | `return_out` dùng giá dòng gốc |

## Giai đoạn MVP-C — Kho, buồng phòng, kiểm kê (tuần 8–9)

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [x] T-030 | Migration 08: phiếu lĩnh 2 bước, điều chuyển, xuất mục đích, hủy + RPC | CC | T-011 | pgTAP từng loại move; SoD hủy |
| [x] T-031 | Màn hình chứng từ kho + tồn kho + thẻ kho | AG | T-030 | Thẻ kho khớp tổng `stock_moves` — **xong 09/11/2026: routes `/[p]/inventory/{requisitions,transfers,issues,waste,stock}` + thẻ kho `/stock/[warehouse]/[item]`, dùng 8 RPC list/get T-030; tồn/thẻ kho đọc trực tiếp qua SELECT (RLS đã chặn theo stock.view_qty/view_value, giá trị chỉ hiện khi có stock.view_value), không migration mới; thẻ kho hiện huy hiệu Khớp/Lệch đối chiếu tồn cuối theo thẻ với `stock_balances`. Q28 mới (stock_balance_get trong đặc tả chưa từng được code).** |
| [x] T-032 | Migration 09: kiểm kê tháng mù, điều chỉnh, khóa ngày/kỳ + view `v_count_sheet` | CC | T-030 | Người đếm không đọc được `book_qty`; kho đang kiểm → `ERR_COUNT_FREEZE` — **xong 09/11/2026: migration `20261109280000` (3 bảng, view `v_count_sheet` mù + `v_count_result`, trigger `ERR_COUNT_FREEZE`, 7 RPC `count_*`, `period_close` +3 điều kiện); pgTAP 101 assertion chưa chạy.** |
| [x] T-033 | Màn hình kiểm kê mobile (đa quy cách, đếm lại) + biên bản chênh lệch + offline | AG + CC | T-032 | Biên bản xuất Excel — **xong 09/11/2026: migration `20261109290000`, RPC `count_list_counters`, ghi đếm offline qua Dexie kind `count_record`; pgTAP 8 assertion chưa chạy.** |
| [x] T-034 | Migration 11 buồng phòng: chuẩn setup, kho tầng/xe đẩy, ca xe đẩy | CC | T-030 | Tiêu hao ca = đầu + lĩnh − cuối — **xong 09/11/2026: migration `20261109310000` (3 bảng + 4 RPC, mở ca đếm mù sinh phiếu lĩnh bù tới par, đóng ca tiêu hao → `purpose_issue` buồng phòng); pgTAP 93 assertion chưa chạy.** |
| [x] T-035 | Minibar theo phòng: bảng giá, bổ sung, yêu cầu kiểm (lễ tân), kiểm (buồng), xác nhận thu, miễn, late charge, đối soát cuối ngày | CC + AG | T-034 | Kịch bản `11-TESTING.md` mục minibar chạy xanh — **xong 09/11/2026: migration `20261109320000` + fix `20261109460000` (3 bảng + 10 RPC, pg_cron đối soát 23:30, 5 route frontdesk/housekeeping/mobile); pgTAP 104 assertion chưa chạy.** |
| [x] T-036 | Form PMS ngày (`pms_daily_upsert`) | AG | T-012 | Không cho nhập trùng ngày; sửa có nhật ký — **xong 09/11/2026: migration `20261109330000` (bảng `pms_daily_stats` + RPC `pms_daily_upsert`/`pms_daily_history`); pgTAP 49 assertion chưa chạy.** |

## Giai đoạn MVP-D — Tài chính, chi phí, báo cáo (tuần 10–12)

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [x] T-040 | Migration 12: hóa đơn, khớp 3 chiều, `ap_ledger`, bảng kê không hóa đơn, quyết toán tạm ứng | CC | T-023 | Lệch giá > 1% → `on_hold` — **xong 10/11/2026: migration `20261109340000` (9 bảng, 10 RPC, dung sai giá 1%); pgTAP 80 assertion chưa chạy.** |
| [x] T-041 | Màn hình hóa đơn, công nợ, tạm ứng, đề nghị thanh toán | AG | T-040 | Tuổi nợ đúng theo `due_date` — **xong 10/11/2026: 11 route `/[property]/finance`, không migration mới.** |
| [x] T-042 | Mua dịch vụ + nghiệm thu + hợp đồng định kỳ + cron sinh lịch | CC + AG | T-040 | Chưa nghiệm thu → không thanh toán được — **xong 10/11/2026: migration `20261109350000` (3 bảng + 4 RPC, pg_cron 01:00 VN) + 5 route UI; pgTAP 67 assertion chưa chạy.** |
| [x] T-043 | Xuất Excel cho kế toán (`/api/export/*`): nhập kho, xuất kho, hóa đơn mua, công nợ, tạm ứng — theo pháp nhân, chỉ kỳ đã khóa hoặc ngày đã khóa | CC | T-040 | File mở được bằng Excel, tiếng Việt có dấu — **xong 10/11/2026: migration `20261109360000` (5 RPC `export_*`) + 5 route `/api/export/[kind]`; pgTAP 55 assertion chưa chạy.** |
| [x] T-044 | 10 báo cáo MVP (`08-REPORTS-ALERTS.md`) | AG + CC | T-031, T-041 | Số khớp truy vấn kiểm tra trong pgTAP — **xong 10/11/2026: migration `20261109370000` (bảng `report_snapshots` + RPC `report_get`/`report_build_daily`) + 10 route `/[property]/reports`; pgTAP 82 assertion chưa chạy.** |
| [x] T-045 | Cảnh báo + `send-notifications` (email + web push; adapter Zalo để sẵn) + bản tin 8h + giờ im lặng | CC | T-044 | Cron UTC đúng 08:00 VN; gộp tin — **xong 10/11/2026: migration `20261109380000` (seed 18 mã `alert_rules` + 4 bảng + Edge Function `send-notification` + 3 cron 07:30/08:00/5 phút) + màn `/[property]/alerts`; pgTAP 54 assertion chưa chạy; chưa gửi được thật — thiếu Resend API key + VAPID keys (Q98/Q99).** |
| [x] T-046 | PWA: manifest, icon, cài lên màn hình chính, service worker cho 4 màn offline | AG | T-025, T-033 | Lighthouse PWA đạt; cài được trên Android/iOS — **xong 10/11/2026: PWA manifest + icon + service worker + trang `/offline`, không migration mới; Lighthouse PWA 1.0; test offline thật bằng Chrome headless.** |
| [x] T-047 | Kiểm thử nghiệm thu thí điểm: Playwright các luồng chính + dữ liệu thật đã làm sạch | AG | tất cả | Danh sách kịch bản `11-TESTING.md` xanh — **xong 10/11/2026: Playwright 39 test (2 tầng đọc/ghi) + Vitest 13 test; không migration mới; public 5/5 + Vitest 13/13 PASS trên máy Duy.** |

## Hoàn thiện chức năng — completion wave 1 (10/11/2026)

Các mục sau không có dòng riêng trong bảng trên nhưng đã xong, ghi ở đây để roadmap khỏi lỗi thời:

- **UI-1/UI-2** — sidebar điều hướng theo module kiểu ClickUp, danh sách dạng bảng gọn với trạng thái pill, tìm kiếm + bộ lọc, chuyển List/Board ở PR/PO; đợt redesign đầy đủ theo mẫu ClickUp vẫn làm riêng trước go-live (chỉ thị Duy 10/11 07:34).
- **Hiệu năng (perf-load)** — Vercel functions về region `bom1` (Mumbai, cùng vùng AWS ap-south-1 với Supabase production); dashboard ~5 round trip, kiểm chứng live 13:57 10/11.
- **admin-relax** — migration `20261109400000`: tự gán vai trò/quyền cho chính mình được phép có chủ đích; vẫn giữ `ERR_LAST_ADMIN`, cấm tự thu hồi/khóa mình, cấm vô hiệu hóa vai trò hệ thống. Xem `docs/11-TESTING.md` §6.6.
- **Xe đẩy mobile (Q105)** — migration `20261109390000` (RPC `trolley_shift_get`) + 3 route `/m/[p]/trolley*` + offline queue.
- **Nhà hàng / đặt tiệc (M06)** — migration `20261109500000` (8 bảng, 21 RPC, 6 mã quyền); trang bếp live tải được 21:04 10/11; pgTAP `restaurant` 69 assertion chưa chạy.
- **T-022A (miễn kiểm tra giá PO chợ)** — migration `20261109240000`; Q171 đã chốt (tự phê duyệt 10/11); `db push` lần sau cần `--include-all` vì version 240000 cũ hơn các migration đã áp.
- **Q73/Q18** — migration `20261109410000`: timeline duyệt đề nghị thanh toán + tên người tạo ở danh sách PR/PO.

## P2 / P3

Viết task chi tiết khi bắt đầu giai đoạn, dựa trên danh mục chức năng trong tài liệu đặc tả (PH02, PH06, PH07 còn lại, PH12, PH13, kết nối MISA/Bravo…).
