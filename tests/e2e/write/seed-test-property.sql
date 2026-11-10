-- Seed property test T047 cho tang ghi Playwright (T-047).
--
-- CHAY BANG TAY trong Supabase SQL Editor (nut "Run"), CHI 1 LAN tren
-- production — tao property + phap nhan + danh muc TOI THIEU cho test.
-- Idempotent: chay lai khong tao trung (ON CONFLICT DO NOTHING / NOT EXISTS).
-- KHONG cham du lieu that SONHOIAN; property test co code TEST47 rieng.
-- Sau khi chay: tao 2 tai khoan test o /admin/users (xem tests/e2e/README.md)
--   * Nguoi tao (vai tro purchaser — tao PR/PO, nhan hang khong duoc)
--   * Nguoi duyet (vai tro outlet_head + receiver — duyet PR/PO, nhan hang)
-- va gan ca 2 vao property TEST47.
-- next_doc_no() tu tao dong doc_sequences nen khong can seed so chung tu.

do $$
declare
  v_org uuid := '00dc6aeb-5e34-4e01-9b80-032a72b16d71'; -- org that (SONHOIAN)
  v_admin uuid := '57f9ab84-ff5e-402d-b5b8-7f5f7cb798be'; -- dnduy@hueic.edu.vn (set_by gia tran)
  v_le uuid := 'b0000000-0000-4000-8000-000000000001';
  v_property uuid := 'b0000000-0000-4000-8000-000000000002';
  v_group uuid := 'b0000000-0000-4000-8000-000000000003';
  v_item1 uuid := 'b0000000-0000-4000-8000-000000000011';
  v_item2 uuid := 'b0000000-0000-4000-8000-000000000012';
  v_outlet uuid := 'b0000000-0000-4000-8000-000000000021';
  v_warehouse uuid := 'b0000000-0000-4000-8000-000000000022';
  v_supplier uuid := 'b0000000-0000-4000-8000-000000000031';
  v_outlet_type uuid;
  v_cost_center uuid;
  v_expense_cat uuid;
begin
  -- Phap nhan + property test (moving_avg — tranh loi FIFO o minibar, Q58).
  insert into public.legal_entities (id, org_id, code, name, costing_method, accounting_regime)
  values (v_le, v_org, 'TEST47-LE', 'Pháp nhân test T047', 'moving_avg', 'TT99')
  on conflict do nothing;

  insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile, rooms_count)
  values (v_property, v_org, v_le, 'TEST47', 'Khách sạn test T047', 'with_cc', 20)
  on conflict do nothing;

  -- Don vi tinh (ma chi cho a-z0-9_).
  insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
  insert into public.uoms (code, name_vi) values ('cai', 'Cái') on conflict do nothing;

  -- Nhom vat tu kind='other' (khong phai 'food') + is_key_item=false
  -- nen nhan hang KHONG bat buoc chup anh (xem _receiving_photo_required).
  insert into public.item_groups (id, org_id, code_prefix, name, kind)
  values (v_group, v_org, 'T047', 'Nhóm test T047', 'other')
  on conflict do nothing;

  -- Vat tu that lay tu file Excel cua Duy (Lst_2020_DL_Buffet.xlsx, sheet NVL).
  insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot)
  values (v_item1, v_org, 'NVL0388', 'ba chỉ nách', v_group, 'kg', false, false)
  on conflict do nothing;
  insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot)
  values (v_item2, v_org, 'NVL0561', 'Bánh bèo', v_group, 'cai', false, false)
  on conflict do nothing;

  -- Loai outlet / trung tam chi phi / khoan muc chi phi.
  insert into public.outlet_types (org_id, code, name)
  values (v_org, 'REST', 'Nhà hàng') on conflict do nothing;
  select id into v_outlet_type from public.outlet_types where org_id = v_org and code = 'REST';

  insert into public.cost_centers (org_id, code, name)
  values (v_org, 'CC-T047', 'Trung tâm chi phí T047') on conflict do nothing;
  select id into v_cost_center from public.cost_centers where org_id = v_org and code = 'CC-T047';

  insert into public.expense_categories (org_id, code, name)
  values (v_org, 'EC-T047', 'Chi phí test T047') on conflict do nothing;
  select id into v_expense_cat from public.expense_categories where org_id = v_org and code = 'EC-T047';

  -- Outlet + kho chinh (kind='main' moi nhan duoc).
  insert into public.outlets (id, property_id, outlet_type_id, cost_center_id, code, name)
  values (v_outlet, v_property, v_outlet_type, v_cost_center, 'NH-T047', 'Nhà hàng T047')
  on conflict do nothing;

  insert into public.warehouses (id, property_id, code, name, kind)
  values (v_warehouse, v_property, 'KHO-T047', 'Kho chính T047', 'main')
  on conflict do nothing;

  -- NCC active (don mua chi chon NCC active).
  insert into public.suppliers (id, org_id, code, name, kind, status)
  values (v_supplier, v_org, 'NCC-T047', 'NCC T047', 'company', 'active')
  on conflict do nothing;

  -- Gia tran: dong PO lay gia tu day (agreement -> ceiling -> tay).
  insert into public.ceiling_prices (org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by)
  select v_org, null, v_item1, 'kg', 100000, current_date - 30, current_date + 365, v_admin
  where not exists (
    select 1 from public.ceiling_prices
    where item_id = v_item1 and uom = 'kg' and valid_to >= current_date
  );
  insert into public.ceiling_prices (org_id, property_id, item_id, uom, price, valid_from, valid_to, set_by)
  select v_org, null, v_item2, 'cai', 5000, current_date - 30, current_date + 365, v_admin
  where not exists (
    select 1 from public.ceiling_prices
    where item_id = v_item2 and uom = 'cai' and valid_to >= current_date
  );
end $$;

-- Kiem chung (ky vong: moi dong = 1, tru uoms/outlet_types co the da co san).
select 'legal_entity' as bang, count(*) as so_dong from public.legal_entities where code = 'TEST47-LE'
union all select 'property', count(*) from public.properties where code = 'TEST47'
union all select 'item_group', count(*) from public.item_groups where code_prefix = 'T047'
union all select 'item', count(*) from public.items where code in ('NVL0388', 'NVL0561')
union all select 'outlet', count(*) from public.outlets where code = 'NH-T047'
union all select 'warehouse', count(*) from public.warehouses where code = 'KHO-T047'
union all select 'supplier', count(*) from public.suppliers where code = 'NCC-T047'
union all select 'ceiling_price', count(*) from public.ceiling_prices where item_id in (
  select id from public.items where code in ('NVL0388', 'NVL0561')
);
