# AGENTS.md — Quy tắc bắt buộc cho mọi AI agent

File này là "hiến pháp" của dự án. Mọi agent (Claude Code, Antigravity, Muse hoặc agent khác) phải đọc file này trước khi viết code. Nếu yêu cầu của một task mâu thuẫn với file này, **dừng lại và hỏi**, không tự quyết.

## 1. Dự án là gì

**Mini-ERP Thu mua – Kho – F&B – Buồng phòng – Chi phí vận hành** cho một chuỗi khách sạn tại Việt Nam (nhiều khách sạn, **mỗi khách sạn là một pháp nhân riêng**).

Mục tiêu: chặn thất thoát ở các khâu mua – nhận – lưu kho – sử dụng – bán, và cho chủ đầu tư con số chi phí thật mỗi sáng.

Ứng dụng là **hệ thống quản lý nội bộ chạy độc lập**. Giai đoạn đầu **không kết nối** PMS, POS, MISA, Bravo — dữ liệu từ các hệ thống đó vào bằng form hoặc file; dữ liệu ra cho kế toán bằng file Excel. Kết nối API làm sau, qua lớp adapter.

Đọc theo thứ tự: `docs/01-PRD.md` → `docs/02-ARCHITECTURE.md` → `docs/03-DATA-MODEL.md` → `docs/05-BUSINESS-RULES.md` → file module liên quan trong `docs/modules/`.

## 2. Stack (không tự đổi)

| Lớp | Công nghệ |
|---|---|
| Frontend | Next.js (App Router, bản ổn định mới nhất), TypeScript `strict`, React Server Components + Server Actions |
| UI | Tailwind CSS + shadcn/ui, icon `lucide-react` |
| Form & validate | React Hook Form + Zod (schema Zod dùng chung client/server) |
| Dữ liệu client | `@supabase/ssr` (cookie session), TanStack Query cho màn hình cần cache/offline |
| Offline | PWA (service worker) + IndexedDB qua Dexie — **chỉ** màn hình nhận hàng, kiểm kê, xe đẩy buồng phòng, kiểm minibar |
| Backend | Supabase: Postgres, Auth, Storage, RLS, RPC (hàm Postgres), Edge Functions, `pg_cron`, `pg_net` |
| Excel | `exceljs` (xuất), `xlsx`/SheetJS (đọc file import) |
| Test | pgTAP (`supabase test db`), Vitest, Playwright |
| Hosting | Vercel (web) + Supabase Cloud (region ap-south-1 Mumbai) |

Thêm thư viện mới → ghi lý do vào `docs/decisions/ADR-xxx.md` trước.

## 3. Mười một quy tắc vàng

1. **Mọi thay đổi tồn kho và tiền đi qua hàm RPC "post" trong Postgres** (`SECURITY DEFINER`, kiểm tra quyền + SoD bên trong). Client **không bao giờ** INSERT/UPDATE trực tiếp vào `stock_moves`, `ap_ledger`, `stock_balances`, `item_costs`.
2. **Sổ cái bất biến.** `stock_moves`, `ap_ledger`, `audit_log` chỉ INSERT. Sửa sai = bút toán đảo (`reverses_move_id`) + bút toán mới. Trigger chặn UPDATE/DELETE.
3. **Chứng từ đã `posted` không sửa, không xóa.** Chỉ được `reverse`.
4. **RLS bật cho 100% bảng** trong schema `public`. Không có bảng nào "tạm tắt RLS". Service role key **chỉ** dùng trong Edge Function và route handler `/api/cron/*`, `/api/import/*` có kiểm tra secret — không bao giờ ra trình duyệt.
5. **Mọi bảng nghiệp vụ có `legal_entity_id` và/hoặc `property_id`.** Dữ liệu tách theo pháp nhân; danh mục vật tư và NCC dùng chung cấp chuỗi (`org_id`).
6. **Thay đổi schema chỉ qua migration** trong `supabase/migrations/`. Sau mỗi migration chạy `supabase gen types typescript --local > src/lib/database.types.ts`.
7. **Tiền và số lượng tính trong Postgres** (`numeric`). Phía JS không cộng trừ tiền bằng `number` để lưu; chỉ hiển thị. Tiền VND `numeric(18,2)`, số lượng `numeric(18,4)`, đơn giá `numeric(18,4)`.
8. **Ngày nghiệp vụ theo `Asia/Ho_Chi_Minh`.** Lưu `timestamptz` cho thời điểm; lưu `business_date date` riêng cho ngày nghiệp vụ. Thời điểm chụp ảnh/nhận hàng lấy **giờ máy chủ** (`now()`), không tin giờ thiết bị.
9. **"Mù" được thực thi ở tầng dữ liệu, không chỉ ẩn ở giao diện.** Vai trò nhận hàng/đếm kho không SELECT được số lượng PO, đơn giá, tồn lý thuyết (RLS + view riêng + RPC trả về tối thiểu).
10. **Phân quyền động — kiểm tra quyền, không kiểm tra vai trò.** Vai trò và quyền do quản trị cấu hình trên giao diện. Code chỉ dùng `has_perm(property, 'ma.quyen')` / `require_perm(...)` trong SQL và `useCan('ma.quyen')` ở UI; **cấm** so sánh tên vai trò (`role = 'gm'`). Tính năng mới phải thêm mã quyền vào seed `permissions` và gán vào vai trò mẫu phù hợp. Xem `docs/04-SECURITY-RLS.md`.
11. **Giao diện tiếng Việt có dấu đầy đủ.** Mọi chuỗi hiển thị nằm trong `src/i18n/vi.ts` (chuẩn bị cho tiếng Anh sau). Không hard-code chuỗi trong component.

## 4. Cấu trúc thư mục

```
/
├─ AGENTS.md  CLAUDE.md  README.md
├─ docs/                      # nguồn sự thật nghiệp vụ — đọc trước khi code
├─ supabase/
│  ├─ migrations/             # YYYYMMDDHHMMSS_<ten>.sql
│  ├─ functions/              # Edge Functions (Deno)
│  ├─ tests/                  # pgTAP: *_test.sql
│  └─ seed.sql
├─ src/
│  ├─ app/
│  │  ├─ (auth)/login/
│  │  ├─ (app)/[property]/... # route theo khách sạn đang chọn
│  │  ├─ m/[property]/...     # màn hình mobile hiện trường (nhận hàng, đếm, xe đẩy, minibar)
│  │  └─ api/cron|import|export/
│  ├─ components/ui/          # shadcn
│  ├─ components/<module>/
│  ├─ features/<module>/      # schema zod, server actions, queries
│  ├─ lib/supabase/{server,client,middleware}.ts
│  ├─ lib/database.types.ts   # sinh tự động, không sửa tay
│  ├─ lib/offline/            # Dexie queue
│  └─ i18n/vi.ts
└─ tests/e2e/                 # Playwright
```

## 5. Quy ước code

- Tên bảng/cột: `snake_case`, tiếng Anh. Tên hiển thị: tiếng Việt trong `vi.ts`.
- Mỗi chứng từ có: `id uuid`, `doc_no text` (sinh bởi `next_doc_no()`), `status`, `created_by`, `created_at`, `updated_at`.
- RPC đặt tên `<module>_<động từ>`: `po_submit`, `receiving_record_line`, `count_lock`.
- RPC ghi dữ liệu trả về `jsonb` dạng `{ ok: true, id, ... }` hoặc `raise exception` với mã lỗi dạng `'ERR_SOD_SAME_USER'` (danh sách mã lỗi ở `docs/09-API-RPC.md`). UI map mã lỗi sang câu tiếng Việt.
- Server Action gọi RPC, không viết logic nghiệp vụ trong TypeScript.
- Mỗi màn hình có 4 trạng thái: đang tải, rỗng, lỗi, có dữ liệu.
- Không `any`. Không tắt ESLint rule để cho qua.

## 6. Lệnh thường dùng

```bash
pnpm i
supabase start                      # Postgres + Studio local
supabase migration new <ten>
supabase db reset                   # chạy lại migration + seed
supabase test db                    # pgTAP
supabase gen types typescript --local > src/lib/database.types.ts
pnpm dev | pnpm lint | pnpm typecheck | pnpm test | pnpm e2e
```

## 7. Definition of Done cho mỗi task

- [ ] Code + migration + types sinh lại
- [ ] RLS cho bảng mới + pgTAP test cho mọi RPC post (đúng quyền, sai quyền, SoD, số dư)
- [ ] Mã quyền mới (nếu có) đã thêm vào seed `permissions`, gán vào vai trò mẫu, và nút/menu UI bọc `useCan`
- [ ] Vitest cho schema Zod / hàm tiện ích; Playwright nếu là luồng màn hình chính
- [ ] `pnpm lint && pnpm typecheck && pnpm test && supabase test db` xanh
- [ ] Cập nhật `docs/` nếu hành vi khác đặc tả, ghi vào `CHANGELOG.md`
- [ ] Không còn `TODO` không có mã task

## 8. Khi không chắc

- Đặc tả thiếu → tìm trong `docs/05-BUSINESS-RULES.md`; vẫn thiếu → hỏi, ghi câu hỏi vào `docs/OPEN-QUESTIONS.md`.
- Không tự "đơn giản hóa" quy tắc chống gian lận (nhận hàng mù, đếm mù, SoD, sổ cái bất biến) vì thấy phức tạp. Đó là lý do tồn tại của sản phẩm.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
