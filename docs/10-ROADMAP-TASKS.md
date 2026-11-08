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
| [ ] T-005 | Quản trị người dùng: Edge Function `admin-create-user` (service role), RPC `admin_*` (mục 9 `09-API-RPC.md`), đặt PIN, khóa tài khoản | CC | T-003 | Tạo user không cần email thật; `ERR_SELF_GRANT`, `ERR_LAST_ADMIN` có test |
| [ ] T-005b | Màn hình phân quyền `06-UI-UX.md` mục 6: danh sách vai trò, sao chép, so sánh, **ma trận quyền tích chọn theo module**, gán vai trò theo KS/bộ phận/kho có thời hạn, quyền riêng cho/chặn, khối quyền hiệu lực có nguồn, cảnh báo tổ hợp xung đột; hook `useCan` | AG | T-005 | Bỏ tích 1 quyền → người giữ vai trò bị chặn ngay ở lần gọi RPC kế tiếp; nút tương ứng mờ sau khi làm mới quyền |
| [ ] T-006 | `settings` + `approval_rules` + `alert_rules` + màn hình quản trị cấu hình | AG | T-005 | Đổi ngưỡng có hiệu lực không cần deploy |

## Giai đoạn MVP-A — Danh mục & sổ cái (tuần 3–4)

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [ ] T-010 | Migration 03 danh mục (A2), `doc_sequences`, `next_doc_no`, `norm_text`, unique `name_norm` | CC | T-002 | Test: số chứng từ tăng đúng khi gọi đồng thời 50 lần (không trùng) |
| [ ] T-011 | Migration 04 sổ cái: `stock_moves`, `stock_balances`, `item_costs`, `_post_move`, `forbid_mutation`, kỳ & khóa ngày | CC | T-010 | pgTAP: bình quân gia quyền đúng 5 ca (nhập/xuất xen kẽ); chặn tồn âm; chặn UPDATE; kỳ đóng chặn ghi |
| [ ] T-012 | Màn hình danh mục: vật tư (lọc nhóm, mã tạm, thiếu quy đổi), nhóm hàng, đơn vị, quy cách mua, kho, phòng, outlet, khoản mục | AG | T-010 | CRUD qua RLS; tạo trùng tên → báo lỗi tiếng Việt |
| [ ] T-013 | NCC + thẩm định + đổi STK 2 người + hợp đồng khung + giá trần | AG + CC (RPC) | T-012 | SoD STK; alert `BANK_ACCOUNT_CHANGE` tạo ra |
| [ ] T-014 | Import Excel 4 bước (01.10) cho vật tư & NCC theo `07-IMPORT-MIGRATION.md`; chạy thử với file `Lst_2020_DL_Buffet.xlsx` | CC | T-012 | Phát hiện đủ 11 mã trùng, 54→33 đơn vị, 281 thiếu hệ số trên file mẫu |
| [ ] T-015 | Mã tạm + gộp mã (`item_create_temp`, `item_merge`) + cron mã tạm quá hạn | CC | T-011 | Mã tạm > 72h bị chặn dùng |
| [ ] T-016 | Storage `evidence` + `attachments` + `CameraCapture` (getUserMedia, nén, SHA-256) + `AttachmentGallery` (signed URL) | AG + CC | T-004 | Không có lựa chọn ảnh từ thư viện; ảnh trùng hash → alert `PHOTO_REUSED` |

## Giai đoạn MVP-B — Thu mua & nhận hàng (tuần 5–7)

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [ ] T-020 | Migration 06 thu mua + RPC PR/PO/duyệt (`approval_rules` sinh bước) | CC | T-013 | pgTAP: PO 30 triệu có đủ 3 bước; người tạo không duyệt được |
| [ ] T-021 | Màn hình PR, PO, timeline duyệt, duyệt nhanh trên mobile | AG | T-020 | Vượt giá trần không submit được khi thiếu lý do |
| [ ] T-022 | Lệnh mua chợ + tạm ứng (đề nghị, duyệt, chi) | CC + AG | T-020 | Có tạm ứng quá hạn → `ERR_ADVANCE_OVERDUE_BLOCK` |
| [ ] T-023 | Migration 07 nhận hàng + RPC mù (`receiving_list_tasks`, `get_task`, `record_line`, `post`) | CC | T-020, T-016 | pgTAP: role receiver SELECT `purchase_order_lines` = 0 dòng; lệch 6% → `needs_reweigh`; vượt PO bị chặn trần |
| [ ] T-024 | Màn hình nhận hàng mobile (`/m/[p]/receive`) + NumPad + QC + PIN | AG | T-023 | Thao tác 1 tay; không hiện số PO/giá ở bất kỳ request nào (kiểm tra tab Network) |
| [ ] T-025 | Offline cho nhận hàng: Dexie queue, `client_uuid`, đồng bộ lại, ảnh chờ tải | CC | T-024 | Tắt mạng nhận 3 dòng → bật mạng tự gửi, không trùng |
| [ ] T-026 | Trả hàng NCC + nhận thẳng vào bếp | CC + AG | T-023 | `return_out` dùng giá dòng gốc |

## Giai đoạn MVP-C — Kho, buồng phòng, kiểm kê (tuần 8–9)

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [ ] T-030 | Migration 08: phiếu lĩnh 2 bước, điều chuyển, xuất mục đích, hủy + RPC | CC | T-011 | pgTAP từng loại move; SoD hủy |
| [ ] T-031 | Màn hình chứng từ kho + tồn kho + thẻ kho | AG | T-030 | Thẻ kho khớp tổng `stock_moves` |
| [ ] T-032 | Migration 09: kiểm kê tháng mù, điều chỉnh, khóa ngày/kỳ + view `v_count_sheet` | CC | T-030 | Người đếm không đọc được `book_qty`; kho đang kiểm → `ERR_COUNT_FREEZE` |
| [ ] T-033 | Màn hình kiểm kê mobile (đa quy cách, đếm lại) + biên bản chênh lệch + offline | AG + CC | T-032 | Biên bản xuất Excel |
| [ ] T-034 | Migration 11 buồng phòng: chuẩn setup, kho tầng/xe đẩy, ca xe đẩy | CC | T-030 | Tiêu hao ca = đầu + lĩnh − cuối |
| [ ] T-035 | Minibar theo phòng: bảng giá, bổ sung, yêu cầu kiểm (lễ tân), kiểm (buồng), xác nhận thu, miễn, late charge, đối soát cuối ngày | CC + AG | T-034 | Kịch bản `11-TESTING.md` mục minibar chạy xanh |
| [ ] T-036 | Form PMS ngày (`pms_daily_upsert`) | AG | T-012 | Không cho nhập trùng ngày; sửa có nhật ký |

## Giai đoạn MVP-D — Tài chính, chi phí, báo cáo (tuần 10–12)

| # | Task | Agent | Phụ thuộc | AC chính |
|---|---|---|---|---|
| [ ] T-040 | Migration 12: hóa đơn, khớp 3 chiều, `ap_ledger`, bảng kê không hóa đơn, quyết toán tạm ứng | CC | T-023 | Lệch giá > 1% → `on_hold` |
| [ ] T-041 | Màn hình hóa đơn, công nợ, tạm ứng, đề nghị thanh toán | AG | T-040 | Tuổi nợ đúng theo `due_date` |
| [ ] T-042 | Mua dịch vụ + nghiệm thu + hợp đồng định kỳ + cron sinh lịch | CC + AG | T-040 | Chưa nghiệm thu → không thanh toán được |
| [ ] T-043 | Xuất Excel cho kế toán (`/api/export/*`): nhập kho, xuất kho, hóa đơn mua, công nợ, tạm ứng — theo pháp nhân, chỉ kỳ đã khóa hoặc ngày đã khóa | CC | T-040 | File mở được bằng Excel, tiếng Việt có dấu |
| [ ] T-044 | 10 báo cáo MVP (`08-REPORTS-ALERTS.md`) | AG + CC | T-031, T-041 | Số khớp truy vấn kiểm tra trong pgTAP |
| [ ] T-045 | Cảnh báo + `send-notifications` (email + web push; adapter Zalo để sẵn) + bản tin 8h + giờ im lặng | CC | T-044 | Cron UTC đúng 08:00 VN; gộp tin |
| [ ] T-046 | PWA: manifest, icon, cài lên màn hình chính, service worker cho 4 màn offline | AG | T-025, T-033 | Lighthouse PWA đạt; cài được trên Android/iOS |
| [ ] T-047 | Kiểm thử nghiệm thu thí điểm: Playwright các luồng chính + dữ liệu thật đã làm sạch | AG | tất cả | Danh sách kịch bản `11-TESTING.md` xanh |

## P2 / P3

Viết task chi tiết khi bắt đầu giai đoạn, dựa trên danh mục chức năng trong tài liệu đặc tả (PH02, PH06, PH07 còn lại, PH12, PH13, kết nối MISA/Bravo…).
