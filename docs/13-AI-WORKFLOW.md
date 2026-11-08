# 13 — Phối hợp Antigravity + Muse + Claude Code

## 1. Nguyên tắc chung

1. **Tài liệu là nguồn sự thật.** Không agent nào được "nhớ" quyết định ngoài `docs/`. Quyết định mới → ghi `docs/decisions/ADR-xxx.md`.
2. **Một task – một agent – một nhánh.** Không cho hai agent sửa cùng một file trong cùng thời điểm.
3. **Agent khác review.** Task do agent A làm thì agent B (hoặc mày) review PR trước khi merge.
4. **Mọi agent nạp `AGENTS.md` làm ngữ cảnh thường trực** (Claude Code tự đọc qua `CLAUDE.md`; với Antigravity và Muse, thêm `AGENTS.md` vào phần rules/context của workspace).
5. Agent kết thúc phiên phải cập nhật `CHANGELOG.md` và đánh dấu task.

## 2. Phân vai gợi ý

| Công cụ | Giao việc | Lý do |
|---|---|---|
| **Claude Code** | Migration SQL, RLS, RPC, pgTAP, Edge Functions, import/export Excel, offline queue, review bảo mật PR của agent khác | Làm việc qua terminal, chạy được `supabase` CLI và test ngay |
| **Antigravity** | Màn hình Next.js, component, luồng mobile, kiểm tra trên trình duyệt (Network tab, viewport điện thoại), Playwright | Mạnh ở thao tác giao diện + kiểm tra trực quan |
| **Muse** | Việc mày thấy hợp nhất với Muse — ví dụ tạo nhanh bản nháp màn hình, viết tài liệu người dùng, dữ liệu mẫu; nạp `AGENTS.md` như các agent khác | Điều chỉnh sau khi dùng thử |

Cột "Agent gợi ý" trong `10-ROADMAP-TASKS.md` theo bảng này; mày đổi tùy ý.

## 3. Mẫu prompt giao task (dán cho agent)

```
Đọc AGENTS.md, docs/02-ARCHITECTURE.md, docs/03-DATA-MODEL.md, docs/05-BUSINESS-RULES.md
và các file docs liên quan tới task.

Thực hiện task T-0xx trong docs/10-ROADMAP-TASKS.md.
1. Nhắc lại mục tiêu và tiêu chí nghiệm thu bằng 5 dòng.
2. Liệt kê file sẽ tạo/sửa trước khi làm.
3. Làm, chạy test, sửa tới khi xanh.
4. Không thay đổi phạm vi ngoài task; thấy vấn đề ngoài phạm vi → ghi vào docs/OPEN-QUESTIONS.md.
5. Kết thúc: tóm tắt thay đổi, cập nhật CHANGELOG.md, đánh dấu [x] task.
```

## 4. Mẫu prompt review

```
Review nhánh task/T-0xx theo AGENTS.md.
Kiểm tra bắt buộc: RLS cho bảng mới; RPC có security definer + search_path + kiểm quyền + SoD;
không client nào ghi trực tiếp vào stock_moves/ap_ledger; "mù" không bị lộ qua API;
chuỗi giao diện nằm trong vi.ts; có test cho mọi RPC post.
Liệt kê lỗi theo mức nghiêm trọng, không tự sửa trừ lỗi nhỏ.
```

## 5. Thứ tự làm việc trong ngày gợi ý

1. Claude Code làm task backend (migration + RPC + test).
2. Sinh types → commit.
3. Antigravity làm màn hình tương ứng dựa trên types mới.
4. Claude Code review PR giao diện về bảo mật; Antigravity review PR backend về khả năng dùng từ UI.
5. Merge vào `develop` → staging tự cập nhật → mày kiểm tra trên điện thoại.

## 6. Chống "trôi" khi dùng nhiều agent

- Không để agent tự sinh lại `database.types.ts` bằng tay — luôn dùng lệnh CLI.
- Không để agent thêm cột mới mà không có migration.
- Khi agent đề xuất "đơn giản hóa" quy tắc chống gian lận → từ chối, chỉ vào `AGENTS.md` mục 8.
- Mỗi tuần chạy 1 phiên Claude Code: "Đối chiếu code với docs, liệt kê chỗ lệch".
