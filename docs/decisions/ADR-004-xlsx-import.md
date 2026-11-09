# ADR-004 — Import Excel dùng SheetJS (xlsx) + bảng import trong DB (T-014)

- Ngày: 09/11/2026
- Trạng thái: Đã chấp nhận
- Liên quan: `docs/07-IMPORT-MIGRATION.md` §01.10, T-014, AGENTS.md §2 (Excel: `xlsx` đọc, `exceljs` xuất)

## Bối cảnh

T-014 cần nhập vật tư & NCC từ file Excel của khách (file mẫu thật
`Lst_2020_DL_Buffet.xlsx`: sheet NVL 1.168 dòng, tiêu đề có tiền tố số,
cột "Mã và tên" gộp, 54 biến thể ĐVT, nhiều dòng thiếu mã/hệ số).
Trước T-014, `xlsx` chưa có trong `package.json` dù AGENTS.md §2 đã chỉ
định SheetJS làm thư viện đọc file import.

## Quyết định

1. **Thêm `xlsx 0.18.5`** (thư viện đọc theo đúng AGENTS.md §2).
   Không thêm `exceljs`: báo cáo kết quả import (file .xlsx tải về sau
   commit) cũng xuất bằng `xlsx` ở phía client cho khỏi thêm dependency;
   `exceljs` giữ lại cho các báo cáo nghiệp vụ phức tạp sau này.
2. **Parse ở client, validate + commit ở server.** SheetJS chỉ đọc sheet
   thành lưới ô thô; mọi chuẩn hóa, kiểm tra trùng, sinh mã và ghi DB
   đều qua RPC Postgres (`import_validate_batch`, `import_commit_batch`).
   TypeScript không chứa logic nghiệp vụ (theo AGENTS.md §5).
3. **Trạng thái import lưu trong DB** (`import_batches`, `import_rows`),
   không giữ trong bộ nhớ trình duyệt: nhập dở vẫn xem lại được, có
   audit trail, và nhiều người cùng xử lý một batch.
4. **Chuẩn hóa ĐVT** = NFC + trim + lower + bỏ dấu (`extensions.unaccent`)
   rồi tra bảng `uoms`, nếu không có thì tra `uom_aliases`. Seed 3 alias:
   `gr → g`, `lit → l`, `qua → trai`. Người có `item.manage` được thêm
   alias mới ngay trong màn sửa lỗi (`import_add_uom_alias`).
5. **Thiếu hệ số (NO_FACTOR) chỉ chặn với nhóm thực phẩm/đồ uống**
   (food/beverage); nhóm khác (CCDC…) chỉ cảnh báo. Lý do: CCDC không
   có ĐVT công thức nên hệ số không có ý nghĩa nghiệp vụ.
6. **Không import công thức (recipe) trong T-014.** Sheet Menu/02 DL góc
   cần `portions_per_batch` từ bếp + giao diện khớp món thủ công — là P2
   theo DATA-MODEL A7, làm ở task riêng.
7. **Sinh mã** qua bảng `item_code_sequences` + RPC `next_item_code`
   (khóa dòng, bỏ qua mã đã tồn tại), tiền tố theo nhóm
   (TP-0001, CCDC-0001…).
8. **Mã tạm / gộp mã** dùng cơ chế resolve của import (`split`, `merge`,
   `keep`, `skip`) — RPC `item_merge` đầy đủ (T-015) làm sau.

## Đo thực tế trên file mẫu thật (09/11/2026, chạy helper `src/lib/import/xlsx.ts` ở Node)

- Sheet NVL: 662 dòng dữ liệu (có mã hoặc tên), 668 dòng có ô dữ liệu.
- DUP_CODE: **11** mã có ≥ 2 tên khác nhau — khớp AC.
- ĐVT: 54 biến thể thô ở cột ĐVT kho (53 khác rỗng + 1 ô trống),
  59 biến thể gộp cả 2 cột ĐVT → **33** mã chuẩn sau khi gộp
  `quả → trái` — khớp AC (không gộp thì 34).
- NO_FACTOR: **282** dòng thiếu hệ số trong 662 dòng — **lệch 1 so với
  AC (281)**. Đã đếm lại 2 lần bằng 2 script độc lập (330 dòng đủ mã+tên,
  332 dòng chỉ có tên, 0 dòng chỉ có mã); không tìm ra quy tắc đếm nào
  của AC cho ra 281. Import vẫn gắn cờ đủ 282 dòng (lỗi/cảnh báo theo
  nhóm) — lệch 1 này ghi nhận ở đây, không ép số cho khớp.
- 332/662 dòng thiếu mã (NO_CODE) → sẽ sinh mã tự động khi commit.

## Hệ quả

- Migration `20261109180000_import_excel.sql` phụ thuộc schema
  vật tư/NCC của T-012/T-013 → chỉ `db push` SAU khi xong migration
  hòa giải wip/T-013 (xem CHANGELOG/roadmap).
- `database.types.ts` chưa sinh lại (cần Docker): phải bổ sung các bảng
  `import_mappings`, `import_batches`, `import_rows`, `uom_aliases`,
  `item_code_sequences` và các hàm `import_*` khi có DB local.
- pgTAP `supabase/tests/import_excel_test.sql` (47 assertion) chưa chạy
  (không Docker) — chạy lại sau khi `db push` hoặc trên DB local.
