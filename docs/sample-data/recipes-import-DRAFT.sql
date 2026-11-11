-- ============================================================================
-- NHÁP IMPORT CÔNG THỨC MÓN ĂN — BẢN NHÁP, KHÔNG PHẢI MIGRATION, CHƯA CHẠY
-- ============================================================================
-- Nguồn: Lst_2020_DL_Buffet.xlsx (sheet Menu 75 món + sheet 02 DL góc
--   358 dòng định lượng) và Lst_Alacarte_foodcost.xlsx (sheet Foodcost
--   52 dòng / 6 món — README §2.2 ghi 53, lệch 1). Đọc bằng openpyxl ngày 10/11/2026.
-- Đích: bảng recipes / recipe_versions / recipe_lines (migration 500000).
--
-- QUY TẮC BẮT BUỘC TRƯỚC KHI CHẠY:
--   1. Duy chốt Q168: nhập công thức từ Excel (file này) hay nhập tay.
--   2. Chạy SAU docs/sample-data/seed-sample-data.sql (cần items đã seed).
--   3. Chạy 1 lần; mọi câu đều idempotent (ON CONFLICT / NOT EXISTS).
--   4. Mọi dòng [CẦN XÁC NHẬN] ở cuối file (§6) phải được bếp trưởng /
--      Duy xử lý TRƯỚC khi chạy (ghép tay tên, cấp mã NVL mới, điền
--      portions_per_batch, chốt ĐVT). KHÔNG tự ý bỏ qua rồi chạy.
--   5. File này KHÔNG chạy qua db push (không phải migration). Chạy tay
--      từng khối qua SQL Editor như seed (khối lớn nhất nên tách nếu
--      vượt ~54KB của SQL Editor).
--
-- Số liệu trong file: 75 món buffet + 6 món alacarte;
--   định lượng buffet 348/358 dòng nhập được, 10 dòng [CẦN XÁC NHẬN];
--   định lượng alacarte 44/52 dòng nhập được, 8 dòng [CẦN XÁC NHẬN].
--   LƯU Ý SỐ LIỆU: file Foodcost thực tế có 52 dòng dữ liệu (README §2.2 ghi 53 — lệch 1, [CẦN XÁC NHẬN]);
--   cột ĐVT thực tế / SL thực tế của sheet 02 DL góc KHÔNG nhất quán
--   với ĐVT / SL (316/348 dòng nhập được có ĐVT thực tế
--   khác ĐVT trong khi SL thực tế = SL — vd. 500 gr nhưng ghi 500 kg.
--   File này dùng SL + ĐVT; cần bếp trưởng đối chiếu trước khi chạy.
--   portions_per_batch + yield_qty + sale_price để NULL [CẦN XÁC NHẬN:
--   bếp trưởng điền trước khi dùng foodcost/bán món].
-- ============================================================================

-- §0. BIẾN — giống seed-sample-data.sql §0 (mặc định: SONHOIAN)
select set_config('seed.org_id', '00dc6aeb-5e34-4e01-9b80-032a72b16d71', false);
select set_config('seed.property_id', '7e37858d-58ed-4924-bb8f-9d56be9c620b', false);

-- ============================================================================
-- §1. CÔNG THỨC BUFFET — 75 món (kind='buffet_batch')
-- ============================================================================
do $recipes$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
begin
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_1', 'bánh mì baguette', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_2', 'croissant', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_3', 'ba chỉ xông khói(bacon)', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_4', 'Bánh bèo sốt tôm', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_5', 'bánh crepe', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_6', 'Bánh da lợn', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_7', 'Bánh khoai 2 màu', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_8', 'bánh khoai nhừ nướng', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_9', 'bánh khoai nhừ nướng với bí đỏ', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_10', 'Bánh mì gối đen', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_11', 'Bánh mì gối sandwich', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_12', 'Bánh mì Hội An', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_13', 'Bánh mì nướng trứng cút', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_14', 'Bánh su xê', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_15', 'Beetroot salad', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_16', 'Blanch veggie salad', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_17', 'bò ca ry', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_18', 'Bò kho', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_19', 'Bơ vĩ Anchor', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_20', 'Bông cải xào nấm', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_21', 'bún gạo xào', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_22', 'Cà chua đốt lò', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_23', 'Cà chua nhồi xúc xích đốt lò', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_24', 'Cà chua nướng trứng cút', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_25', 'cá cơm kho tiêu', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_26', 'cammembert cheese', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_27', 'Cao Lầu', 'buffet_batch', 'noodle',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_28', 'caramel creme', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_29', 'Chả trứng gà', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_30', 'Cháo trắng', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_31', 'cheddale cheese', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_32', 'chicken sassage(xx gà)', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_33', 'Chocolate croisant', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_34', 'Cocopops', 'buffet_batch', 'cereal',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_35', 'Cơm chiên dương châu', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_36', 'Cơm chiên ức gà xíu', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_37', 'condiment', 'buffet_batch', 'egg',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_38', 'corn plake', 'buffet_batch', 'cereal',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_39', 'Đậu tây xào bơ tỏi', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_40', 'Đậu trắng sốt cà', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_41', 'Dưa hấu', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_42', 'egg salad', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_43', 'emmental cheese', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_44', 'Farfalle salad', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_45', 'Ham', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_46', 'heo xíu mại sốt cà', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_47', 'Hollandaise sauce', 'buffet_batch', 'egg',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_48', 'khoai tây đút lò', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_49', 'Mixed salad', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_50', 'Mứt bưởi', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_51', 'mứt cam', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_52', 'mứt dâu', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_53', 'Mỳ quãng tôm thịt', 'buffet_batch', 'noodle',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_54', 'Phở Hội An', 'buffet_batch', 'noodle',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_55', 'pineaple cook fruit', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_56', 'Pork sassage (xx heo)', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_57', 'Rainbow salad', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_58', 'raisin nho', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_59', 'raisin quế', 'buffet_batch', 'bread',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_60', 'Rau thập cẩm xào nấm', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_61', 'rau xào nấm', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_62', 'smoke beef salami(xx tỏi)', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_63', 'Sữa tươi', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_64', 'Thanh long', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_65', 'thịt dăm bông', 'buffet_batch', 'hot',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_66', 'trứng gà', 'buffet_batch', 'egg',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_67', 'xà lách cà bi', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_68', 'xà lách cà chua dưa leo', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_69', 'xà lách đậu đỏ với bắp hạt', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_70', 'Xà lách khoai tây', 'buffet_batch', 'salad',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_71', 'yaourt', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_72', 'yarout chanh dây', 'buffet_batch', 'dessert',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_73', 'Mỳ quảng gà', 'buffet_batch', 'noodle',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_74', 'Sữa đậu nành', 'buffet_batch', 'cold cut',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipes (org_id, code, name, kind, group_name, notes)
  values (v_org_id, 'Bu_75', 'Muesli', 'buffet_batch', 'cereal',
         'Nháp từ Menu buffet — portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  raise notice '§1 recipes buffet: % món', (select count(*) from public.recipes where org_id = v_org_id and kind = 'buffet_batch');
end;
$recipes$;

-- ============================================================================
-- §2. PHIÊN BẢN v1 — 75 món buffet (status='active')
-- ============================================================================
do $recipes$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
begin
  insert into public.recipe_versions (org_id, recipe_id, version_no, status)
  select v_org_id, r.id, 1, 'active'
  from public.recipes r
  where r.org_id = v_org_id and r.kind = 'buffet_batch'
    and not exists (select 1 from public.recipe_versions v
                    where v.recipe_id = r.id and v.version_no = 1);
  raise notice '§2 versions buffet: % phiên bản', (select count(*) from public.recipe_versions v join public.recipes r on r.id = v.recipe_id where r.org_id = v_org_id and r.kind = 'buffet_batch');
end;
$recipes$;

-- ============================================================================
-- §3. DÒNG ĐỊNH LƯỢNG BUFFET — dùng cột SL + ĐVT (xem ghi chú §6)
-- ============================================================================
do $recipes$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
begin
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'cai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0387'
  where r.org_id = v_org_id and r.code = 'Bu_1' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'cai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0130'
  where r.org_id = v_org_id and r.code = 'Bu_2' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0152'
  where r.org_id = v_org_id and r.code = 'Bu_3' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 30, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 6, 'con', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0096'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0195'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0538'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'cai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0561'
  where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0013'
  where r.org_id = v_org_id and r.code = 'Bu_5' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_5' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_5' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 600, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_5' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 6, 'trai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0284'
  where r.org_id = v_org_id and r.code = 'Bu_5' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 2, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_5' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_6' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0381'
  where r.org_id = v_org_id and r.code = 'Bu_6' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'cai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0559'
  where r.org_id = v_org_id and r.code = 'Bu_6' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0359'
  where r.org_id = v_org_id and r.code = 'Bu_6' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0053'
  where r.org_id = v_org_id and r.code = 'Bu_7' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0055'
  where r.org_id = v_org_id and r.code = 'Bu_7' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_7' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_7' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_7' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0209'
  where r.org_id = v_org_id and r.code = 'Bu_7' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0560'
  where r.org_id = v_org_id and r.code = 'Bu_7' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0053'
  where r.org_id = v_org_id and r.code = 'Bu_8' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0055'
  where r.org_id = v_org_id and r.code = 'Bu_8' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_8' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_8' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_8' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0560'
  where r.org_id = v_org_id and r.code = 'Bu_8' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0053'
  where r.org_id = v_org_id and r.code = 'Bu_9' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0055'
  where r.org_id = v_org_id and r.code = 'Bu_9' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.05, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_9' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_9' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_9' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_9' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0364'
  where r.org_id = v_org_id and r.code = 'Bu_9' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'o', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0129'
  where r.org_id = v_org_id and r.code = 'Bu_10' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'o', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0004'
  where r.org_id = v_org_id and r.code = 'Bu_11' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'o', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0125'
  where r.org_id = v_org_id and r.code = 'Bu_12' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0054'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 2, 'o', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0125'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0223'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 30, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0167'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0038'
  where r.org_id = v_org_id and r.code = 'Bu_13' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'cai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0554'
  where r.org_id = v_org_id and r.code = 'Bu_14' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_15' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_15' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_15' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0104'
  where r.org_id = v_org_id and r.code = 'Bu_15' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0190'
  where r.org_id = v_org_id and r.code = 'Bu_15' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0235'
  where r.org_id = v_org_id and r.code = 'Bu_15' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0378'
  where r.org_id = v_org_id and r.code = 'Bu_15' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0011'
  where r.org_id = v_org_id and r.code = 'Bu_16' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0012'
  where r.org_id = v_org_id and r.code = 'Bu_16' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_16' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_16' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_16' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0190'
  where r.org_id = v_org_id and r.code = 'Bu_16' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0363'
  where r.org_id = v_org_id and r.code = 'Bu_16' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 60, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0055'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0077'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0092'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 40, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0167'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0243'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0381'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 45, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0421'
  where r.org_id = v_org_id and r.code = 'Bu_17' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 60, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0077'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0092'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 40, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0167'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'hu', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0258'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 36, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0375'
  where r.org_id = v_org_id and r.code = 'Bu_18' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'vien', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0123'
  where r.org_id = v_org_id and r.code = 'Bu_19' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0011'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0012'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 180, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0066'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 180, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0067'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.060000000000000005, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_20' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0033'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0071'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0093'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 30, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 2, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0153'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0155'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0206'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0207'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0233'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0239'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 250, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0407'
  where r.org_id = v_org_id and r.code = 'Bu_21' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_22' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_22' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_22' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'mieng', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0024'
  where r.org_id = v_org_id and r.code = 'Bu_23' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_23' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_23' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_23' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0153'
  where r.org_id = v_org_id and r.code = 'Bu_23' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0155'
  where r.org_id = v_org_id and r.code = 'Bu_23' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 30, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_24' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_24' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0192'
  where r.org_id = v_org_id and r.code = 'Bu_24' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0213'
  where r.org_id = v_org_id and r.code = 'Bu_24' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0223'
  where r.org_id = v_org_id and r.code = 'Bu_24' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 80, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0233'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0237'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.5, 'hu', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0258'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 350, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0429'
  where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 125, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0180'
  where r.org_id = v_org_id and r.code = 'Bu_26' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 150, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0077'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0081'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0085'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 600, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0093'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0137'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0167'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0188'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0210'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0225'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0237'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0244'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 3, 'hu', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0258'
  where r.org_id = v_org_id and r.code = 'Bu_27' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_28' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_28' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 12, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_28' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0045'
  where r.org_id = v_org_id and r.code = 'Bu_30' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 250, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0563'
  where r.org_id = v_org_id and r.code = 'Bu_31' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0153'
  where r.org_id = v_org_id and r.code = 'Bu_32' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'cai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0126'
  where r.org_id = v_org_id and r.code = 'Bu_33' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0187'
  where r.org_id = v_org_id and r.code = 'Bu_34' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 120, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0093'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0118'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0272'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0436'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 3, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_35' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0077'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0102'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0137'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0225'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 2, 'hu', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0258'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0272'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 3, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_36' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0046'
  where r.org_id = v_org_id and r.code = 'Bu_37' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_37' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0067'
  where r.org_id = v_org_id and r.code = 'Bu_37' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0071'
  where r.org_id = v_org_id and r.code = 'Bu_37' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_37' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0152'
  where r.org_id = v_org_id and r.code = 'Bu_37' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_37' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0374'
  where r.org_id = v_org_id and r.code = 'Bu_38' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_39' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_39' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_39' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_39' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0507'
  where r.org_id = v_org_id and r.code = 'Bu_39' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0168'
  where r.org_id = v_org_id and r.code = 'Bu_40' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0044'
  where r.org_id = v_org_id and r.code = 'Bu_41' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0072'
  where r.org_id = v_org_id and r.code = 'Bu_41' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_42' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0058'
  where r.org_id = v_org_id and r.code = 'Bu_42' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_42' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0104'
  where r.org_id = v_org_id and r.code = 'Bu_42' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0105'
  where r.org_id = v_org_id and r.code = 'Bu_42' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0115'
  where r.org_id = v_org_id and r.code = 'Bu_42' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 2, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_42' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0010'
  where r.org_id = v_org_id and r.code = 'Bu_44' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0111'
  where r.org_id = v_org_id and r.code = 'Bu_44' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 90, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0163'
  where r.org_id = v_org_id and r.code = 'Bu_44' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0246'
  where r.org_id = v_org_id and r.code = 'Bu_44' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0539'
  where r.org_id = v_org_id and r.code = 'Bu_44' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0046'
  where r.org_id = v_org_id and r.code = 'Bu_45' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 30, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0167'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0207'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0216'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0409'
  where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_47' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0194'
  where r.org_id = v_org_id and r.code = 'Bu_47' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 4, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_47' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_49' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.05, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_49' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.2, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0104'
  where r.org_id = v_org_id and r.code = 'Bu_49' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.30000000000000004, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0105'
  where r.org_id = v_org_id and r.code = 'Bu_49' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0114'
  where r.org_id = v_org_id and r.code = 'Bu_49' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.25, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0117'
  where r.org_id = v_org_id and r.code = 'Bu_49' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 0.1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0239'
  where r.org_id = v_org_id and r.code = 'Bu_49' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0165'
  where r.org_id = v_org_id and r.code = 'Bu_50' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0164'
  where r.org_id = v_org_id and r.code = 'Bu_51' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0385'
  where r.org_id = v_org_id and r.code = 'Bu_52' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0040'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 30, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0042'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0074'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0082'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0137'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 30, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0194'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0195'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0198'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0206'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0210'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0213'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0214'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0244'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0273'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0092'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0538'
  where r.org_id = v_org_id and r.code = 'Bu_54' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0044'
  where r.org_id = v_org_id and r.code = 'Bu_55' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0072'
  where r.org_id = v_org_id and r.code = 'Bu_55' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0155'
  where r.org_id = v_org_id and r.code = 'Bu_56' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0007'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0071'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0192'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0213'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0239'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0241'
  where r.org_id = v_org_id and r.code = 'Bu_57' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'o', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0128'
  where r.org_id = v_org_id and r.code = 'Bu_58' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'o', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0127'
  where r.org_id = v_org_id and r.code = 'Bu_59' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0038'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 180, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0066'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 180, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0067'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0167'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0190'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0210'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0363'
  where r.org_id = v_org_id and r.code = 'Bu_60' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0021'
  where r.org_id = v_org_id and r.code = 'Bu_61' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0022'
  where r.org_id = v_org_id and r.code = 'Bu_61' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 180, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0066'
  where r.org_id = v_org_id and r.code = 'Bu_61' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 180, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0067'
  where r.org_id = v_org_id and r.code = 'Bu_61' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0009'
  where r.org_id = v_org_id and r.code = 'Bu_62' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_63' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0044'
  where r.org_id = v_org_id and r.code = 'Bu_64' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0072'
  where r.org_id = v_org_id and r.code = 'Bu_64' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0283'
  where r.org_id = v_org_id and r.code = 'Bu_64' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0510'
  where r.org_id = v_org_id and r.code = 'Bu_65' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1, 'trung', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'Bu_66' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0010'
  where r.org_id = v_org_id and r.code = 'Bu_67' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'Bu_67' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 90, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0163'
  where r.org_id = v_org_id and r.code = 'Bu_67' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0201'
  where r.org_id = v_org_id and r.code = 'Bu_67' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0246'
  where r.org_id = v_org_id and r.code = 'Bu_67' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 20, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0362'
  where r.org_id = v_org_id and r.code = 'Bu_67' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0435'
  where r.org_id = v_org_id and r.code = 'Bu_67' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'Bu_68' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0115'
  where r.org_id = v_org_id and r.code = 'Bu_68' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 425, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0116'
  where r.org_id = v_org_id and r.code = 'Bu_69' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0117'
  where r.org_id = v_org_id and r.code = 'Bu_69' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0507'
  where r.org_id = v_org_id and r.code = 'Bu_69' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0054'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0055'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0058'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0064'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0084'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0094'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 10, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'Bu_70' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_71' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 3, 'hop', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0170'
  where r.org_id = v_org_id and r.code = 'Bu_71' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 120, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0044'
  where r.org_id = v_org_id and r.code = 'Bu_72' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0083'
  where r.org_id = v_org_id and r.code = 'Bu_72' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 3, 'hop', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0170'
  where r.org_id = v_org_id and r.code = 'Bu_72' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0518'
  where r.org_id = v_org_id and r.code = 'Bu_72' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0564'
  where r.org_id = v_org_id and r.code = 'Bu_72' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0043'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0634'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0095'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0140'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0167'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 500, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0188'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 300, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0195'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 1000, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0238'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 100, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0257'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 3, 'hu', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0258'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 50, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0579'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'g', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0371'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 5, 'cai', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0566'
  where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom, note)
  select v_org_id, v.id, i.id, 200, 'ml', null
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'HH0141'
  where r.org_id = v_org_id and r.code = 'Bu_74' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  raise notice '§3 lines buffet: % dòng', (select count(*) from public.recipe_lines l join public.recipe_versions v on v.id = l.version_id join public.recipes r on r.id = v.recipe_id where r.org_id = v_org_id and r.kind = 'buffet_batch');
end;
$recipes$;

-- ============================================================================
-- §4. CÔNG THỨC ALACARTE — 6 món (kind='dish') + phiên bản + định lượng
-- ============================================================================
do $recipes$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
begin
  -- ALA-01 = Rau muống trộn tôm thịt
  insert into public.recipes (org_id, code, name, kind, notes)
  values (v_org_id, 'ALA-01', 'Rau muống trộn tôm thịt', 'dish',
         'Nháp từ Foodcost alacarte — mã ALA-xx tạm đặt, [CẦN XÁC NHẬN] mã chính thức; portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  -- ALA-02 = Tôm Chiên Giòn
  insert into public.recipes (org_id, code, name, kind, notes)
  values (v_org_id, 'ALA-02', 'Tôm Chiên Giòn', 'dish',
         'Nháp từ Foodcost alacarte — mã ALA-xx tạm đặt, [CẦN XÁC NHẬN] mã chính thức; portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  -- ALA-03 = Bánh mì nhồi thịt bò nướng
  insert into public.recipes (org_id, code, name, kind, notes)
  values (v_org_id, 'ALA-03', 'Bánh mì nhồi thịt bò nướng', 'dish',
         'Nháp từ Foodcost alacarte — mã ALA-xx tạm đặt, [CẦN XÁC NHẬN] mã chính thức; portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  -- ALA-04 = Súp Hải Sản Tóc Tiên
  insert into public.recipes (org_id, code, name, kind, notes)
  values (v_org_id, 'ALA-04', 'Súp Hải Sản Tóc Tiên', 'dish',
         'Nháp từ Foodcost alacarte — mã ALA-xx tạm đặt, [CẦN XÁC NHẬN] mã chính thức; portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  -- ALA-05 = Sườn heo xào chua ngọt
  insert into public.recipes (org_id, code, name, kind, notes)
  values (v_org_id, 'ALA-05', 'Sườn heo xào chua ngọt', 'dish',
         'Nháp từ Foodcost alacarte — mã ALA-xx tạm đặt, [CẦN XÁC NHẬN] mã chính thức; portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  -- ALA-06 = Cà tím tay cầm
  insert into public.recipes (org_id, code, name, kind, notes)
  values (v_org_id, 'ALA-06', 'Cà tím tay cầm', 'dish',
         'Nháp từ Foodcost alacarte — mã ALA-xx tạm đặt, [CẦN XÁC NHẬN] mã chính thức; portions_per_batch/yield/sale_price [CẦN XÁC NHẬN]')
  on conflict (org_id, code) do nothing;
  insert into public.recipe_versions (org_id, recipe_id, version_no, status)
  select v_org_id, r.id, 1, 'active'
  from public.recipes r
  where r.org_id = v_org_id and r.kind = 'dish'
    and not exists (select 1 from public.recipe_versions v
                    where v.recipe_id = r.id and v.version_no = 1);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 100, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0555'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 30, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 20, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 20, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0073'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0074'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0567'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 2, 'con'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0096'
  where r.org_id = v_org_id and r.code = 'ALA-01' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 2, 'con'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0096'
  where r.org_id = v_org_id and r.code = 'ALA-02' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 0.25, 'trung'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'ALA-02' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 2.5, 'ml'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0084'
  where r.org_id = v_org_id and r.code = 'ALA-02' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 0.5, 'o'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0125'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 60, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0592'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0023'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0172'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0166'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0028'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'ml'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0031'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0239'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0071'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0116'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 2.5, 'ml'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0084'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0062'
  where r.org_id = v_org_id and r.code = 'ALA-03' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 1, 'con'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0096'
  where r.org_id = v_org_id and r.code = 'ALA-04' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0063'
  where r.org_id = v_org_id and r.code = 'ALA-04' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 0.25, 'trung'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'ALA-04' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 150, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0573'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 0.5, 'trung'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0101'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 20, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0013'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0193'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 50, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0098'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 50, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0071'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 30, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0199'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0195'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 15, 'ml'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0207'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 15, 'ml'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0113'
  where r.org_id = v_org_id and r.code = 'ALA-05' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 150, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0099'
  where r.org_id = v_org_id and r.code = 'ALA-06' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0200'
  where r.org_id = v_org_id and r.code = 'ALA-06' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0048'
  where r.org_id = v_org_id and r.code = 'ALA-06' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 5, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0074'
  where r.org_id = v_org_id and r.code = 'ALA-06' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
  select v_org_id, v.id, i.id, 10, 'g'
  from public.recipe_versions v
  join public.recipes r on r.id = v.recipe_id
  join public.items i on i.org_id = v_org_id and i.code = 'NVL0049'
  where r.org_id = v_org_id and r.code = 'ALA-06' and v.version_no = 1
    and not exists (select 1 from public.recipe_lines l
                    where l.version_id = v.id and l.item_id = i.id);
  raise notice '§4 alacarte: % món, % dòng', (select count(*) from public.recipes where org_id = v_org_id and kind = 'dish'), (select count(*) from public.recipe_lines l join public.recipe_versions v on v.id = l.version_id join public.recipes r on r.id = v.recipe_id where r.org_id = v_org_id and r.kind = 'dish');
end;
$recipes$;

-- ============================================================================
-- §5. KIỂM CHỨNG (chỉ đọc — chạy sau khi nhập)
-- ============================================================================
-- select kind, count(*) from public.recipes where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' group by kind;
--   kỳ vọng: buffet_batch 75, dish 6.
-- select count(*) from public.recipe_versions v join public.recipes r on r.id = v.recipe_id where r.org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71';
--   kỳ vọng: 81.
-- select r.kind, count(*) from public.recipe_lines l join public.recipe_versions v on v.id = l.version_id join public.recipes r on r.id = v.recipe_id where r.org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' group by r.kind;
--   kỳ vọng: buffet_batch 348, dish 44.
-- select r.code, count(*) from public.recipe_lines l join public.recipe_versions v on v.id = l.version_id join public.recipes r on r.id = v.recipe_id where r.org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' group by r.code having count(*) = 0;
--   (món nào không có dòng nào sẽ hiện ở §6 — xử lý trước khi go-live).

-- ============================================================================
-- §6. [CẦN XÁC NHẬN] — các dòng KHÔNG nhập được (đã comment lại).
--   Xử lý xong từng dòng rồi mới bỏ comment + chạy. KHÔNG xóa.
-- ============================================================================
-- [CẦN XÁC NHẬN: món '#N/A' không có trong sheet Menu]
--   món '#N/A' (bake bean) — nguyên liệu 'Đậu xốt cà baked beans ( Đậu sốt AYAM)', Mã NVL 'NVL0168', ĐVT 'gr', SL 450.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 450, 'g'
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = 'NVL0168'
--   where r.org_id = v_org_id and r.code = '#N/A' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_4' (Bánh bèo sốt tôm) — nguyên liệu 'NƯỚC MẮM NAM NGƯ 750ML', Mã NVL '', ĐVT '', SL 20.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 20, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_4' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_25' (cá cơm kho tiêu) — nguyên liệu 'NƯỚC MẮM NAM NGƯ 750ML', Mã NVL '', ĐVT '', SL 200.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 200, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_25' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_29' (Chả trứng gà) — nguyên liệu 'NƯỚC MẮM NAM NGƯ 750ML', Mã NVL '', ĐVT '', SL 10.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 10, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_29' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_41' (Dưa hấu) — nguyên liệu 'Trái dưa hấu', Mã NVL '', ĐVT '', SL 1000.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 1000, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_41' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_43' (emmental cheese) — nguyên liệu 'emmental cheese', Mã NVL '', ĐVT '', SL 250.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 250, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_43' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_46' (heo xíu mại sốt cà) — nguyên liệu 'Nạc heo xay', Mã NVL '', ĐVT '', SL 1000.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 1000, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_46' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_55' (pineaple cook fruit) — nguyên liệu 'Trái thơm', Mã NVL '', ĐVT '', SL 1.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 1, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_55' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_73' (Mỳ quảng gà) — nguyên liệu 'đùi gà góc tư', Mã NVL '', ĐVT '', SL 1000.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 1000, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1;
-- [CẦN XÁC NHẬN: thiếu Mã NVL]
--   món 'Bu_73' (Mỳ quảng gà) — nguyên liệu 'NƯỚC MẮM NAM NGƯ 750ML', Mã NVL '', ĐVT '', SL 40.0
--   insert into public.recipe_lines (org_id, version_id, item_id, qty, uom)
--   select v_org_id, v.id, i.id, 40, null
--   from public.recipe_versions v join public.recipes r on r.id = v.recipe_id
--   join public.items i on i.org_id = v_org_id and i.code = null
--   where r.org_id = v_org_id and r.code = 'Bu_73' and v.version_no = 1;
-- [CẦN XÁC NHẬN: tên 'Thịt Nạc Vai heo loại 1 - Vietgap mã 238964' trùng dòng NVL đã bỏ qua (trùng mã NVL0091 — cần cấp mã mới Q158)]
--   món alacarte 'Rau muống trộn tôm thịt' — nguyên liệu 'Thịt Nạc Vai heo loại 1 - Vietgap mã 238964', ĐVT 'gr', SL 20.0
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)
-- [CẦN XÁC NHẬN: thiếu số lượng]
--   món alacarte 'Tôm Chiên Giòn' — nguyên liệu 'bột bắp_năng', ĐVT 'gr', SL None
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)
-- [CẦN XÁC NHẬN: thiếu số lượng]
--   món alacarte 'Tôm Chiên Giòn' — nguyên liệu 'bột Mì', ĐVT 'gr', SL None
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)
-- [CẦN XÁC NHẬN: thiếu số lượng]
--   món alacarte 'Tôm Chiên Giòn' — nguyên liệu 'Tương Ớt sài gòn (2lit)', ĐVT 'ml', SL None
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)
-- [CẦN XÁC NHẬN: thiếu số lượng]
--   món alacarte 'Tôm Chiên Giòn' — nguyên liệu 'mayonnaise', ĐVT 'gr', SL None
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)
-- [CẦN XÁC NHẬN: tên nguyên liệu 'Tóc Tiên' không khớp danh mục NVL]
--   món alacarte 'Súp Hải Sản Tóc Tiên' — nguyên liệu 'Tóc Tiên', ĐVT 'gr', SL 5.0
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)
-- [CẦN XÁC NHẬN: tên nguyên liệu 'Trái thơm' không khớp danh mục NVL]
--   món alacarte 'Sườn heo xào chua ngọt' — nguyên liệu 'Trái thơm', ĐVT '', SL 0.2
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)
-- [CẦN XÁC NHẬN: tên 'Thịt Nạc Vai heo loại 1 - Vietgap mã 238964' trùng dòng NVL đã bỏ qua (trùng mã NVL0091 — cần cấp mã mới Q158)]
--   món alacarte 'Cà tím tay cầm' — nguyên liệu 'Thịt Nạc Vai heo loại 1 - Vietgap mã 238964', ĐVT 'gr', SL 30.0
--   (ghép tay tên → mã NVL rồi thêm dòng như §4)

-- ============================================================================
-- ROLLBACK (nếu cần — xóa ngược thứ tự, audit_log giữ dấu vết theo thiết kế)
-- ============================================================================
-- delete from public.recipe_lines where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and version_id in (select v.id from public.recipe_versions v join public.recipes r on r.id = v.recipe_id where r.org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and r.notes like 'Nháp từ%');
-- delete from public.recipe_versions where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and recipe_id in (select id from public.recipes where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and notes like 'Nháp từ%');
-- delete from public.recipes where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and notes like 'Nháp từ%';
