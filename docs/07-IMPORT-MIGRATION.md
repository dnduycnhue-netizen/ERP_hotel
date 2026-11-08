# 07 — Nhập dữ liệu từ Excel hiện tại

## 1. Hiện trạng (đã phân tích 4 file khách gửi — cách quản lý hiện vẫn như vậy)

| File | Dùng gì khi nhập | Lỗi đã thấy cần xử lý |
|---|---|---|
| `Lst_2020_DL_Buffet.xlsx` sheet `NVL` | Danh mục vật tư | 50% không có mã; 11 mã gán cho 2 mặt hàng (vd. NVL0029 = cua nguyên con và cua hộp 450 g); 54 cách ghi cho 33 đơn vị (kg/KG/Kg; "Cái" 2 kiểu Unicode); 43% thiếu hệ số quy đổi; 236 dòng là CCDC lẫn vào |
| `Lst_Alacarte_foodcost.xlsx` sheet `NVL` | Bản danh mục thứ hai | Lệch 1 dòng với bản trên → gộp |
| `…Buffet.xlsx` sheet `Menu`, `02 DL góc` | 75 món buffet, 358 dòng định lượng | Định lượng theo khay chứ không theo khách; 3 món thiếu định lượng; 9 nguyên liệu gõ tên khác danh mục; mã món `#N/A` |
| `…Buffet.xlsx` sheet `Order NVL`, `02 Định lượng` | **Không nhập** | Phương pháp sai (cộng mọi món × số khách); đơn giá sai đơn vị (food cost 967%) |
| `…Alacarte_foodcost.xlsx` sheet `Foodcost` | 6 món Á-la-carte | Không có đơn giá; 4 dòng thiếu số lượng |
| `…Buffet.xlsx` sheet set menu / dị ứng | Set menu, thực đơn lactose | Nhập dạng `set_menu` + `diet_flags` |
| `Nhập xuất Minibar.xlsx` | Chỉ lấy danh sách món + giá bán | Tồn âm, ghi đè; không theo phòng → tồn đầu lấy bằng kiểm đếm thực tế |
| `…Amenities….xlsx` | Danh sách amenities + định mức tham khảo | Không tách phòng trả/ở tiếp; số phòng thiếu 9/23 ngày |

Cột "Mã Bravo", "Nhóm Bravo" → lưu vào `items.legacy_code` và `external_codes.bravo`.

## 2. Quy trình import (chức năng 01.10)

Màn hình `/[p]/master/import` — 4 bước, không ghi gì cho tới bước 4:

1. **Tải file + chọn mẫu ánh xạ** (`import_mappings`): chọn sheet, dòng tiêu đề, ánh xạ cột → trường. Lưu mẫu để dùng lại.
2. **Làm sạch tự động** (hàm `import_normalize`):
   - `normalize(text, NFC)`, trim, gộp khoảng trắng.
   - Đơn vị: bảng quy đổi biến thể → `uoms.code` (`KG|Kg|kg` → `kg`; `CÁI|Cái|cái` → `cai`; `lit|lít|L` → `l`; `HỦ|hủ` → `hu`; …). Biến thể lạ → lỗi "đơn vị chưa có".
   - Phân loại CCDC: cột "Loại" = `CCDC` → `item_groups.kind = 'ccdc'`.
3. **Xem trước lỗi & cảnh báo** — bảng có lọc:
   - `DUP_CODE` một mã nhiều tên → bắt buộc người dùng chọn: tách mã mới / gộp.
   - `NEAR_DUP_NAME` tên gần trùng (pg_trgm similarity > 0,8) → gợi ý gộp.
   - `NO_CODE` → sinh mã theo quy tắc nhóm (vd. `TP-THIT-0001`).
   - `NO_FACTOR` thiếu hệ số quy đổi → bắt buộc nhập (không cho bỏ qua với nhóm food/beverage).
   - `UNKNOWN_UOM`, `UNKNOWN_GROUP`.
4. **Xác nhận** → ghi vào bảng thật trong 1 transaction; xuất báo cáo kết quả (Excel).

## 3. Định lượng buffet → công thức theo mẻ

- Mỗi món buffet → `recipes.kind = 'buffet_batch'`. Bếp trưởng phải điền `portions_per_batch` (một khay phục vụ khoảng bao nhiêu khách) — trường bắt buộc trước khi kích hoạt.
- Dòng có số lượng đúng bằng quy cách đóng gói (1.000 g, 1 lon 450 g…) → cờ "kiểm tra lại: có phải 1 khay dùng nguyên gói?".
- Nguyên liệu không khớp danh mục → màn hình ghép tay (gợi ý theo pg_trgm).

## 4. Tồn đầu kỳ

- Không lấy từ Excel. Ngày chuyển đổi: kiểm kê toàn bộ bằng app (`stock_counts.kind = 'monthly_full'`), post dạng `opening` với đơn giá = giá nhập gần nhất do kế toán cung cấp.
- Minibar: kiểm từng phòng → `opening` vào kho `minibar_room`.

## 5. Mẫu file chuẩn (agent tạo trong `public/templates/`)

| File | Cột |
|---|---|
| `mau_vat_tu.xlsx` | ma, ten, ten_en, nhom, dvt_kho, dvt_mua, he_so_mua_kho, dvt_cong_thuc, he_so_kho_cong_thuc, key_item, han_dung_ngay, vat, ma_cu |
| `mau_ncc.xlsx` | ma, ten, mst, loai, dien_thoai, dia_chi, han_thanh_toan_ngay, ngan_hang, so_tk, chu_tk |
| `mau_gia_tran.xlsx` | ma_vat_tu, dvt, gia_tran, tu_ngay, den_ngay, khach_san |
| `mau_ton_dau.xlsx` | kho, ma_vat_tu, so_luong, dvt, don_gia, lo, han_dung |
| `mau_pms_ngay.xlsx` | ngay, phong_ban, so_khach, khach_an_sang, giuong_phu, so_phong_tra |
| `mau_pos_ca.xlsx` | ngay, ca, ma_mon, ten_mon, so_luong, thanh_tien, huy, huy_sau_in_bill, mien_phi, nguoi_duyet_mien |

POS không có API: cần xin khách **mẫu báo cáo bán hàng theo món** xuất từ POS thật để tạo `import_mappings` (ghi vào `OPEN-QUESTIONS.md`).
