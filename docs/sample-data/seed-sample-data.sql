-- ============================================================================
-- SEED DỮ LIỆU MẪU THẬT — ERP_hotel (workstream 8, 10/11/2026)
-- File seed ĐỘC LẬP — KHÔNG PHẢI migration, KHÔNG tự chạy khi db push.
-- Chạy 1 LẦN bằng Supabase Dashboard → SQL Editor (role postgres).
--
-- NGUỒN (dữ liệu vận hành thật của khách sạn, 2018–2020 — KHÔNG bịa):
--   1. Lst_2020_DL_Buffet.xlsx      (sheet NVL: 662 dòng; Menu: 75 món;
--      02 DL góc: 358 dòng định lượng; Sổ dl buffet: 359 dòng)
--   2. Lst_Alacarte_foodcost.xlsx   (sheet NVL: 661 dòng — trùng bản buffet
--      trừ 1 dòng; Foodcost: 53 dòng / 6 món; 02 Định lượng: thẻ giá Kosher)
--   3. Nha__p_Xua__t_Minibar.xlsx  (14 tháng 10.2018–11.2019, 6 món + rượu vang)
--   4. tha_ng_5_..._Amenities_....xlsx (tháng 5/2019: 12 món, 1.175 phòng)
--   Chi tiết đối chiếu đầy đủ: docs/sample-data/README.md
--
-- SEED GÌ:
--   §1  UoM còn thiếu (bảo vệ — phần lớn đã có từ migration T-014)
--   §2  Nhóm vật tư (TP/CCDC/MB/AMN/CPM đã có từ T-012; thêm KHAC)
--   §3  items: 668 dòng (NVL buffet 649 + minibar 7
--        + amenities 12) — master data, idempotent
--   §4  minibar_price_list: 7 giá bán LỊCH SỬ (10/2018–11/2019, xem README §4)
--   §5  room_setup_standards: 12 món × số loại phòng hiện có (checkout)
--   §6  trolley_par_levels: 12 món × số xe đẩy hiện có
--
-- KHÔNG SEED (cố ý — xem README §6 + Q157):
--   * KHÔNG ghi stock_moves / stock_balances / item_costs (tồn kho chỉ đi qua
--     RPC post; tồn đầu kỳ lấy bằng KIỂM ĐẾM THỰC TẾ ngày chuyển đổi — docs/07 §4).
--     Số tồn cuối 11/2019 chỉ ghi trong README để tham khảo, KHÔNG nhập làm tồn đầu.
--   * KHÔNG seed công thức/menu: chưa có bảng recipes/recipe_versions/
--     recipe_lines (docs/03 A7 — P2, chưa làm). 75 món + 358 dòng định lượng
--     buffet + 53 dòng alacarte chỉ ghi trong README, chờ task tạo bảng (Q158).
--   * KHÔNG seed giá vốn / NCC / hợp đồng giá (file không có dữ liệu này).
--
-- CÁCH CHẠY:
--   1. Sửa 2 giá trị ở §0 nếu chạy cho khách sạn khác (mặc định: SONHOIAN).
--   2. Chạy TOÀN BỘ file 1 lần. Nếu SQL Editor báo lỗi vì file dài, chạy từng
--      khối §0 → §1 → §2 → §3a → §3b → §3c → §4 → §5 → §6 theo thứ tự, trong
--      CÙNG 1 tab (biến §0 lưu theo session). Mỗi khối đều idempotent — chạy
--      lại không nhân đôi dữ liệu (xem ghi chú từng khối).
--   3. Kiểm tra bằng các truy vấn ở cuối file (§7) — số lượng kỳ vọng ghi sẵn.
--   4. Rollback (nếu cần gỡ): xem khối chú thích cuối file.
--
-- LƯU Ý RLS: file chạy bằng role postgres trong SQL Editor nên bypass RLS.
--   Các dòng insert đều có created_by mặc định auth.uid() (= NULL khi chạy
--   bằng SQL Editor — cột cho phép NULL; audit trigger ghi actor NULL, hợp lệ).
-- ============================================================================

-- ============================================================================
-- §0. BIẾN — SỬA 2 DÒNG NÀY nếu chạy cho khách sạn khác (mặc định: SONHOIAN)
-- ============================================================================
select set_config('seed.org_id', '00dc6aeb-5e34-4e01-9b80-032a72b16d71', false);
select set_config('seed.property_id', '7e37858d-58ed-4924-bb8f-9d56be9c620b', false);

-- ============================================================================
-- §1. ĐƠN VỊ TÍNH (uoms) — chỉ chèn mã còn thiếu; đã có từ migration T-014/T-010
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.uoms (code, name_vi)
  values
  ('bich', 'Bịch'),
  ('bo', 'Bó'),
  ('cai', 'Cái'),
  ('can', 'Can'),
  ('cay', 'Cây'),
  ('chai', 'Chai'),
  ('con', 'Con'),
  ('cuon', 'Cuộn'),
  ('doi', 'Đôi'),
  ('don', 'Đòn'),
  ('g', 'Gam'),
  ('goi', 'Gói'),
  ('hop', 'Hộp'),
  ('hu', 'Hủ'),
  ('kg', 'Kilôgam'),
  ('l', 'Lít'),
  ('la', 'Lá'),
  ('lat', 'Lát'),
  ('lo', 'Lọ'),
  ('loc', 'Lóc'),
  ('lon', 'Lon'),
  ('ly', 'Ly'),
  ('mieng', 'Miếng'),
  ('ml', 'Mililít'),
  ('nai', 'Nải'),
  ('o', 'Ổ'),
  ('phan', 'Phần'),
  ('thung', 'Thùng'),
  ('trai', 'Trái'),
  ('trung', 'Trứng'),
  ('uc', 'Ức'),
  ('vien', 'Viên'),
  ('xap', 'Xấp')
  on conflict (code) do nothing;
  get diagnostics v_n = row_count;
  raise notice '§1 uoms: % mã mới (0 = đã đủ)', v_n;
end;
$seed$;

-- ============================================================================
-- §2. NHÓM VẬT TƯ (item_groups) — 5 nhóm đã có từ T-012, thêm KHAC (Vật tư khác, kind 'other') cho 5 dòng Nhiên Liệu
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.item_groups (org_id, code_prefix, name, kind)
  values
    (v_org_id, 'TP', 'Thực phẩm tươi sống & khô', 'food'),
    (v_org_id, 'DU', 'Đồ uống & Rượu bia', 'beverage'),
    (v_org_id, 'AMN', 'Đồ dùng phòng khách', 'amenity'),
    (v_org_id, 'CPM', 'Đồ miễn phí cho khách', 'complimentary'),
    (v_org_id, 'MB', 'Mặt hàng Minibar', 'minibar'),
    (v_org_id, 'CCDC', 'Công cụ dụng cụ', 'ccdc'),
    (v_org_id, 'KHAC', 'Vật tư khác', 'other')
  on conflict (org_id, code_prefix) do nothing;
  get diagnostics v_n = row_count;
  raise notice '§2 item_groups: % nhóm mới (0 = đã đủ)', v_n;
  if (select count(*) from public.item_groups
      where org_id = v_org_id and code_prefix in ('TP','CCDC','KHAC','MB','AMN','CPM')) <> 6 then
    raise exception 'Thiếu nhóm vật tư cho org % (cần đủ TP/CCDC/KHAC/MB/AMN/CPM)', v_org_id;
  end if;
end;
$seed$;

-- ============================================================================
-- §3a. ITEMS — NVL buffet (phần 1/3) — 284 dòng (NVL 649 dòng chia 3 khối < ~45KB để paste được vào SQL Editor) — idempotent: bỏ qua dòng đã tồn tại theo mã HOẶC tên
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.items (org_id, code, name, group_id, stock_uom, recipe_uom, stock_to_recipe, is_key_item, external_codes)
  select v_org_id, v.code, v.name, g.id, v.stock_uom, v.recipe_uom, v.factor, v.is_key, v.ext
  from (values
  ('NVL0388', 'ba chỉ nách', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":1,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0152', 'BA CHỈ XÔNG KHÓI', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":2,"loai":"Thịt Nguội","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0561', 'Bánh bèo', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":3,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0559', 'Bánh da lợn', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":4,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0387', 'bánh mì baguette', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":5,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0003', 'Bánh Mì Burger', 'TP', 'o', 'o', 1, false, '{"f":"buffet-nvl","stt":6,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0004', 'Bánh Mì Gối ( sandwich)', 'TP', 'o', 'o', 1, false, '{"f":"buffet-nvl","stt":7,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0129', 'Bánh Mì gối Đen', 'TP', 'o', 'o', 1, false, '{"f":"buffet-nvl","stt":8,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0554', 'bánh su xê', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":9,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0537', 'bánh tráng bò bía', 'TP', 'xap', 'cai', 30, false, '{"f":"buffet-nvl","stt":10,"loai":"Bánh Tráng","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0566', 'bánh tráng chín', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":11,"loai":"Bánh Tráng","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0218', 'Bánh tráng lề', 'TP', 'xap', 'cai', 10, false, '{"f":"buffet-nvl","stt":12,"loai":"Bánh Tráng","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0219', 'Bánh Tráng sg (200g)', 'TP', 'xap', 'g', 200, false, '{"f":"buffet-nvl","stt":13,"loai":"Bánh Tráng","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0117', 'Bắp hạt lon', 'TP', 'lon', 'g', 400, false, '{"f":"buffet-nvl","stt":14,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0007', 'bắp su trắng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":15,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0420', 'BẦU', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":16,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0009', 'Beef salami (500g)', 'TP', 'goi', 'g', 500, true, '{"f":"buffet-nvl","stt":17,"loai":"Thịt Nguội","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0267', 'bí đao', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":18,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0364', 'bí đỏ', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":19,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0363', 'Bí ngồi (Mướp Tây) vàng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":20,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0190', 'Bí ngồi (Mướp Tây) xanh', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":21,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0010', 'black olive (340g)', 'TP', 'lon', 'g', 340, false, '{"f":"buffet-nvl","stt":22,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0553', 'Blue chesse', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":23,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0012', 'Bông cải trắng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":24,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0011', 'bông cải xanh', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":25,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0509', 'Bông gòn', 'CCDC', 'goi', 'goi', 1, false, '{"f":"buffet-nvl","stt":26,"loai":"CCDC"}'::jsonb),
  ('NVL0193', 'bột bắp_năng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":27,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0560', 'Bột chiên xù', 'TP', 'goi', 'g', 150, false, '{"f":"buffet-nvl","stt":28,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0386', 'BỘT CROISANT', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":29,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0359', 'bột gạo', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":30,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0013', 'bột Mì', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":31,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0172', 'BƠ ANCHO KHỐI', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":32,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0425', 'Bơ đậu', 'TP', 'bich', 'bich', 1, false, '{"f":"buffet-nvl","stt":33,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0243', 'bột cary', 'TP', 'goi', 'g', 10, false, '{"f":"buffet-nvl","stt":34,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0423', 'Bơ đầu bò', 'TP', 'mieng', 'mieng', 1, true, '{"f":"buffet-nvl","stt":35,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0415', 'BƠ ĐẬU PHỤNG', 'TP', 'hu', 'hu', 1, false, '{"f":"buffet-nvl","stt":36,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0123', 'Bơ vĩ Anchor (100 vien)', 'TP', 'vien', 'vien', 1, true, '{"f":"buffet-nvl","stt":37,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0407', 'bún gạo', 'TP', 'goi', 'g', 250, false, '{"f":"buffet-nvl","stt":38,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0014', 'Bún Tươi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":39,"loai":"Nui - Mỳ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0278', 'búp bò', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":40,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0506', 'Bưởi trái', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":41,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0531', 'cá bạc má', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":42,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0246', 'Cà chua Bi / cherry tomato', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":43,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0107', 'cá cơm', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":44,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0429', 'Cá cơm khô', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":45,"loai":"NVL Khô","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0017', 'cá diêu hồng(bếp)', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":46,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0403', 'cá ngân(nv)', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":47,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0430', 'cá ngừ', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":48,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0261', 'cá nục bông', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":49,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0166', 'CÀ PAST 400G', 'TP', 'lon', 'g', 400, false, '{"f":"buffet-nvl","stt":50,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0431', 'Cá phèn', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":51,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0020', 'cai bó xôi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":52,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0263', 'cải cay', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":53,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0362', 'cải con', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":54,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0021', 'cải ngọt', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":55,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0240', 'cải thảo', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":56,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0022', 'cải thìa', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":57,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0016', 'Cam tươi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":58,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0565', 'cánh gà', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":59,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0421', 'CARY HỦ', 'TP', 'hu', 'g', 45, false, '{"f":"buffet-nvl","stt":60,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0199', 'CẦN TÀU', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":61,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0023', 'Cần Tây lớn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":62,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0572', 'chả cá(nv)', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":63,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0518', 'chanh dây(bếp)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":64,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0194', 'CHANH XANH', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":65,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0024', 'cheddar cheese', 'TP', 'goi', 'mieng', 12, true, '{"f":"buffet-nvl","stt":66,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0563', 'cheddar newzealand', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":67,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0126', 'chocolate Croisant', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":68,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0171', 'CHOCOLATE ĐEN', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":69,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0284', 'chuối cau (bếp)', 'TP', 'nai', 'trai', 12, false, '{"f":"buffet-nvl","stt":70,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0374', 'corn flake (500g)', 'TP', 'hop', 'g', 500, false, '{"f":"buffet-nvl","stt":71,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0428', 'cồn nước', 'KHAC', 'l', 'ml', 1000, false, '{"f":"buffet-nvl","stt":72,"loai":"Nhiên Liệu","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0130', 'Croisant', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":73,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0028', 'củ cà rốt', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":74,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0535', 'củ cải', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":75,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0235', 'củ dền', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":76,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0149', 'CỦ SEN NGÂM 500G', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":77,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0029', 'Cua nguyên con', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":78,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0031', 'dalat red wine', 'TP', 'chai', 'ml', 750, false, '{"f":"buffet-nvl","stt":79,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0399', 'dalat white wine 750ml', 'TP', 'chai', 'ml', 750, false, '{"f":"buffet-nvl","stt":80,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0510', 'Dăm bông (bếp)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":81,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0538', 'dấm trắng coroni', 'TP', 'l', 'ml', 1000, false, '{"f":"buffet-nvl","stt":82,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0542', 'Dấm vinegar balsamic', 'TP', 'l', 'ml', 1000, false, '{"f":"buffet-nvl","stt":83,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0167', 'DẦU CÁI LÂN 25L', 'TP', 'can', 'ml', 27400, false, '{"f":"buffet-nvl","stt":84,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0160', 'DẦU DẤM', 'TP', 'chai', 'ml', 270, false, '{"f":"buffet-nvl","stt":85,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0033', 'dầu hào (820ml)', 'TP', 'chai', 'ml', 820, false, '{"f":"buffet-nvl","stt":86,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0215', 'DẦU MÈ', 'TP', 'chai', 'ml', 100, false, '{"f":"buffet-nvl","stt":87,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('HH0118', 'Dừa (trái)', 'TP', 'trai', 'trai', 1, false, '{"f":"buffet-nvl","stt":88,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0266', 'dưa cải', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":89,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0557', 'DƯA CHUỘT BAO TỬ', 'TP', 'hu', 'g', 350, false, '{"f":"buffet-nvl","stt":90,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0115', 'Dưa leo tươi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":91,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0545', 'Dừa sấy', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":92,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0030', 'Đại Hồi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":93,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0116', 'Đậu đỏ lon (425g) (Đậu đỏ FIAMMA)', 'TP', 'lon', 'g', 425, false, '{"f":"buffet-nvl","stt":94,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0262', 'đậu hủ lát', 'TP', 'lat', 'lat', 1, false, '{"f":"buffet-nvl","stt":95,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0567', 'đậu phụng chín', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":96,"loai":"Hạt","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0214', 'ĐẬU PHỤNG SỐNG', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":97,"loai":"Hạt","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0118', 'Đậu Tây', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":98,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0507', 'Đậu tây Đà lạt', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":99,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0168', 'Đậu xốt cà baked beans ( Đậu sốt AYAM)', 'TP', 'lon', 'g', 450, false, '{"f":"buffet-nvl","stt":100,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0035', 'đế pizza', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":101,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0037', 'Đinh Hương (tiểu Hồi)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":102,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0133', 'Đu đủ Chín', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":103,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0040', 'Đu đủ sống', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":104,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0358', 'đùi gà', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":105,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0042', 'Đường Phèn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":106,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0043', 'Đường Trắng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":107,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0044', 'Đường Vàng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":108,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0124', 'emmental cheese 3kg/cục', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":109,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0435', 'FETA CHEESSE', 'TP', 'hu', 'g', 300, true, '{"f":"buffet-nvl","stt":110,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0280', 'gà nguyên con', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":111,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0272', 'gạo nhân viên', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":112,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0406', 'Gas bình 48 kg', 'KHAC', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":113,"loai":"Nhiên Liệu","cp":"4 nhiên liệu"}'::jsonb),
  ('NVL0395', 'gas mini', 'KHAC', 'lon', 'lon', 1, false, '{"f":"buffet-nvl","stt":114,"loai":"Nhiên Liệu","cp":"4 nhiên liệu"}'::jsonb),
  ('NVL0405', 'Gas nước P12', 'KHAC', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":115,"loai":"Nhiên Liệu","cp":"4 nhiên liệu"}'::jsonb),
  ('NVL0244', 'giá đậu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":116,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0375', 'gia vị bò kho', 'TP', 'goi', 'g', 18, false, '{"f":"buffet-nvl","stt":117,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0576', 'Giò heo', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":118,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0206', 'GỪNG LỚN', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":119,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0046', 'Ham (DĂM BÔNG)', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":120,"loai":"Thịt Nguội","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0197', 'Hành boa rô', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":121,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0200', 'HÀNH LÁ', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":122,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0398', 'hành phi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":123,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0048', 'Hành Tây', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":124,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0049', 'Hành tím lớn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":125,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0201', 'HÀNH TÍM NHỎ LỘT', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":126,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0237', 'hạt điều màu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":127,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0050', 'hạt điều rang', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":128,"loai":"Hạt","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0141', 'Hạt nêm Maggi nấm hương', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":129,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0140', 'Hạt nêm ngon ngon gà', 'TP', 'goi', 'g', 3000, false, '{"f":"buffet-nvl","stt":130,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0051', 'hạt sen tươi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":131,"loai":"Hạt","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0226', 'hẹ lá', 'TP', 'bo', 'bo', 1, false, '{"f":"buffet-nvl","stt":132,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0052', 'Hoành thánh chiên', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":133,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0053', 'Kem Tươi', 'TP', 'l', 'ml', 1000, true, '{"f":"buffet-nvl","stt":134,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0054', 'ketchup', 'TP', 'chai', 'g', 300, false, '{"f":"buffet-nvl","stt":135,"loai":"NVL Khô","cp":"3 Gia vị"}'::jsonb),
  ('NVL0209', 'KHOAI LANG', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":136,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0222', 'khoai môn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":137,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0055', 'Khoai tây', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":138,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0056', 'Khoai Tây Chiên', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":139,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0408', 'khổ qua', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":140,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0236', 'lá chuối', 'TP', 'xap', 'xap', 1, false, '{"f":"buffet-nvl","stt":141,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0383', 'lá galentin', 'TP', 'la', 'la', 1, false, '{"f":"buffet-nvl","stt":142,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0376', 'lagu cắt sẵn (nấu chay)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":143,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0436', 'LẠP XƯỞNG', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":144,"loai":"Thịt Nguội","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0058', 'mayonnaise', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":145,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0577', 'Mắm cái', 'TP', 'chai', 'chai', 1, false, '{"f":"buffet-nvl","stt":146,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0402', 'mắm dưa', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":147,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0575', 'Mắm rút', 'TP', 'hu', 'hu', 1, false, '{"f":"buffet-nvl","stt":148,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('SEED-TP-0001', 'măng chua Trắng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":149,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0224', 'mật ong', 'TP', 'chai', 'ml', 600, false, '{"f":"buffet-nvl","stt":150,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0192', 'mè Đen Chưa Rang', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":151,"loai":"Hạt","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0213', 'MÈ TRẮNG', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":152,"loai":"Hạt","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0530', 'men (bột nở)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":153,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0380', 'mì Pasta barilla spaghetti no_(500gr)', 'TP', 'hop', 'g', 500, false, '{"f":"buffet-nvl","stt":154,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0060', 'Mì ý', 'TP', 'hop', 'g', 500, false, '{"f":"buffet-nvl","stt":155,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0217', 'Miếng Dong (10g)', 'TP', 'goi', 'g', 10, false, '{"f":"buffet-nvl","stt":156,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0062', 'mozzarella cheese', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":157,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0061', 'Mỡ Heo không da', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":158,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0517', 'Mù tạt Maille Old Style(210G)', 'TP', 'hu', 'g', 210, false, '{"f":"buffet-nvl","stt":159,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0185', 'MÙ TẠT VÀNG 454G', 'TP', 'hu', 'g', 454, false, '{"f":"buffet-nvl","stt":160,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0120', 'Muesli', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":161,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0064', 'Muối bọt (I ốt)', 'TP', 'goi', 'g', 100, false, '{"f":"buffet-nvl","stt":162,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0210', 'muối sống ( muối hột)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":163,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0063', 'mực 8c/kg', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":164,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0385', 'MỨC BƯỞI QUÝT', 'TP', 'lo', 'g', 1000, false, '{"f":"buffet-nvl","stt":165,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0433', 'Mướp trái (nv)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":166,"loai":"Rau Củ"}'::jsonb),
  ('NVL0164', 'MỨT CAM 425G', 'TP', 'hu', 'g', 1000, false, '{"f":"buffet-nvl","stt":167,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0165', 'MỨT DÂU 425G', 'TP', 'lo', 'g', 1000, false, '{"f":"buffet-nvl","stt":168,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0367', 'mỳ trứng', 'TP', 'goi', 'g', 500, false, '{"f":"buffet-nvl","stt":169,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0066', 'nấm đông cô tươi', 'TP', 'goi', 'g', 180, false, '{"f":"buffet-nvl","stt":170,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0067', 'nấm linh chi trắng (180gr)', 'TP', 'goi', 'g', 180, false, '{"f":"buffet-nvl","stt":171,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0216', 'nấm mèo khô', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":172,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0068', 'Nấm rơm tươi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":173,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0371', 'nghệ củ', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":174,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0525', 'NGHÊU 25-30CON/KG', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":175,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0198', 'ngò gai ( ngò tàu)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":176,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0366', 'ngò rí', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":177,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0571', 'ngó sen', 'TP', 'hu', 'g', 500, false, '{"f":"buffet-nvl","stt":178,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0187', 'NGŨ CỐC COCOPOPS 400G', 'TP', 'hop', 'g', 400, false, '{"f":"buffet-nvl","stt":179,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0225', 'Ngũ Vị Hương 10g', 'TP', 'goi', 'g', 10, false, '{"f":"buffet-nvl","stt":180,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0539', 'nui ý (nơ)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":181,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0381', 'nước cốt dừa 400ml', 'TP', 'lon', 'ml', 400, false, '{"f":"buffet-nvl","stt":182,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0382', 'nước cốt dừa lon CHAOKOH 560ml', 'TP', 'lon', 'ml', 560, false, '{"f":"buffet-nvl","stt":183,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0211', 'NƯỚC NẮM NAM NGƯ 750ML', 'TP', 'chai', 'ml', 750, false, '{"f":"buffet-nvl","stt":185,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0233', 'nước nhị', 'TP', 'chai', 'g', 600, false, '{"f":"buffet-nvl","stt":186,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0570', 'ổi trái', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":189,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0432', 'ớt bột', 'TP', 'g', 'g', 1, false, '{"f":"buffet-nvl","stt":190,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0239', 'ớt đỏ đà lạt', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":191,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0195', 'ỚT ĐỎ TO', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":192,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0221', 'ớt hiểm nhỏ', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":193,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0257', 'ớt xanh', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":194,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0071', 'ớt Xanh Đà Lạt', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":195,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0378', 'parmesan cheese ( phô mai bột)', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":196,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0434', 'PENNE SPAGHETTI', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":197,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0541', 'phẩm màu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":198,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0180', 'PHÔ MAI CAMENBER 125G', 'TP', 'cai', 'g', 125, true, '{"f":"buffet-nvl","stt":199,"loai":"Sữa - Phô Mai","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0072', 'Quế Khâu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":200,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0397', 'Quýt trái', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":201,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0128', 'raisin nho', 'TP', 'o', 'o', 1, false, '{"f":"buffet-nvl","stt":202,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0127', 'raisin quế', 'TP', 'o', 'o', 1, false, '{"f":"buffet-nvl","stt":203,"loai":"bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0413', 'RAU BỒ NGÓT', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":204,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0073', 'rau Húng cay', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":205,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0265', 'rau lang', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":206,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0260', 'rau lộn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":207,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0270', 'rau mồng tơi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":208,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL 0610', 'Rau mùi tây', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":209,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0555', 'Rau muống hột', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":210,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0271', 'Rau Muống lăt / Water spinach', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":211,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0074', 'rau quế', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":212,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0231', 'Rau Răm', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":213,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0188', 'rau sống', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":214,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0077', 'sả cây', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":215,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0409', 'sắn dây', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":216,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0511', 'Socola syrup(BẾP)', 'TP', 'chai', 'g', 680, false, '{"f":"buffet-nvl","stt":217,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0161', 'SỐT LEA & PERRINS', 'TP', 'chai', 'ml', 290, false, '{"f":"buffet-nvl","stt":218,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0081', 'Sợi Cao Lầu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":219,"loai":"Nui - Mỳ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0238', 'Sợi Mì Quảng', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":220,"loai":"Nui - Mỳ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0082', 'Sợi Phở Tươi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":221,"loai":"Nui - Mỳ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0264', 'su su cắt sẵn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":223,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0241', 'su tím', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":224,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0170', 'SỮA CHUA KHÔNG ĐƯỜNG', 'TP', 'hop', 'hop', 1, false, '{"f":"buffet-nvl","stt":225,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0564', 'sữa đặc (1 kg)', 'TP', 'kg', 'g', 1284, false, '{"f":"buffet-nvl","stt":226,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0083', 'Sữa Tươi', 'TP', 'l', 'ml', 1000, false, '{"f":"buffet-nvl","stt":227,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0573', 'sườn heo (Mỹ)', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":228,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0080', 'Sườn heo non', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":229,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0084', 'Tabasco (60ml)', 'TP', 'chai', 'ml', 60, false, '{"f":"buffet-nvl","stt":230,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0256', 'táo nhỏ vn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":231,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0259', 'tăm', 'CCDC', 'hu', 'hu', 1, false, '{"f":"buffet-nvl","stt":232,"loai":"CCDC","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0085', 'Tép cao lầu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":233,"loai":"Nui - Mỳ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0283', 'thanh long (bếp)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":234,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0087', 'Thảo Quả', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":235,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0088', 'Thịt Bò đùi vn', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":236,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0275', 'thịt cốt lết', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":237,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0144', 'Thịt đầu thăn ngoại bò đông lạnh không xươi AUP0102-107', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":238,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0276', 'thịt heo phi lê', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":239,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0090', 'Thịt Mông heo có da', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":240,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0091', 'Thịt Nạc Vai heo', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":241,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0092', 'Thịt Nạm Bò vn', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":242,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0093', 'Thịt phô heo', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":243,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NH0210', 'TIÊU ĐEN BỘT', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":244,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0094', 'Tiêu hạt xay', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":245,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0191', 'TIÊU XANH', 'TP', 'hu', 'g', 100, false, '{"f":"buffet-nvl","stt":246,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0202', 'TỎI NHỎ LỘT', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":247,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0281', 'tôm bạc 100c/kg', 'TP', 'kg', 'con', 100, true, '{"f":"buffet-nvl","stt":248,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0096', 'tôm bạc 60c/kg', 'TP', 'kg', 'con', 60, true, '{"f":"buffet-nvl","stt":249,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0097', 'tôm sú 20c/kg', 'TP', 'kg', 'con', 20, true, '{"f":"buffet-nvl","stt":250,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0098', 'Trái Cà Chua', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":251,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0099', 'Trái cà tím', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":252,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0132', 'Dưa hấu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":253,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0220', 'trái Quật', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":254,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0131', 'Trái thơm gọt vỏ', 'TP', 'trai', 'trai', 1, false, '{"f":"buffet-nvl","stt":255,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0223', 'trứng cút', 'TP', 'trung', 'trung', 1, false, '{"f":"buffet-nvl","stt":256,"loai":"Trứng","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0101', 'Trứng Gà - mã 213603', 'TP', 'trung', 'trung', 1, false, '{"f":"buffet-nvl","stt":257,"loai":"Trứng","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0207', 'TƯƠNG CÀ', 'TP', 'chai', 'ml', 2000, false, '{"f":"buffet-nvl","stt":258,"loai":"NVL Khô","cp":"3 Gia vị"}'::jsonb),
  ('NVL0424', 'tương đậu', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":259,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0258', 'tương ớt hội an', 'TP', 'hu', 'hu', 1, false, '{"f":"buffet-nvl","stt":260,"loai":"NVL Khô","cp":"3 Gia vị"}'::jsonb),
  ('NVL0113', 'Tương Ớt sài gòn (2lit)', 'TP', 'chai', 'ml', 2000, false, '{"f":"buffet-nvl","stt":261,"loai":"NVL Khô","cp":"3 Gia vị"}'::jsonb),
  ('NVL0102', 'Ức Gà', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":262,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0135', 'vani nước (45G)', 'TP', 'chai', 'ml', 45, false, '{"f":"buffet-nvl","stt":263,"loai":"NVL Khô","cp":"3 Gia vị"}'::jsonb),
  ('NVL0104', 'xà lách carol(prize) dalat', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":264,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0105', 'xà lách dalat', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":265,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0114', 'xà lách tím dalat(lolo)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":266,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0379', 'xì dầu kikoman', 'TP', 'chai', 'ml', 1000, false, '{"f":"buffet-nvl","stt":267,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0229', 'xoài', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":268,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0155', 'XÚC XÍCH ĂN SÁNG(xx heo)', 'TP', 'goi', 'g', 500, true, '{"f":"buffet-nvl","stt":269,"loai":"Thịt Nguội","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0153', 'XÚC XÍCH GÀ', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":270,"loai":"Thịt Nguội","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0273', 'xương bò', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":271,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0274', 'xương cốt lết', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":272,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0417', 'Hến', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":273,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('SEED-TP-0002', 'xà lách ta', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":274,"loai":"Rau Mềm","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0003', 'chả đòn', 'TP', 'don', 'g', 500, true, '{"f":"buffet-nvl","stt":275,"loai":"Thịt Nguội","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0004', 'kem tràng Tiền', 'TP', 'cay', 'cay', 1, false, '{"f":"buffet-nvl","stt":276,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0039', 'dry thyme', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":278,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0038', 'dry oregano', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":279,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0008', 'bay leaf', 'TP', 'hu', 'g', 55, false, '{"f":"buffet-nvl","stt":280,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('SEED-TP-0005', 'cá nhòng', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":281,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0125', 'Bánh Mì Ổ Hội An', 'TP', 'o', 'o', 1, false, '{"f":"buffet-nvl","stt":282,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0205', 'Riềng Củ', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":283,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0006', 'Nấm Kim Châm', 'TP', 'goi', 'g', 180, false, '{"f":"buffet-nvl","stt":284,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0580', 'Rong Biển', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":285,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0631', 'Nấm Tuyết khô', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":286,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0007', 'Đậu Hà Lan Tươi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":287,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0111', 'dầu oliu virgin (salad)', 'TP', 'l', 'ml', 1000, false, '{"f":"buffet-nvl","stt":288,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('SEED-TP-0008', 'Cá bóp', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":290,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb)
  ) as v(code, name, group_prefix, stock_uom, recipe_uom, factor, is_key, ext)
  join public.item_groups g on g.org_id = v_org_id and g.code_prefix = v.group_prefix
  where not exists (
    select 1 from public.items i
    where i.org_id = v_org_id
      and (i.code = v.code or i.name_norm = public.norm_text(v.name))
  );
  get diagnostics v_n = row_count;
  raise notice '§3a. ITEMS — NVL buffet (phần 1/3): % dòng items mới', v_n;
end;
$seed$;

-- ============================================================================
-- §3b. ITEMS — NVL buffet (phần 2/3) — 269 dòng (NVL 649 dòng chia 3 khối < ~45KB để paste được vào SQL Editor) — idempotent: bỏ qua dòng đã tồn tại theo mã HOẶC tên
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.items (org_id, code, name, group_id, stock_uom, recipe_uom, stock_to_recipe, is_key_item, external_codes)
  select v_org_id, v.code, v.name, g.id, v.stock_uom, v.recipe_uom, v.factor, v.is_key, v.ext
  from (values
  ('SEED-TP-0009', 'bánh hỏi', 'TP', 'kg', 'kg', 1000, false, '{"f":"buffet-nvl","stt":291,"loai":"Nui - Mỳ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0010', 'hạt sen chín', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":292,"loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0011', 'Tàu Hủ Ky (Bồ Trúc Khô)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":294,"loai":"NVL Khô","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0012', 'Trái Mận Đỏ', 'TP', 'hop', 'g', 1000, false, '{"f":"buffet-nvl","stt":295,"loai":"Trái cây","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0013', 'kem flan', 'TP', 'hop', 'hop', 1, false, '{"f":"buffet-nvl","stt":296,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0014', 'sữa chua có đường', 'TP', 'hu', 'hop', 1, false, '{"f":"buffet-nvl","stt":297,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0015', 'Cá Rô Phi', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":298,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0103', 'vịt nguyên con', 'TP', 'cai', 'uc', 2, true, '{"f":"buffet-nvl","stt":299,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0536', 'Cá lóc nguyên con làm sẵn', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":300,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('SEED-TP-0016', 'laghim cắt sẵn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":301,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0532', 'rau tần ô', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":302,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0017', 'khoai mỡ ( khoai tím)', 'TP', 'lat', 'g', 1000, false, '{"f":"buffet-nvl","stt":303,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0018', 'Cá thu chay', 'TP', 'kg', 'lat', 1, false, '{"f":"buffet-nvl","stt":304,"loai":"NVL chay","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0019', 'Rau má', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":305,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0020', 'Trái đậu bắp', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":306,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0021', 'vải', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":307,"loai":"Trái cây","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0022', 'Cá chuồn', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":308,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('HH0003', 'Dâu tây', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":309,"loai":"Trái cây","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0023', 'cà chua lon không hạt', 'TP', 'chai', 'g', 2500, false, '{"f":"buffet-nvl","stt":311,"loai":"NVL Khô","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0024', 'Cá Cam Tươi', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":314,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0025', 'Cá Thu Cắt Lát', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":315,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0163', 'Olive Xanh Không Nhân', 'TP', 'chai', 'g', 180, false, '{"f":"buffet-nvl","stt":317,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0026', 'Trái Chôm Chôm', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":318,"loai":"Trái cây","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0027', 'đùi gà tỏi', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":319,"loai":"Thịt","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0095', 'tỏi lớn lột', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":320,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0028', 'XÀ LÁCH BÚP', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":321,"loai":"Rau Mềm","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0196', 'ngò ta ( rau mùi) (200gr)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":322,"loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0029', 'cá diêu hồng File', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":324,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0579', 'Nghệ Bột', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":325,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('SEED-TP-0030', 'Mù Tạc Xanh', 'TP', 'kg', 'g', 43, false, '{"f":"buffet-nvl","stt":326,"loai":"Gia Vị","cp":"3 Gia vị","code_gen":true}'::jsonb),
  ('SEED-TP-0031', 'Xoài Xanh', 'TP', 'cai', 'g', 1000, false, '{"f":"buffet-nvl","stt":327,"loai":"Trái cây","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0032', 'Bánh Ít Lá Gai', 'TP', 'cay', 'cai', 1, false, '{"f":"buffet-nvl","stt":328,"loai":"Bánh","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0033', 'Đậu Hủ Non', 'TP', 'kg', 'g', 220, false, '{"f":"buffet-nvl","stt":329,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0622', 'mực 10c/kg', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":330,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('SEED-TP-0034', 'Trái Nhãn', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":331,"loai":"Trái cây","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0035', 'Me Ngào', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":332,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0036', 'Cá trê', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":333,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0037', 'Chả Quét', 'TP', 'goi', 'g', 1000, true, '{"f":"buffet-nvl","stt":334,"loai":"Thịt Nguội","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0038', 'Prosciutto (đùi heo xông khói)', 'TP', 'kg', 'g', 500, true, '{"f":"buffet-nvl","stt":335,"loai":"Thịt Nguội","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0039', 'Ớt chuông vàng', 'TP', 'goi', 'g', 1000, false, '{"f":"buffet-nvl","stt":336,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0520', 'Smoked salmon (cá hồi xông khói)', 'TP', 'goi', 'g', 500, true, '{"f":"buffet-nvl","stt":337,"loai":"hải sản","cp":"1 nvl_Chính"}'::jsonb),
  ('SEED-TP-0040', 'Caper( hạt bạch nụ hoa)', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","stt":338,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0041', 'Lá thì là', 'TP', 'chai', 'g', 1000, false, '{"f":"buffet-nvl","stt":339,"loai":"Rau Mềm","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0042', 'Dầu giấm mè', 'TP', 'chai', 'ml', 1000, false, '{"f":"buffet-nvl","stt":340,"loai":"Gia Vị","cp":"3 Gia vị","code_gen":true}'::jsonb),
  ('NVL0623', 'Tương phở đen', 'TP', 'chai', 'g', 700, false, '{"f":"buffet-nvl","stt":341,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('SEED-TP-0043', 'Bánh nậm', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":342,"loai":"Bánh","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0592', 'Mông bò úc', 'TP', 'goi', 'g', 1000, true, '{"f":"buffet-nvl","stt":344,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('NVL0036', 'Demi-glace', 'TP', 'goi', 'g', 1000, false, '{"f":"buffet-nvl","stt":345,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0597', 'chả giò', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":346,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0044', 'Xíu mại', 'TP', 'kg', 'g', 500, false, '{"f":"buffet-nvl","stt":347,"loai":"Bánh","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0045', 'Gà tây nguyên con', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":348,"loai":"Thịt","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0046', 'Gan gà', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":349,"loai":"Thịt","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0047', 'mông cừu', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":350,"loai":"Thịt","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0048', 'Rosemary (lá hương thảo)', 'TP', 'goi', 'g', 1000, false, '{"f":"buffet-nvl","stt":351,"loai":"Gia Vị","cp":"3 Gia vị","code_gen":true}'::jsonb),
  ('NVL0515', 'Bột ớt cựa gà (pakrika)', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":352,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0119', 'Nấm đùi gà', 'TP', 'goi', 'g', 250, false, '{"f":"buffet-nvl","stt":353,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0049', 'Tôm Hùm 4con/kg', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":354,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0050', 'Hầu sữa', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":355,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0051', 'Điệp lớn (10con/kg)', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":356,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0052', 'Bạch tuộc', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":357,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0053', 'Bắp trái', 'TP', 'trai', 'trai', 1, false, '{"f":"buffet-nvl","stt":358,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('SEED-TP-0054', 'Bắp chuối bào sợi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":359,"loai":"Rau Củ","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0626', 'Đậu gà trắng (Chickpeas)', 'TP', 'lon', 'g', 400, false, '{"f":"buffet-nvl","stt":360,"loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0055', 'Lưỡi heo', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":361,"loai":"Thịt","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('SEED-TP-0056', 'Cá liệt', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":362,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0045', 'Gạo khách', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":363,"loai":"Nui - Mỳ","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0057', 'Đậu xanh cà', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":364,"loai":"Hạt","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('HH0141', 'sữa đậu nành', 'TP', 'hop', 'ml', 200, false, '{"f":"buffet-nvl","stt":365,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0058', 'Dừa trái', 'TP', 'trai', 'trai', 1, false, '{"f":"buffet-nvl","stt":366,"loai":"Trái cây","cp":"2 nvl_phụ","code_gen":true}'::jsonb),
  ('NVL0137', 'Nước tương đậu nành', 'TP', 'chai', 'ml', 1800, false, '{"f":"buffet-nvl","stt":367,"loai":"Gia Vị","cp":"3 Gia vị"}'::jsonb),
  ('NVL0620', 'giấy bạc', 'CCDC', 'cuon', 'g', 1370, false, '{"f":"buffet-nvl","stt":368,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('NH-0105', 'Giấy SaiGon Care', 'CCDC', 'thung', 'goi', 48, false, '{"f":"buffet-nvl","stt":371,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('NVL0384', 'giấy ăn', 'CCDC', 'bich', 'xap', 20, false, '{"f":"buffet-nvl","stt":372,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('NVL0629', 'Nạc heo xay loai 1 Vietgap - mã 238973', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":373,"loai":"Thịt","cp":"1 nvl_Chính"}'::jsonb),
  ('HH0023', 'Sữa chua', 'TP', 'hu', 'hu', 1, false, '{"f":"buffet-nvl","stt":374,"loai":"Sữa - Phô Mai","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0635', 'Bột bánh xèo nước', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":375,"loai":"Nui - Mỳ","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0059', 'gan heo', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":376,"loai":"Thịt","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('BEP-NG002', 'MÀNG BỌC THỰC PHẨM 600', 'CCDC', 'cuon', NULL, NULL, false, '{"f":"buffet-nvl","stt":377,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('HH0-95', 'Bánh su kem', 'TP', 'cai', 'cai', 1, false, '{"f":"buffet-nvl","stt":378,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('HH-083', 'Nước rửa chén', 'CCDC', 'can', 'can', NULL, false, '{"f":"buffet-nvl","stt":379,"loai":"CCDC","cp":"6 HC"}'::jsonb),
  ('KT-PA001', 'Bao ni lông đen', 'CCDC', 'kg', 'cai', NULL, false, '{"f":"buffet-nvl","stt":380,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('BP-PA002', 'Bao ni long trắng', 'CCDC', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","stt":381,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('HH-095', 'Bao rác cuộn tiểu đen', 'CCDC', 'loc', NULL, NULL, false, '{"f":"buffet-nvl","stt":382,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('NVL0527', 'bao tay nilong', 'CCDC', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","stt":383,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('HH-084', 'Bao tay su', 'CCDC', 'hop', NULL, NULL, false, '{"f":"buffet-nvl","stt":384,"loai":"CCDC","cp":"5 BQ"}'::jsonb),
  ('HH-086', 'Hóa Chất lau bếp', 'CCDC', 'chai', NULL, NULL, false, '{"f":"buffet-nvl","stt":386,"loai":"CCDC","cp":"6 HC"}'::jsonb),
  ('NVL0108', 'Dưa gan muối', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":388,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0232', 'Đũa tre', 'CCDC', 'doi', 'cay', 200, false, '{"f":"buffet-nvl","stt":389,"loai":"CCDC","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0005', 'Bánh Ướt', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":390,"loai":"Bánh","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0060', 'Sò lụa', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":400,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0606', 'Than củi', 'KHAC', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":401,"loai":"Nhiên Liệu","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0061', 'Ghẹ nguyên con', 'TP', 'kg', 'g', 1000, true, '{"f":"buffet-nvl","stt":403,"loai":"hải sản","cp":"1 nvl_Chính","code_gen":true}'::jsonb),
  ('NVL0634', 'Củ nén', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","stt":404,"loai":"Rau Củ","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0018', 'Cá ngừ lon', 'TP', 'lon', 'g', 175, false, '{"f":"buffet-nvl","loai":"NVL Khô","cp":"2 nvl_phụ"}'::jsonb),
  ('NVL0638', 'Kim chi', 'TP', 'kg', 'g', 1000, false, '{"f":"buffet-nvl","loai":"Rau Mềm","cp":"2 nvl_phụ"}'::jsonb),
  ('SEED-TP-0062', 'chocolate mousse', 'TP', 'ly', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Dessert","code_gen":true}'::jsonb),
  ('SEED-TP-0063', 'panna cotta', 'TP', 'ly', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Dessert","code_gen":true}'::jsonb),
  ('SEED-TP-0064', 'bánh Flan', 'TP', 'ly', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Dessert","code_gen":true}'::jsonb),
  ('SEED-TP-0065', 'Nhân hamburger', 'TP', 'cai', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0066', 'Hải sản pizza', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0067', 'hải sản cơm chiên', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0068', 'hải sản mì xào', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0069', 'tôm nướng bơ tỏi', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0070', 'thịt nướng', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0071', 'Đùi gà nướng', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0072', 'sườn heo lasenta', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0073', 'ức vịt cà ry', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0074', 'gà cà ry', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0075', 'cánh gà hấp', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0076', 'Gà sa tê', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0077', 'Ribeye steak', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0078', 'ướp bò kho (nạm)', 'TP', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0079', 'ướp bò cary (nạm)', 'TP', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0080', 'ướp thịt xíu (phô heo)', 'TP', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0081', 'Xíu mại viên 30gr/viên', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0082', 'Gà xíu', 'TP', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0083', 'Hải sản nướng sate', 'TP', 'phan', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0084', 'Đùi gà mỳ quảng', 'TP', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0085', 'CB025 sốt mù tạc vàng', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt Lạnh","code_gen":true}'::jsonb),
  ('SEED-TP-0086', 'CB026 sốt hồng', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt Lạnh","code_gen":true}'::jsonb),
  ('SEED-TP-0087', 'CB027 sốt dầu dấm pha', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt Lạnh","code_gen":true}'::jsonb),
  ('SEED-TP-0088', 'CB029 nước mắm chua ngọt', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt Lạnh","code_gen":true}'::jsonb),
  ('SEED-TP-0089', 'CB030 nước mắm gỏi', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt Lạnh","code_gen":true}'::jsonb),
  ('SEED-TP-0090', 'CB021 sốt cà chua âu', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0091', 'CB003 sốt cà chua á', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0092', 'CB017 sốt bò băm', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0093', 'CB022 sốt demi', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0094', 'CB018 sốt BBQ', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0095', 'CB019 sốt (gà sate)', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0096', 'CB007 sốt xì dầu xào', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0097', 'CB006 sốt xì dầu gừng', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0098', 'CB004 sốt dầu hào', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0099', 'CB001 sốt kho tộ', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0100', 'CB011 sốt hoisin', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0101', 'CB010 sốt sate', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0102', 'CB023 sốt cà ry đỏ', 'TP', 'kg', 'vien', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0103', 'CB024 sốt cà ry vàng', 'TP', 'kg', 'vien', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0104', 'CB002 Thắng tương ớt', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0105', 'CB032 Sốt Tương đậu', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Sốt nóng","code_gen":true}'::jsonb),
  ('SEED-TP-0106', 'súp bí đỏ', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"súp","code_gen":true}'::jsonb),
  ('SEED-TP-0107', 'Nghêu chín', 'TP', 'kg', 'con', NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0108', 'nghệ củ xay sẵn', 'TP', 'kg', NULL, NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","cp":"7 làm sẵn","code_gen":true}'::jsonb),
  ('SEED-TP-0109', 'Nạm bò chín', 'TP', 'kg', 'g', NULL, false, '{"f":"buffet-nvl","loai":"Làm Sẵn","code_gen":true}'::jsonb),
  ('SEED-CCDC-0001', 'Thố cơm lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0002', 'Thố cơm nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0003', 'Thố gốm nắp gỗ H17D20cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0004', 'Chén bánh bèo', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0005', 'Chén Flan lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0006', 'Chén ngấm 2 ngăn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0007', 'Dĩa CN 33*18', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0008', 'Dĩa tròn 8cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0009', 'Dĩa HCN 51*21 cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0010', 'Dĩa Inox cạn 22cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0011', 'Dĩa Inox sâu 24cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0012', 'Dĩa Inox sâu 28cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0013', 'Dĩa oval 32 cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0014', 'Dĩa tròn ảo 27 cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0015', 'Dĩa tròn 31 cm có vành', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0016', 'Dĩa tròn 45cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0017', 'Dĩa tròn 31 cm không vành', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0018', 'Dĩa sâu lòng 23 cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0019', 'Dĩa sâu lòng 18 cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0020', 'Dĩa vuông 25 cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0021', 'Dĩa vuông nhí SQD31', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0022', 'Ly gốm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0023', 'Ly ( 4 loại)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0024', 'Tô thủy tinh P00625 Ocean', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0025', 'Tô cao 15 cm - Tô phở nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0026', 'Tô cao 20 cm - Tô phở lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0027', 'Tô mỳ quảng', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0028', 'Tô oval 25*38 cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0029', 'NẮP ĐẬY ĐĨA THỨC ĂN PI 25CM', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0030', 'Chụp thủy tinh D22H16', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0031', 'Hôp lưu mẫu Inox trung', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0032', 'Hộp nhựa 2 quai xách (Đại)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0033', 'Hộp nhựa 2 quai xách (nhỏ)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0034', 'Hộp nhựa 2 quai xách (trung)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0035', 'Hộp nhựa để trong tủ lạnh (Đại)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0036', 'Hộp nhựa để trong tủ lạnh (nhỏ)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0037', 'Hộp nhựa để trong tủ lạnh (Trung)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0038', 'Hộp nhựa lớn (Căn tin )', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0039', 'Hộp nhựa nhỏ (Căn tin )', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0040', 'Hủ đường gốm có nắp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0041', 'Hủ yout', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0042', 'Chảo 22cm (Cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0043', 'Chảo chengs 30cm đế bằng ko chống dính Inox', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0044', 'Chảo chengs chống dính 30cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0045', 'Chảo Inox 24cm ko chống dính', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0046', 'Chảo nhôm 36 Thanh hiền 2 quai', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0047', 'Chảo nhôm gò 50', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0048', 'Chảo nhôm gò 70', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0049', 'Chảo nhôm gò đáy bằng 50cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0050', 'Chảo nhôm gò đáy bằng 60cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0051', 'Chảo SH chống dính 24cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0052', 'Chảo SH chống dính 30cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0053', 'Chảo thép (gang) cán gỗ 40', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0054', 'Dao 2 lưỡi HN nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0055', 'Dao Pho mat MGB08', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0056', 'Dao cắt bánh mì', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0057', 'Dao nạy hào', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0058', 'Dao phi lê', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0059', 'Dao tròn cắt pizza 1 bánh xe', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0060', 'Dao xắt HN', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0061', 'Đà mái Thái Lan', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0062', 'Đánh trứng lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0063', 'Đánh trứng xoay', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0064', 'Đánh trứng trung', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0065', 'Đánh vảy cá', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0066', 'Kho tộ lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0067', 'Kho tộ nhỏ (Cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0068', 'Khuôn bánh CN (nhôm)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0069', 'Khuôn bánh gối nhỏ bằng nhôm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0070', 'Khuôn CN không dây SN3382', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0071', 'Khuôn mai nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0072', 'Khuôn tạc nhỏ SN60615', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0073', 'Khuôn tròn không dây SN3240', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0074', 'Khuôn tròn nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0075', 'Khay nướng Inox lò nướng nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0076', 'Khay 1/1 H65 lỗ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0077', 'Khay 1/1H65 không lỗ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0078', 'Khay 1/2H100', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0079', 'Khay 1/3H100', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0080', 'Khay 1/4H100 + nắp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0081', 'Khay 1/6H150 + nắp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0082', 'Khay 1/9H65 + nắp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0083', 'Khay 1/1 H100 có lỗ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0084', 'Khay 1/1 H100', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0085', 'Khay 1/1 H150', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0086', 'Nắp 1/1', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0087', 'Dĩa CN 30*17', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0088', 'Khay cơm nhân viên Inox (ko nắp)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0089', 'Khay Inox sâu 20*30 2 lớp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0090', 'Khay Inox sâu 30*40 2 lớp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0091', 'Vá canh 7 Inox rẻ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0092', 'Vá canh 8 Inox rẻ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0093', 'Vá canh Inox cán ngăn 18cm RH', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0094', 'Vá dân sinh ( vá xào cán gỗ)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0095', 'Vá phở Inox', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0096', 'Vá RH dẹp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0097', 'Vá RH lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0098', 'Vĩ nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0099', 'Vĩ nướng hộp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0100', 'Vòi phun tráng', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0101', 'Vòi tưới buddy', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0102', 'Vòng chiên trứng', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0103', 'Vợt chanh', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0104', 'Vợt dầu cán Inox dài 20cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0105', 'Vợt dầu nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0106', 'Vợt xương cán gỗ 28cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0107', 'Trụng phở Inox', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0108', 'Rổ đức 30cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0109', 'Rổ nhựa có lỗ Ky hở 1T9', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0110', 'Thau Inox 14cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0111', 'Thau Inox 22cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0112', 'Thau Inox 32cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0113', 'Thau Inox 34cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0114', 'Thau Inox 44cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0115', 'Thớt gỗ (Pizza)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0116', 'Thớt lục giác bằng gỗ (Chuyển nhà hàng từ T8/2018)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0117', 'Thớt gỗ Cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0118', 'Thớt nhựa 30*40 (trắng + xanh + đỏ)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0119', 'Xẻng gỗ lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0120', 'Xẻng Inox cán gỗ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0121', 'Xẻng xúc bánh ko lỗ dài', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0122', 'Gắp đá 30cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0123', 'Kẹp gấp bánh mỳ nhỏ: N8-GI-JXX103', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0124', 'bếp ga DL(Cookclass)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0125', 'Bếp ga Ri RB-2CG (bếp 3 họng Buffet)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0126', 'Bình mắm lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb)
  ) as v(code, name, group_prefix, stock_uom, recipe_uom, factor, is_key, ext)
  join public.item_groups g on g.org_id = v_org_id and g.code_prefix = v.group_prefix
  where not exists (
    select 1 from public.items i
    where i.org_id = v_org_id
      and (i.code = v.code or i.name_norm = public.norm_text(v.name))
  );
  get diagnostics v_n = row_count;
  raise notice '§3b. ITEMS — NVL buffet (phần 2/3): % dòng items mới', v_n;
end;
$seed$;

-- ============================================================================
-- §3c. ITEMS — NVL buffet (phần 3/3) — 96 dòng (NVL 649 dòng chia 3 khối < ~45KB để paste được vào SQL Editor) — idempotent: bỏ qua dòng đã tồn tại theo mã HOẶC tên
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.items (org_id, code, name, group_id, stock_uom, recipe_uom, stock_to_recipe, is_key_item, external_codes)
  select v_org_id, v.code, v.name, g.id, v.stock_uom, v.recipe_uom, v.factor, v.is_key, v.ext
  from (values
  ('SEED-CCDC-0127', 'Bình mắm nhỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0128', 'Bình ngũ cốc đơn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0129', 'Bình rót gốm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0130', 'Bình xịt nhựa (Cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0131', 'Bộ bắt bông kem Inox', 'CCDC', 'hop', 'hop', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0132', 'Bộ cắt táo hình vuông', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0133', 'Bộ cối chày gỗ lớn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0134', 'Bộ khuôn Inox chắn bánh', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0135', 'Bộ muỗng đo lường Goodcook', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0136', 'Búa đập thịt 1 đầu', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0137', 'Buffer AT62293', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0138', 'Buffer có cục giữ lạnh', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0139', 'Ca đong Đức 1lít', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0140', 'Ca đong Đức 250ml', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0141', 'Cân 60kg', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0142', 'Cây cào nước', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0143', 'Cây chà nồi', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0144', 'Cây chùi kính', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0145', 'Cây đẩy nước', 'CCDC', 'cay', 'cay', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0146', 'Cây lau nhà', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0147', 'Cây mài dao', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0148', 'Cây xiên thịt cán đen', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0149', 'Cọ Silicon', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0150', 'Dây nước', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0151', 'Đèn bẫy con trùng FOS-01', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0152', 'Đèn giữ nóng thức ăn', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0153', 'Thanh tròn nhôm SN42134', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0154', 'Gáo Inox cán dài 16cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0155', 'Giỏ đựng rác(Cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0156', 'Giỏ rác VP', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0157', 'Hộp bỏ giấy ( căn tin )', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0158', 'Kệ dép', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0159', 'Kéo Cắt đỏ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0160', 'Kẹp phơi', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0161', 'Lót nồi Aro', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0162', 'Muỗng nhân viên', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0163', 'Nhiệt kế đo chín bánh BG363', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0164', 'Nồi cao 2 quai Inox 30cm TQ 1 đáy', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0165', 'Nồi cơm Sharp 1010W', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0166', 'Nồi cơm Sharp R19ST', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0167', 'Nồi hầm inox 1D 5L26', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0168', 'Nồi Inox 2 quai 40*26 2 đáy East', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0169', 'Nồi inox 3D 18cm 25', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0170', 'Nồi Kim Hằng', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0171', 'Nồi nhôm HN 60 lít', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0172', 'Nồi sốt 240H80 1 quai Inox 2 đáy', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0173', 'Quạt đứng', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0174', 'Muỗng đo lường(Cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0175', 'Thùng nhựa (120l) đựng gạo', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0176', 'Thùng rác di động', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0177', 'Thùng rác mái nhà', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0178', 'Thùng rác nhựa 351', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0179', 'Bộ lưu tích điện TG500', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0180', 'Máy cắt thịt 30cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0181', 'Máy chế biến thực phẩm 5076 Pana', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0182', 'Máy đánh trứng Philips 1538', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0183', 'Máy xay thịt công nghiệp', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0184', 'Lò hầm soup (nắp PC) N5-LHAT52293', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0185', 'Lò nướng bánh mì băng chuyền', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0186', 'Lò nướng bề mặt Salamanda', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0187', 'Lò nướng đối lưu FC110EG', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0188', 'Lò nướng đối lưu model: BJY-E-CO28', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0189', 'Lò nướng lớn 60*80', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0190', 'Lò vi sóng Sharp 24A1', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0191', 'Tủ đông Alasca HB-650CC', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0192', 'Xe đẩy 3 tầng inox', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0193', 'giỏ đựng rác mây ( cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0194', 'Tô inox ( cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0195', 'Vá inox (cooking class)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0196', 'Hộp nhựa 2 quai (nhân viên)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0197', 'Tô 7 (VCP) (nhân viên)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0198', 'Chén flan nhỏ (Chuan Kuo)', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0199', 'Khuôn làm bánh silicon 8 lỗ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0200', 'Đồng hồ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0201', 'Dao 812', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0202', 'Dao 21', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0203', 'Dao 172', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0204', 'Dao nhí cán gỗ', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0205', 'Đá mài', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0206', 'Kẹp găp khóa 35cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0207', 'Kẹp găp khóa 40cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0208', 'May xay Panasonic', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0209', 'Cắt trứng inox', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0210', 'Xô inox 20cm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0211', 'Rắc tiêu inox', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0212', 'Khay nướng bánh mì lượng sóng', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0213', 'Khay nướng bánh nhôm', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0214', 'Máy xay cầm tay', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0215', 'Hủ pudding nhỏ', 'CCDC', 'hu', 'hu', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0216', 'Khay G/N 1/6 H100', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0217', 'Nắp khay 1/6', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0218', 'Nắp khay 1/2', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0219', 'Nắp khay 1/1', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0220', 'Cân 5 kg', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-CCDC-0221', 'Cân điện tử', 'CCDC', 'cai', 'cai', NULL, false, '{"f":"buffet-nvl","loai":"CCDC","code_gen":true}'::jsonb),
  ('SEED-TP-0110', 'Mì trứng', 'TP', 'goi', NULL, NULL, false, '{"f":"buffet-nvl","code_gen":true}'::jsonb)
  ) as v(code, name, group_prefix, stock_uom, recipe_uom, factor, is_key, ext)
  join public.item_groups g on g.org_id = v_org_id and g.code_prefix = v.group_prefix
  where not exists (
    select 1 from public.items i
    where i.org_id = v_org_id
      and (i.code = v.code or i.name_norm = public.norm_text(v.name))
  );
  get diagnostics v_n = row_count;
  raise notice '§3c. ITEMS — NVL buffet (phần 3/3): % dòng items mới', v_n;
end;
$seed$;

-- ============================================================================
-- §3d. ITEMS — Minibar (7 món) — ĐVT lon/chai suy ra từ loại hàng (file không ghi ĐVT); tên lấy từ tiêu đề cột, xem README §4
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.items (org_id, code, name, group_id, stock_uom, recipe_uom, stock_to_recipe, is_key_item, external_codes)
  select v_org_id, v.code, v.name, g.id, v.stock_uom, v.recipe_uom, v.factor, v.is_key, v.ext
  from (values
  ('MB-LARUE', 'Larue', 'MB', 'lon', NULL, NULL, false, '{"f":"minibar","hdr":"LARUE","note":"ĐVT (lon/chai) suy ra từ loại hàng — file không ghi ĐVT","sheet":"10.2018-11.2019"}'::jsonb),
  ('MB-TIGER', 'Tiger', 'MB', 'lon', NULL, NULL, false, '{"f":"minibar","hdr":"TIGER","note":"ĐVT (lon/chai) suy ra từ loại hàng — file không ghi ĐVT","sheet":"10.2018-11.2019"}'::jsonb),
  ('MB-COCA', 'Coca-Cola', 'MB', 'lon', NULL, NULL, false, '{"f":"minibar","hdr":"COCACOLA","note":"ĐVT (lon/chai) suy ra từ loại hàng — file không ghi ĐVT","sheet":"10.2018-11.2019"}'::jsonb),
  ('MB-DIETCOKE', 'Diet Coke', 'MB', 'lon', NULL, NULL, false, '{"f":"minibar","hdr":"DIET COKE","note":"ĐVT (lon/chai) suy ra từ loại hàng — file không ghi ĐVT","sheet":"10.2018-11.2019"}'::jsonb),
  ('MB-LAVIE', 'Lavie', 'MB', 'chai', NULL, NULL, false, '{"f":"minibar","hdr":"LAVIE chai","note":"ĐVT (lon/chai) suy ra từ loại hàng — file không ghi ĐVT","sheet":"10.2018-11.2019"}'::jsonb),
  ('MB-SPRITE', 'Sprite', 'MB', 'lon', NULL, NULL, false, '{"f":"minibar","hdr":"SPRITE","note":"ĐVT (lon/chai) suy ra từ loại hàng — file không ghi ĐVT","sheet":"10.2018-11.2019"}'::jsonb),
  ('MB-VANG', 'Rượu vang', 'MB', 'chai', NULL, NULL, false, '{"f":"minibar","hdr":"RƯỢU VANG","note":"ĐVT (lon/chai) suy ra từ loại hàng — file không ghi ĐVT","sheet":"10.2018-11.2019"}'::jsonb)
  ) as v(code, name, group_prefix, stock_uom, recipe_uom, factor, is_key, ext)
  join public.item_groups g on g.org_id = v_org_id and g.code_prefix = v.group_prefix
  where not exists (
    select 1 from public.items i
    where i.org_id = v_org_id
      and (i.code = v.code or i.name_norm = public.norm_text(v.name))
  );
  get diagnostics v_n = row_count;
  raise notice '§3d minibar items: % dòng mới', v_n;
end;
$seed$;

-- ============================================================================
-- §3e. ITEMS — Amenities tháng 5/2019 (12 món) — pcs → 'cai'; Nước dasani vào nhóm CPM (complimentary, KHÔNG phải minibar — theo T-035)
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.items (org_id, code, name, group_id, stock_uom, recipe_uom, stock_to_recipe, is_key_item, external_codes)
  select v_org_id, v.code, v.name, g.id, v.stock_uom, v.recipe_uom, v.factor, v.is_key, v.ext
  from (values
  ('AMN-GIAY-VS', 'Giấy vệ sinh', 'AMN', 'cuon', NULL, NULL, false, '{"f":"amenities","dvt":"cuộn","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-TRA-COZY', 'Trà cozy', 'AMN', 'goi', NULL, NULL, false, '{"f":"amenities","dvt":"gói","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-DUONG', 'Đường thẻ', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-CAPHE', 'Cà phê', 'AMN', 'goi', NULL, NULL, false, '{"f":"amenities","dvt":"gói","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-XAPHONG', 'Xà phòng cục', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-BANCHAI', 'Bàn chải', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-DAO', 'Dao cạo râu', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-TUIVS', 'Túi vệ sinh', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-LUOC', 'Lược', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-BONG', 'Bông quáy tai', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('AMN-CHUPTOC', 'Chụp tóc', 'AMN', 'cai', NULL, NULL, false, '{"f":"amenities","dvt":"pcs","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb),
  ('CPM-DASANI', 'Nước dasani', 'CPM', 'chai', NULL, NULL, false, '{"f":"amenities","dvt":"chai","sheet":"1.5-8.5 + 9.5.2019-31.5.2019 + SL sử dụng trong tháng 5.2019"}'::jsonb)
  ) as v(code, name, group_prefix, stock_uom, recipe_uom, factor, is_key, ext)
  join public.item_groups g on g.org_id = v_org_id and g.code_prefix = v.group_prefix
  where not exists (
    select 1 from public.items i
    where i.org_id = v_org_id
      and (i.code = v.code or i.name_norm = public.norm_text(v.name))
  );
  get diagnostics v_n = row_count;
  raise notice '§3e amenities items: % dòng mới', v_n;
end;
$seed$;

-- ============================================================================
-- §4. BẢNG GIÁ MINIBAR LỊCH SỬ (minibar_price_list) — giá = giá trị THƯỜNG GẶP NHẤT của (doanh thu tháng / số lượng bán tháng) trong 14 tháng; 9/83 ô tháng-món lệch (xem README §4). Chỉ có hiệu lực 01/10/2018–30/11/2019 nên KHÔNG áp cho phiếu kiểm 2026 — giá bán hiện hành phải nhập qua minibar_price_set (Q47)
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.minibar_price_list (org_id, property_id, item_id, price, valid_from, valid_to)
  select v_org_id, v_property_id, i.id, v.price, date '2018-10-01', date '2019-11-30'
  from (values
  ('MB-LARUE', 25000),
  ('MB-TIGER', 35000),
  ('MB-COCA', 25000),
  ('MB-DIETCOKE', 25000),
  ('MB-LAVIE', 15000),
  ('MB-SPRITE', 25000),
  ('MB-VANG', 245000)
  ) as v(code, price)
  join public.items i on i.org_id = v_org_id and i.code = v.code
  where not exists (
    select 1 from public.minibar_price_list p
    where p.property_id = v_property_id and p.item_id = i.id and p.valid_from = date '2018-10-01'
  );
  get diagnostics v_n = row_count;
  raise notice '§4 minibar_price_list: % dòng mới (kỳ vọng 7)', v_n;
end;
$seed$;

-- ============================================================================
-- §5. CHUẨN SETUP PHÒNG (room_setup_standards) — qty = số lượng dùng tháng 5/2019 / 1.175 phòng (làm tròn 4 chữ số); chỉ clean_type 'checkout', per_guest=false. Nếu property chưa có room_types thì 0 dòng — tạo loại phòng trước rồi chạy lại khối này (idempotent). Giá trị là ĐỊNH MỨC THAM KHẢO, cần buồng phòng xác nhận (Q159)
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.room_setup_standards (org_id, property_id, room_type_id, clean_type, item_id, qty, per_guest)
  select v_org_id, v_property_id, rt.id, 'checkout', i.id, v.qty, false
  from (values
  ('AMN-GIAY-VS', 0.7174),
  ('AMN-TRA-COZY', 0.4868),
  ('AMN-DUONG', 0.3906),
  ('AMN-CAPHE', 0.7736),
  ('AMN-XAPHONG', 0.3753),
  ('AMN-BANCHAI', 0.8868),
  ('AMN-DAO', 0.0196),
  ('AMN-TUIVS', 0.2826),
  ('AMN-LUOC', 0.3191),
  ('AMN-BONG', 0.4043),
  ('AMN-CHUPTOC', 0.2298),
  ('CPM-DASANI', 1.9396)
  ) as v(code, qty)
  join public.items i on i.org_id = v_org_id and i.code = v.code
  join public.room_types rt on rt.property_id = v_property_id
  on conflict (room_type_id, clean_type, item_id, per_guest) do nothing;
  get diagnostics v_n = row_count;
  raise notice '§5 room_setup_standards: % dòng mới (kỳ vọng 12 x số loại phòng)', v_n;
end;
$seed$;

-- ============================================================================
-- §6. MỨC PAR XE ĐẨY (trolley_par_levels) — par_qty = lượng XUẤT lên xe lớn nhất 1 ngày trong tháng 5/2019 (sheet 9.5–31.5). Nếu property chưa có kho kind='trolley' thì 0 dòng — tạo xe đẩy trước rồi chạy lại khối này (idempotent). Giá trị là THAM KHẢO, cần giám sát buồng xác nhận (Q159)
-- ============================================================================
do $seed$
declare
  v_org_id uuid := current_setting('seed.org_id')::uuid;
  v_property_id uuid := current_setting('seed.property_id')::uuid;
  v_n integer;
begin
  insert into public.trolley_par_levels (org_id, property_id, trolley_warehouse_id, item_id, par_qty)
  select v_org_id, v_property_id, w.id, i.id, v.par_qty
  from (values
  ('AMN-GIAY-VS', 62),
  ('AMN-TRA-COZY', 100),
  ('AMN-DUONG', 100),
  ('AMN-CAPHE', 100),
  ('AMN-XAPHONG', 60),
  ('AMN-BANCHAI', 110),
  ('AMN-DAO', 6),
  ('AMN-TUIVS', 60),
  ('AMN-LUOC', 60),
  ('AMN-BONG', 60),
  ('AMN-CHUPTOC', 60),
  ('CPM-DASANI', 125)
  ) as v(code, par_qty)
  join public.items i on i.org_id = v_org_id and i.code = v.code
  join public.warehouses w on w.property_id = v_property_id and w.kind = 'trolley'
  on conflict (trolley_warehouse_id, item_id) do nothing;
  get diagnostics v_n = row_count;
  raise notice '§6 trolley_par_levels: % dòng mới (kỳ vọng 12 x số xe đẩy)', v_n;
end;
$seed$;

-- ============================================================================
-- §7. TRUY VẤN KIỂM TRA (chạy sau khi seed — thay UUID nếu đã sửa §0)
-- ============================================================================
-- 7.1 Tổng items theo nhóm (kỳ vọng: TP 409, CCDC 235, MB 7, AMN 11, CPM 1, KHAC 5; tổng 668)
select g.code_prefix as nhom, count(*) as so_dong
from public.items i join public.item_groups g on g.id = i.group_id
where i.org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71'
group by g.code_prefix order by g.code_prefix;
-- 7.2 Đếm items do seed này tạo (mã SEED-/MB-/AMN-/CPM-; NVL giữ mã gốc nên đếm theo external_codes)
select count(*) as items_seed from public.items
where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and external_codes ->> 'f' in ('buffet-nvl', 'minibar', 'amenities');
-- 7.3 Giá minibar lịch sử (kỳ vọng 7 dòng)
select i.code, i.name, p.price, p.valid_from, p.valid_to
from public.minibar_price_list p join public.items i on i.id = p.item_id
where p.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' order by i.code;
-- 7.4 Chuẩn setup phòng (kỳ vọng 12 dòng / 1 loại phòng; 0 dòng = chưa có room_types)
select rt.code as loai_phong, i.code, i.name, s.qty, s.clean_type, s.per_guest
from public.room_setup_standards s
join public.room_types rt on rt.id = s.room_type_id
join public.items i on i.id = s.item_id
where s.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' order by rt.code, i.code;
-- 7.5 Par xe đẩy (kỳ vọng 12 dòng / 1 xe; 0 dòng = chưa có kho trolley)
select w.code as xe_day, i.code, i.name, t.par_qty
from public.trolley_par_levels t
join public.warehouses w on w.id = t.trolley_warehouse_id
join public.items i on i.id = t.item_id
where t.property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' order by w.code, i.code;
-- 7.6 Loại phòng + xe đẩy hiện có của property (giải thích khi 7.4/7.5 = 0 dòng)
select 'room_type' as loai, code, name from public.room_types where property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b'
union all
select 'warehouse:' || kind, code, name from public.warehouses where property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' order by 1, 2;
-- 7.7 Tồn kho KHÔNG bị động vào (kỳ vọng 0 — seed này không ghi stock_moves/balances)
select count(*) as stock_moves_cua_seed_items
from public.stock_moves m
where m.item_id in (select id from public.items where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and external_codes ->> 'f' in ('buffet-nvl', 'minibar', 'amenities'));

-- ============================================================================
-- ROLLBACK (chỉ chạy khi cần gỡ TOÀN BỘ seed này — chạy từng dòng, theo thứ tự)
-- ----------------------------------------------------------------------------
-- delete from public.trolley_par_levels where property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and item_id in (select id from public.items where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and external_codes ->> 'f' = 'amenities');
-- delete from public.room_setup_standards where property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and item_id in (select id from public.items where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and external_codes ->> 'f' = 'amenities');
-- delete from public.minibar_price_list where property_id = '7e37858d-58ed-4924-bb8f-9d56be9c620b' and valid_from = date '2018-10-01';
-- delete from public.items where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and external_codes ->> 'f' in ('buffet-nvl', 'minibar', 'amenities');
-- -- Nhóm KHAC chỉ xóa khi không còn item nào dùng (kiểm tra trước):
-- -- delete from public.item_groups where org_id = '00dc6aeb-5e34-4e01-9b80-032a72b16d71' and code_prefix = 'KHAC' and not exists (select 1 from public.items where group_id = public.item_groups.id);
-- -- UoM: KHÔNG xóa (dùng chung toàn hệ thống, các mã đã có từ migration).
-- -- LƯU Ý: audit_log giữ lại dấu vết INSERT (đúng thiết kế sổ cái bất biến).
-- ============================================================================
