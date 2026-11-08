# Mini-ERP Chuỗi khách sạn

Ứng dụng nội bộ quản lý thu mua, kho, F&B, buồng phòng và chi phí vận hành cho chuỗi khách sạn. Đặc tả nghiệp vụ là nguồn sự thật trong thư mục [`docs/`](./docs/); tiến độ triển khai theo [`docs/10-ROADMAP-TASKS.md`](./docs/10-ROADMAP-TASKS.md).

## Công nghệ

- Next.js App Router, React, TypeScript strict
- Tailwind CSS và shadcn/ui
- Supabase local: PostgreSQL, Auth, Storage, RLS và RPC
- pnpm

## Yêu cầu

- Node.js 22+
- pnpm 12+
- Docker Desktop đang chạy để sử dụng Supabase local

## Chạy lần đầu

```bash
pnpm install
pnpm dev
```

Mở [http://localhost:3000](http://localhost:3000).

Để chạy Supabase local trong terminal khác:

```bash
pnpm exec supabase start
```

Các migration, seed và kiểm thử cơ sở dữ liệu sẽ được bổ sung theo roadmap. Không dùng khóa production trong môi trường local.

## Kết nối Supabase hosted

Đặt `NEXT_PUBLIC_SUPABASE_URL` và `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` trong `.env.local` khi phát triển, và trong Environment Variables của Vercel cho Production, Preview và Development. Client SSR dùng cookie qua `src/lib/supabase/`; không đưa secret/service-role key vào trình duyệt. Secret key đã lộ cần được thu hồi và thay mới trong Supabase.

Project Vercel đích: [erp_hotel](https://vercel.com/dnduys-projects/erp_hotel). Chỉ triển khai sau khi xác nhận repository Git được kết nối là repository dự án này.

## Kiểm tra

```bash
pnpm lint
pnpm typecheck
pnpm format:check
pnpm build
```

GitHub Actions chạy lint và type-check cho pull request, `main` và `develop`.

## Tài liệu dự án

- [`AGENTS.md`](./AGENTS.md): quy tắc kiến trúc, nghiệp vụ và code bắt buộc.
- [`docs/01-PRD.md`](./docs/01-PRD.md): mục tiêu và phạm vi MVP/P2/P3.
- [`docs/02-ARCHITECTURE.md`](./docs/02-ARCHITECTURE.md): kiến trúc hệ thống.
- [`docs/03-DATA-MODEL.md`](./docs/03-DATA-MODEL.md), [`docs/04-SECURITY-RLS.md`](./docs/04-SECURITY-RLS.md), [`docs/05-BUSINESS-RULES.md`](./docs/05-BUSINESS-RULES.md): dữ liệu, bảo mật và nghiệp vụ.
- [`docs/10-ROADMAP-TASKS.md`](./docs/10-ROADMAP-TASKS.md): task và tiêu chí nghiệm thu.
- [`docs/decisions/ADR-002-supabase-ssr-client.md`](./docs/decisions/ADR-002-supabase-ssr-client.md): tích hợp Supabase SSR và xử lý khóa.

Mọi giao diện người dùng phải dùng tiếng Việt; chuỗi giao diện được quản lý trong [`src/i18n/vi.ts`](./src/i18n/vi.ts).
