# Dữ liệu mẫu thật — Seed cho ERP_hotel (workstream 8, 10/11/2026)

File seed: [`seed-sample-data.sql`](./seed-sample-data.sql) — chạy **1 lần** bằng
Supabase Dashboard → SQL Editor (role postgres). **Không phải migration** (không có
số version, `db push` không tự chạy). Hướng dẫn chạy + rollback xem cuối file SQL.

## 1. Kết quả seed (tóm tắt)

| Bảng đích | Số dòng seed | Nguồn |
|---|---|---|
| `public.uoms` (chỉ chèn mã thiếu) | 33 mã (11 gốc + 22 của T-014) | ĐVT trong 4 file |
| `public.item_groups` | 7 nhóm (6 đã có + `KHAC` mới) | Nhóm TP/CCDC/MB/AMN/CPM + Nhiên Liệu |
| `public.items` | **668** (NVL buffet 649 + minibar 7 + amenities 12) | §2 |
| `public.minibar_price_list` | 7 (giá lịch sử 10/2018–11/2019) | §4 |
| `public.room_setup_standards` | 12 × số loại phòng hiện có (`checkout`) | §5 |
| `public.trolley_par_levels` | 12 × số xe đẩy hiện có | §5 |
| `public.stock_moves` / `stock_balances` / `item_costs` | **0 — cố ý không ghi** | §6 |

Mặc định seed cho **SONHOIAN** (org `00dc6aeb-5e34-4e01-9b80-032a72b16d71`,
property `7e37858d-58ed-4924-bb8f-9d56be9c620b`). Đổi 2 giá trị ở §0 trong file SQL
nếu chạy cho khách sạn khác.

## 2. Đối chiếu file → sheet → bảng

### 2.1 `Lst_2020_DL_Buffet.xlsx` (1.716.072 byte)

| Sheet | Dòng dữ liệu | Dùng làm gì | Bảng đích / số dòng |
|---|---|---|---|
| `NVL` | 662 | Danh mục vật tư chính | `items` — **649 dòng** (13 dòng bỏ qua, xem §3) |
| `Menu` | 75 món (`Bu_1`–`Bu_75`, mã + tên duy nhất) | Menu buffet — **chỉ tham khảo** | Không seed (chưa có bảng `recipes`, xem §7) |
| `Bản sao của Menu` | 75 món, giống hệt `Menu` | Bản sao | Không seed |
| `02 DL góc` | 358 dòng định lượng (73 món + 1 dòng `#N/A`) | Định lượng theo khay — **chỉ tham khảo** | Không seed (chờ bảng `recipe_lines`, Q158) |
| `Sổ dl buffet` | 359 dòng (gồm 1 dòng tiêu đề) | Định lượng (bản ghi theo tên, không mã NVL) | Không seed; 6 tên nguyên liệu không khớp danh mục NVL (xem §3.4) |
| `Order NVL` | 140 dòng | Tính order theo công thức sai (cộng mọi món × số khách) | **Không nhập** (theo docs/07 §1) |
| `02 Định lượng` | 564 dòng | Thẻ giá set menu Kosher (FOAL, food cost 967,2%) | **Không nhập** (đơn giá sai đơn vị, theo docs/07 §1) |
| `02 Menu không Salad` | 28 dòng (text) | Thực đơn Âu 4 | Tham khảo, không seed |
| `02 Cách làm menu` | 22 dòng (text) | Cách làm | Tham khảo, không seed |
| `03 dị ứng_01 menu Lactose` | 24 dòng (text) | Thực đơn Âu 1 (lactose) | Tham khảo, không seed |
| `03 cách làm` | 24 dòng (text) | Cách làm | Tham khảo, không seed |
| `Recipe` | 12 dòng (toàn tiêu đề) | Mẫu công thức trống, **không có dữ liệu** | Không seed |

### 2.2 `Lst_Alacarte_foodcost.xlsx` (320.535 byte)

| Sheet | Dòng dữ liệu | Dùng làm gì | Bảng đích / số dòng |
|---|---|---|---|
| `NVL` | 661 | Bản danh mục thứ hai — **trùng bản buffet** (chỉ lệch 1 dòng `NVL0626`, xem §3.3) | Không seed thêm (đã có từ buffet) |
| `Foodcost` | 53 dòng / 6 món | Định lượng alacarte — **chỉ tham khảo** | Không seed (chờ bảng `recipe_lines`, Q158); 4 dòng thiếu số lượng |
| `02 Định lượng` | 13 dòng (tiêu đề thẻ giá) | Thẻ giá Kosher (FOAL, vốn 0%) | Không seed |

6 món alacarte: Rau muống trộn tôm thịt, Tôm Chiên Giòn, Bánh mì nhồi thịt bò nướng,
Cà tím tay cầm, Súp Hải Sản Tóc Tiên, Sườn heo xào chua ngọt.

### 2.3 `Nha__p_Xua__t_Minibar.xlsx` (156.029 byte, 14 sheet tháng 10.2018–11.2019)

| Nội dung | Số liệu | Bảng đích |
|---|---|---|
| 6 món (Larue, Tiger, Coca-Cola, Diet Coke, Lavie, Sprite) + Rượu vang (từ 5.2019, chỉ có cột SL Bán) | 91 ô tháng-món | `items` — **7 dòng** (nhóm `MB`, mã `MB-*`) |
| Doanh thu tháng / số lượng bán tháng → đơn giá | 83 ô có doanh thu | `minibar_price_list` — **7 dòng** (giá modal, xem §4) |
| Nhập/xuất/tồn từng ngày | 425 ngày-món | **Không seed** — chỉ đối chiếu ở §4 (tồn đầu kỳ lấy bằng kiểm đếm, §6) |

### 2.4 `tha_ng_5_..._Amenities_....xlsx` (71.357 byte, tháng 5/2019)

| Sheet | Dòng | Dùng làm gì | Bảng đích |
|---|---|---|---|
| `1.5-8.5` | 12 món (tổng hợp 8 ngày, 314 phòng) | Tồn đầu tháng + dùng 8 ngày đầu | Tham khảo (§5) |
| `9.5.2019`–`31.5.2019` | 12 món × 23 ngày | Dùng/xuất/tồn từng ngày | `trolley_par_levels` (par = xuất max 1 ngày) |
| `SL sử dụng trong tháng 5.2019` | 12 món (tổng tháng, 1.175 phòng) | Tổng dùng tháng → định mức/phòng-đêm | `room_setup_standards` (12 dòng / loại phòng) |
| 12 món amenities | — | Danh mục | `items` — **12 dòng** (nhóm `AMN`, riêng Nước dasani nhóm `CPM`) |

Kiểm chứng: tổng "dùng" 1.5–8.5 + tổng "dùng" 9.5–31.5 = tổng tháng trong sheet
tổng hợp — **khớp cả 12/12 món**.

## 3. Dòng bỏ qua + quy tắc ánh xạ

### 3.1 Dòng NVL bị bỏ qua (13/662)

| Nguồn | Tên | Mã | Lý do bỏ qua |
| --- | --- | --- | --- |
| Buffet NVL | Gừng Nhỏ | NVL0206 | Trùng mã với mặt hàng khác ('GỪNG LỚN') — giữ dòng STT 119 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | dầu oliu extra (cooking) | NVL0111 | Trùng mã với mặt hàng khác ('dầu oliu virgin (salad)') — giữ dòng STT 288 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | Cồn thạch | NVL0633 | Thiếu ĐVT kho (ĐVT trống) — không seed được (items.stock_uom NOT NULL). ĐVT qui đổi và hệ số đều trống trong file |
| Buffet NVL | Củ Cải Trắng | NVL0535 | Trùng mã với mặt hàng khác ('củ cải') — giữ dòng STT 75 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | ruốc khô | — | Thiếu ĐVT kho (ĐVT trống) — không seed được (items.stock_uom NOT NULL). ĐVT qui đổi ghi trong file: 'gr', hệ số trống |
| Buffet NVL | CHUỐI | NVL0284 | Trùng mã với mặt hàng khác ('chuối cau (bếp)') — giữ dòng STT 70 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | Ớt hiểm | NVL0221 | Trùng mã với mặt hàng khác ('ớt hiểm nhỏ') — giữ dòng STT 193 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | Thịt Nạc Vai heo loại 1 - Vietgap mã 238964 | NVL0091 | Trùng mã với mặt hàng khác ('Thịt Nạc Vai heo') — giữ dòng STT 241 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | xương | NVL0274 | Trùng mã với mặt hàng khác ('xương cốt lết') — giữ dòng STT 272 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | Cua hộp 450gr | NVL0029 | Trùng mã với mặt hàng khác ('Cua nguyên con') — giữ dòng STT 78 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | chocolate Croisant sống | NVL0126 | Trùng mã với mặt hàng khác ('chocolate Croisant') — giữ dòng STT 68 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | Croisant sống | NVL0130 | Trùng mã với mặt hàng khác ('Croisant') — giữ dòng STT 73 trước, dòng này cần cấp mã mới (xem §3.1) |
| Buffet NVL | Bao ni long trắng (có quai) | BP-PA002 | Trùng mã với mặt hàng khác ('Bao ni long trắng') — giữ dòng STT 381 trước, dòng này cần cấp mã mới (xem §3.1) |

Ghi chú:

- **11 mã trùng 2 mặt hàng** (giữ dòng có STT nhỏ hơn, tức dòng xuất hiện trước
  trong file): `NVL0029` (Cua nguyên con / Cua hộp 450gr), `NVL0091`,
  `NVL0111` (dầu oliu virgin / extra), `NVL0126`, `NVL0130`, `NVL0206`
  (Gừng lớn / Gừng nhỏ), `NVL0221`, `NVL0274`, `NVL0284` (chuối cau / CHUỐI),
  `NVL0535`, `BP-PA002`. Dòng bị bỏ cần cấp mã mới trước khi nhập (Q158).
- **2 dòng thiếu ĐVT kho** nên không seed được (`stock_uom` NOT NULL):
  `NVL0633` Cồn thạch và `ruốc khô` (dòng này cũng không có mã).
- **332/662 dòng không có mã** (50,2%) — được cấp mã sinh `SEED-<nhóm>-NNNN`
  (vd. `SEED-TP-0001`), ghi rõ trong `items.external_codes.code_gen`. Mã sinh
  cố ý khác mẫu `TP-0001` của luồng import T-014 để không đụng bộ đếm
  `item_code_sequences`. Đổi mã sau được qua màn master-data.
- **275 dòng không có STT** (dòng thêm cuối sheet: món tráng miệng, món làm sẵn,
  CCDC bổ sung) — giữ nguyên thứ tự file, STT ghi trong `external_codes` khi có.
- Tên trùng nhau sau chuẩn hóa (không dấu/hoa-thường): **0 dòng**.
- Tên/mã trong file giữ nguyên văn (kể cả `NVL 0610` có khoảng trắng và
  `HH0-95` có thể là lỗi gõ của `HH-095`) — không tự sửa dữ liệu gốc.

### 3.2 Ánh xạ cột NVL → `items`

| Cột Excel | Cột `items` | Quy tắc |
|---|---|---|
| Mã nvl2 | `code` | Giữ nguyên; trống → mã sinh `SEED-<nhóm>-NNNN` |
| Sản phẩm | `name` | Giữ nguyên văn (trim) |
| Loại | `group_id` | `CCDC` → nhóm `CCDC`; `Nhiên Liệu` → nhóm mới `KHAC` (kind `other`); còn lại → `TP` (food). Loại trống → `TP` (1 dòng: Mì trứng) |
| ĐVT | `stock_uom` | Chuẩn hóa về `uoms.code` (vd. `KG/Kg/kg` → `kg`, `gr` → `g`, `pcs` → `cai`, `lít` → `l`, `xắp` → `xap`, `Quả` → `trai`). Cả 33 mã đều đã có từ migration T-010/T-014 |
| Hệ Số Qui Đổi + ĐVT Qui Đổi | `stock_to_recipe` + `recipe_uom` | 1 ĐVT kho = hệ số ĐVT công thức (vd. 1 kg = 1.000 g). **279/649 dòng seed thiếu hệ số** (trong đó 248 dòng có ĐVT qui đổi nhưng không có hệ số) → `stock_to_recipe` NULL, `recipe_uom` giữ nguyên khi có |
| Nhóm CP `1 nvl_Chính` | `is_key_item` | `true` cho 84 dòng; còn lại `false` |
| — | `external_codes` | JSON gọn: `f` (file nguồn), `stt`, `loai`, `cp` (Nhóm CP), `code_gen` |

Cột `dl sử dụng` / `dl order` (số lượng order của 1 sự kiện cụ thể) **không seed**
— không phải dữ liệu master. Cột `Mã Bravo` / `Nhóm Bravo` không có trong sheet
NVL nên `legacy_code` để NULL (nhóm Bravo của món ăn nằm ở sheet `Menu`).

### 3.3 Lệch giữa 2 bản NVL (buffet vs alacarte)

Chỉ **1 dòng** lệch — lấy bản buffet (file `Lst_2020`, mới hơn) làm chuẩn:

| Mã | Buffet | Alacarte |
|---|---|---|
| `NVL0626` Đậu gà trắng (Chickpeas) | ĐVT `lon`, hệ số 400, Nhóm CP `2 nvl_phụ` | ĐVT `kg`, hệ số 1000, Nhóm CP `phụ` |

Bản alacarte thiếu 1 dòng so với buffet: `Mì trứng` (không mã, không Loại).

### 3.4 Tên nguyên liệu trong định lượng không khớp danh mục NVL

- `Sổ dl buffet`: 6 tên — `NƯỚC MẮM NAM NGƯ 750ML`, `Nạc heo xay`, `Trái dưa hấu`,
  `Trái thơm`, `emmental cheese`, `đùi gà góc tư` (cần ghép tay khi nhập công thức).
- `02 DL góc`: 9/358 dòng **thiếu Mã NVL** (trong đó 1 dòng món `#N/A` — bake bean);
  139 mã NVL còn lại đều có trong danh mục. 0 dòng thiếu số lượng.
- `Foodcost` alacarte: 4/53 dòng **thiếu số lượng** (đều món Tôm Chiên Giòn:
  bột bắp_năng, bột Mì, Tương Ớt sài gòn (2lit), mayonnaise); 52/53 dòng thiếu
  Mã Bravo (cột trống toàn bộ); 2 tên không khớp NVL: `Trái thơm`, `Tóc Tiên`.

## 4. Minibar — số liệu đối chiếu

### 4.1 Tồn cuối tháng (SL TỒN ngày cuối tháng; "—" = không có số liệu)

| Tháng | Larue | Tiger | Coca-Cola | Diet Coke | Lavie | Sprite | Rượu vang |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 10.2018 | 26 | 21 | 32 | 18 | 463 | 25 | — |
| 11.2018 | 10 | 14 | 27 | 33 | 311 | 17 | — |
| 12.2018 | 12 | 15 | 10 | 30 | 152 | 33 | — |
| 1.1.2019 | 60 | 53 | 66 | 40 | 57 | 31 | — |
| 2.2019 | 34 | 16 | 27 | 31 | 21 | 13 | — |
| 3.2019 | 34 | 34 | 11 | 18 | 12 | 29 | — |
| 4.2019 | 32 | 28 | 14 | 27 | 25 | 25 | — |
| 5.2019 | 4 | 1 | 16 | 12 | 26 | 2 | bán 7 |
| 6.2019 | 24 | 20 | 12 | 21 | 34 | 17 | bán 4 |
| 7.2019 | 4 | 10 | 22 | 19 | 3 | 8 | bán 7 |
| 8.2019 | 20 | 22 | 35 | 28 | 20 | 30 | bán 6 |
| 9.2019 | 18 | 11 | 22 | 24 | 20 | 22 | bán 5 |
| 10.2019 | 23 | 16 | 14 | 51 | 36 | 31 | bán 5 |
| 11.2019 | 24 | 18 | 13 | 22 | 17 | 18 | — |

### 4.2 Tổng 14 tháng

| Món | Σ Nhập (14 tháng) | Σ Xuất (14 tháng) | Σ Bán (footer) | Σ Doanh thu (footer, đ) | Tồn cuối 30/11/2019 |
| --- | --- | --- | --- | --- | --- |
| Larue | 840 | 828 | 828 | 20.700.000 | 24 |
| Tiger | 840 | 819 | 819 | 28.630.000 | 18 |
| Coca-Cola | 695 | 665 | 665 | 16.600.000 | 13 |
| Diet Coke | 528 | 411 | 411 | 10.200.000 | 22 |
| Lavie | 1584 | 2067 | 2067 | 30.870.000 | 17 |
| Sprite | 480 | 497 | 497 | 12.375.000 | 18 |
| RƯỢU VANG | 0 | 34 | 34 | 8.330.000 | — |

Kiểm chứng: **Σ XUẤT từng ngày = số lượng bán ở footer trong cả 84/84 ô tháng-món**
(6 món × 14 tháng). Rượu vang chỉ có cột SL Bán (không có nhập/xuất/tồn).

### 4.3 Giá bán (đơn giá suy ra = doanh thu tháng / số lượng bán tháng)

Giá seed là giá trị **thường gặp nhất (modal)** trong 14 tháng:
Larue **25.000**, Tiger **35.000**, Coca-Cola **25.000**, Diet Coke **25.000**,
Lavie **15.000**, Sprite **25.000**, Rượu vang **245.000** đ.
9/83 ô tháng-món lệch khỏi giá modal (doanh thu ghi thấp hơn SL × giá modal —
có thể là tặng/khuyến mãi hoặc ghi sai, **không tự hiệu chỉnh**):

| Tháng | Món | SL bán | Doanh thu (đ) | Đơn giá suy ra (đ) | Giá modal (đ) |
| --- | --- | --- | --- | --- | --- |
| 11.2018 | Diet Coke | 30 | 725.000 | 24.167 | 25,000 |
| 11.2018 | Sprite | 30 | 725.000 | 24.167 | 25,000 |
| 1.1.2019 | Coca-Cola | 41 | 1.000.000 | 24.390 | 25,000 |
| 1.1.2019 | Diet Coke | 28 | 675.000 | 24.107 | 25,000 |
| 1.1.2019 | Lavie | 116 | 1.695.000 | 14.612 | 15,000 |
| 1.1.2019 | Sprite | 24 | 575.000 | 23.958 | 25,000 |
| 7.2019 | Tiger | 71 | 2.450.000 | 34.507 | 35,000 |
| 7.2019 | Diet Coke | 46 | 1.125.000 | 24.457 | 25,000 |
| 7.2019 | Lavie | 242 | 3.540.000 | 14.628 | 15,000 |

Giá seed chỉ có hiệu lực 01/10/2018–30/11/2019 nên **không áp cho phiếu kiểm
2026** — giá bán hiện hành phải nhập qua `minibar_price_set` (Q47).

### 4.4 Vấn đề chất lượng số liệu minibar (ghi nhận, không sửa)

- **Tồn đầu tháng sau ≠ tồn cuối tháng trước trong 59/78 lần chuyển tháng**
  (vd. Larue: tồn 31/10/2018 = 26 nhưng đầu 01/11/2018 ghi 22). Trong tháng thì
  khớp (ĐẦU KÌ ngày N = SL TỒN ngày N−1, 0 lần lệch). Tháng sau có thể đã kiểm
  đếm lại hoặc ghi đè — đúng như docs/07 §1 ghi "Tồn âm, ghi đè".
- **Tồn âm 2 lần**: Coca-Cola −2 ngày 07/10/2018, −1 ngày 28/05/2019.
- Sheet `3.2019` ngày 31/03 thiếu số liệu 1 phần (Tiger/Diet Coke/Lavie thiếu
  ĐẦU KÌ; Sprite trống cả dòng) — tồn cuối tháng lấy theo ngày có số liệu gần nhất.
- Sheet `4.2019` lẫn 1 dòng ngày 01/05/2019 (đã loại khi tổng hợp theo tháng).
- Sheet `2.2019` có 3 dòng trống cuối sheet lặp lại số tồn cuối (đã loại).
- Sheet `1.1.2019` là tháng 1/2019 (tên sheet ghi thừa ".1").
- Lavie: tồn đầu 615 chai (01/10/2018), không nhập thêm trong 10–12/2018.
- ĐVT minibar (lon/chai) **không có trong file** — suy ra từ loại hàng
  (bia/nước ngọt lon, nước/vang chai), ghi trong `external_codes.note`.

## 5. Amenities tháng 5/2019 — định mức + par

Tổng công suất tháng 5/2019: **1.175 phòng** (+ 51 triple + 26 extra bed ≈ 38,5
phòng tương đương = 1.213,5 — sheet tổng hợp ghi chú; định mức dưới đây chia
cho 1.175 phòng như M07 §4).

| Món | ĐVT | Tồn 30/04 | Nhận T5 | Dùng T5 | Dùng/phòng-đêm | Xuất max 1 ngày (par) | Dùng max 1 ngày | Tồn 31/05 | Mã seed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Giấy vệ sinh | cuộn | 142 | 800 | 843 | 0.7174 | 62 | 42 | 99 | AMN-GIAY-VS |
| Trà cozy | gói | 117 | 550 | 572 | 0.4868 | 100 | 39 | 95 | AMN-TRA-COZY |
| Đường thẻ | pcs | 57 | 500 | 459 | 0.3906 | 100 | 42 | 98 | AMN-DUONG |
| Cà phê | gói | 118 | 864 | 909 | 0.7736 | 100 | 71 | 73 | AMN-CAPHE |
| Xà phòng cục | pcs | 87 | 445 | 441 | 0.3753 | 60 | 27 | 91 | AMN-XAPHONG |
| Bàn chải | pcs | 136 | 1020 | 1042 | 0.8868 | 110 | 69 | 114 | AMN-BANCHAI |
| Dao cạo râu | pcs | 164 | 0 | 23 | 0.0196 | 6 | 2 | 141 | AMN-DAO |
| Túi vệ sinh | pcs | 235 | 250 | 332 | 0.2826 | 60 | 22 | 153 | AMN-TUIVS |
| Lược | pcs | 128 | 309 | 375 | 0.3191 | 60 | 35 | 62 | AMN-LUOC |
| Bông quáy tai | pcs | 126 | 400 | 475 | 0.4043 | 60 | 36 | 51 | AMN-BONG |
| Chụp tóc | pcs | 72 | 269 | 270 | 0.2298 | 60 | 18 | 71 | AMN-CHUPTOC |
| Nước dasani | chai | 155 | 2136 | 2279 | 1.9396 | 125 | 119 | 12 | CPM-DASANI |

- `room_setup_standards`: qty = Dùng T5 / 1.175, chỉ `clean_type='checkout'`,
  `per_guest=false` (file không tách theo loại dọn phòng hay theo khách).
  4 giá trị khớp M07 §4: bàn chải 0,89; giấy vệ sinh 0,72; nước 1,94; cà phê 0,77.
- `trolley_par_levels`: par = lượng **Xuất lên xe lớn nhất 1 ngày**
  (sheet 9.5–31.5). Dao cạo râu par = 6 (ít dùng: 23 cái/tháng).
- Cả 2 giá trị đều là **định mức tham khảo**, cần buồng phòng xác nhận/điều chỉnh
  theo từng loại phòng (Q159). `stayover`/`vip`/`child` chưa có số liệu → không seed.
- `Nước dasani` vào nhóm `CPM` (complimentary) — theo quyết định T-035:
  Dasani cấp phòng đi qua trolley/room setup, **không** qua `minibar_refill`.

## 6. Tồn đầu kỳ — KHÔNG seed từ Excel (cố ý)

Theo docs/07 §4, tồn đầu kỳ **không lấy từ Excel**: ngày chuyển đổi kiểm kê
toàn bộ bằng app (`stock_counts.kind = 'monthly_full'`, post dạng `opening`),
minibar kiểm từng phòng → `opening` vào kho `minibar_room`. Vì vậy file seed
**không ghi 1 dòng nào** vào `stock_moves` / `stock_balances` / `item_costs`
(truy vấn §7.7 kiểm chứng = 0), và không bịa chứng từ nhập/xuất.

Số tồn cuối kỳ ghi nhận lần cuối (30/11/2019) chỉ để tham khảo khi kiểm đếm:
Larue 24, Tiger 18, Coca-Cola 13, Diet Coke 22, Lavie 17, Sprite 18
(Rượu vang không có số tồn). Tồn cuối tháng 5/2019 của amenities xem bảng §5.
Các số này đã **7 năm tuổi** — tuyệt đối không dùng làm tồn đầu kỳ (Q157).

## 7. Công thức / menu — KHÔNG seed (chưa có bảng)

**Kết quả kiểm tra: KHÔNG tồn tại bảng công thức nào trong repo.**
`docs/03-DATA-MODEL.md` A7 đã vẽ `recipes` / `recipe_versions` / `recipe_lines` /
`pos_item_map` (P2 — "tạo bảng sớm") nhưng **chưa có migration nào tạo các bảng này**
(đã rà toàn bộ `supabase/migrations/`). Migration T-014 cũng ghi rõ
"recipes là P2, cần portions_per_batch".

Vì vậy file seed **chỉ seed `items`**; dữ liệu món ăn/định lượng dưới đây mới ở
mức tham khảo trong README, chờ task tạo bảng + RPC rồi nhập (Q158):

| Nguồn | Số liệu |
|---|---|
| Buffet `Menu`: 75 món (`Bu_1`–`Bu_75`), nhóm Bravo: hot 27, salad 13, dessert 9, bread 8, cold cut 8, noodle 4, cereal 3, egg 3 | Chờ `recipes.kind='buffet_batch'` + `portions_per_batch` (bếp trưởng điền) |
| Buffet `02 DL góc`: 358 dòng định lượng, 139 mã NVL | Chờ `recipe_lines` |
| Buffet `Sổ dl buffet`: 358 dòng định lượng (bản theo tên) | Chờ `recipe_lines` |
| Alacarte `Foodcost`: 53 dòng / 6 món | Chờ `recipe_lines` |
| Set menu / dị ứng (`02 Menu không Salad`, `03 dị ứng_01 menu Lactose`) | Chờ `recipes.kind='set_menu'` + `diet_flags` |

## 8. Cách chạy + kiểm tra

1. Mở Supabase Dashboard → SQL Editor, chạy toàn bộ
   `docs/sample-data/seed-sample-data.sql` **1 lần**.
2. Nếu SQL Editor báo lỗi vì file dài (~118 KB): chạy từng khối theo thứ tự
   §0 → §1 → §2 → §3a → §3b → §3c → §3d → §3e → §4 → §5 → §6 **trong cùng 1 tab**
   (khối §0 lưu `seed.org_id` / `seed.property_id` theo session; khối lớn nhất
   §3a ≈ 41 KB). Mỗi khối đều idempotent — chạy lại không nhân đôi.
3. Chạy các truy vấn §7 cuối file. Số kỳ vọng:
   - §7.1 items theo nhóm: TP 409, CCDC 235, MB 7, AMN 11, CPM 1, KHAC 5 (tổng 668).
   - §7.2 items do seed tạo: 668. §7.3 giá minibar: 7 dòng.
   - §7.4 chuẩn setup: 12 dòng / 1 loại phòng (0 dòng = property chưa có `room_types`).
   - §7.5 par xe đẩy: 12 dòng / 1 xe (0 dòng = chưa có kho `trolley`).
   - §7.7 `stock_moves` của items seed: **0**.
4. Rollback: khối chú thích cuối file SQL (xóa theo thứ tự ngược; `audit_log`
   giữ lại dấu vết INSERT theo thiết kế sổ cái bất biến).

## 9. Câu hỏi mở

- **Q157** — Tồn đầu kỳ nhập bằng luồng nào (kiểm đếm ngày chuyển đổi theo
  docs/07 §4), và số tồn cuối 11/2019 có dùng để đối chiếu khi kiểm đếm không?
- **Q158** — Tạo bảng công thức A7 (migration + RPC) rồi nhập 75 món buffet +
  358 dòng định lượng + 53 dòng alacarte khi nào? 11 mã trùng (vd. `NVL0029`)
  cấp mã mới cho mặt hàng thứ hai bằng cách nào?
- **Q159** — Định mức setup phòng (checkout, theo phòng) + par xe đẩy seed ở
  mức tham khảo tháng 5/2019 — buồng phòng xác nhận/điều chỉnh theo từng loại
  phòng không? Có bổ sung chuẩn `stayover`/`vip`/`child` và tách theo khách
  (`per_guest`) không? (Xem `docs/OPEN-QUESTIONS.md`.)
