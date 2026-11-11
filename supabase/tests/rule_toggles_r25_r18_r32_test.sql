-- Q214: pgTAP cho co che bat/tat rang buoc (rule toggles) R25 / R18 / R32.
-- Moi ma 2 truong hop: co BAT (mac dinh) -> chan dung ma loi cu; co TAT
-- -> cho qua (R32 assert them co alert sinh ra).
-- Co duoc set truc tiep bang upsert vao bang settings (chay bang postgres
-- trong SQL Editor nen qua duoc RLS); day la cach test, khong phai cach
-- van hanh — van hanh dung /admin/settings (admin_setting_save).
-- Luu y: settings.value la jsonb number (0 = tat / 1 = bat); test chi
-- dung 0/1 vi CHECK cua bang chan kieu khac.
-- R32 dong ky 2026-10 (khong phai 2026-11): moi kho fixture deu tao o
-- thang 11/2026 nen dieu kien kiem ke thang (ERR_COUNT_NOT_LOCKED) duoc
-- mien nhien cho ky 10/2026, chi con 2 dieu kien PO/tam ung de test.
-- Tat ca insert fixture chay bang postgres (truoc `set local role
-- authenticated`) de qua RLS; cac lenh doc alerts cung dung
-- `set local role postgres` vi role fixture khong co quyen
-- alert.receive.period_close_warning.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);

-- ---------------------------------------------------------------------------
-- Fixture (prefix d9e50000). Chay bang postgres.
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('d9e50000-0000-4000-8000-000000000001', 'Rule Toggles Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('d9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000001', 'RT', 'Entity RT');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('d9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'PRT', 'Property RT', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('d9e50000-0000-4000-8000-000000000401', 'd9e50000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food'),
  ('d9e50000-0000-4000-8000-000000000403', 'd9e50000-0000-4000-8000-000000000001', 'MUOI', 'Muối', 'other');
insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, allowed_channels) values
  ('d9e50000-0000-4000-8000-000000000501', 'd9e50000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'd9e50000-0000-4000-8000-000000000401', 'kg', true, false, array['contract', 'market']),
  ('d9e50000-0000-4000-8000-000000000503', 'd9e50000-0000-4000-8000-000000000001', 'ITM_MUOI', 'Muối hạt', 'd9e50000-0000-4000-8000-000000000403', 'kg', false, false, array['contract', 'market']);
insert into public.warehouses (id, property_id, code, name, kind) values
  ('d9e50000-0000-4000-8000-000000000301', 'd9e50000-0000-4000-8000-000000000201', 'WH_A', 'Kho A', 'main'),
  ('d9e50000-0000-4000-8000-000000000302', 'd9e50000-0000-4000-8000-000000000201', 'WH_B', 'Kho B', 'main'),
  ('d9e50000-0000-4000-8000-000000000303', 'd9e50000-0000-4000-8000-000000000201', 'WH_R18', 'Kho nhận', 'main');
insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, qty) values
  ('d9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000301', 'd9e50000-0000-4000-8000-000000000501', 100),
  ('d9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000301', 'd9e50000-0000-4000-8000-000000000503', 50),
  ('d9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000302', 'd9e50000-0000-4000-8000-000000000501', 100),
  ('d9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000302', 'd9e50000-0000-4000-8000-000000000503', 50);
insert into public.item_costs (legal_entity_id, org_id, item_id, avg_cost, qty_on_hand) values
  ('d9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000501', 10000, 110),
  ('d9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000503', 5000, 60);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('d9e50000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rt1@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e50000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rt2@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d9e50000-0000-4000-8000-000000000a07', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rt7@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('d9e50000-0000-4000-8000-000000000a01', 'NVRT01', 'Thủ kho'),
  ('d9e50000-0000-4000-8000-000000000a02', 'NVRT02', 'Bếp trưởng'),
  ('d9e50000-0000-4000-8000-000000000a07', 'NVRT07', 'Kế toán trưởng')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;
update public.profiles
set pin_hash = extensions.crypt('1111', extensions.gen_salt('bf'))
where id = 'd9e50000-0000-4000-8000-000000000a01';
update public.profiles
set pin_hash = extensions.crypt('2222', extensions.gen_salt('bf'))
where id = 'd9e50000-0000-4000-8000-000000000a02';
insert into public.roles (id, org_id, code, name_vi) values
  ('d9e50000-0000-4000-8000-000000000601', 'd9e50000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('d9e50000-0000-4000-8000-000000000602', 'd9e50000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('d9e50000-0000-4000-8000-000000000607', 'd9e50000-0000-4000-8000-000000000001', 'chief_accountant', 'Kế toán trưởng');
insert into public.role_permissions (role_id, permission_code) values
  ('d9e50000-0000-4000-8000-000000000601', 'count.open'),
  ('d9e50000-0000-4000-8000-000000000601', 'count.perform'),
  ('d9e50000-0000-4000-8000-000000000601', 'receiving.post'),
  ('d9e50000-0000-4000-8000-000000000602', 'count.perform'),
  ('d9e50000-0000-4000-8000-000000000607', 'period.close');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d9e50000-0000-4000-8000-000000000a01', 'd9e50000-0000-4000-8000-000000000601', 'd9e50000-0000-4000-8000-000000000201'),
  ('d9e50000-0000-4000-8000-000000000a02', 'd9e50000-0000-4000-8000-000000000602', 'd9e50000-0000-4000-8000-000000000201'),
  ('d9e50000-0000-4000-8000-000000000a07', 'd9e50000-0000-4000-8000-000000000607', null);
-- R18: 1 PO 2 dong + 2 phieu nhan (moi phieu 1 dong + 1 anh).
select set_config('app.pr_po_guard_bypass', 'on', true);
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, advance_id, status, created_by, doc_no) values
  ('d9e50000-0000-4000-8000-000000000b01', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', null, 'contract', 'stock', '2026-11-09', '2026-11-20', null, 'approved', 'd9e50000-0000-4000-8000-000000000a07', 'PO-RT-001');
insert into public.purchase_order_lines (id, po_id, org_id, item_id, qty, uom, qty_stock, unit_price, price_source, received_qty_stock) values
  ('d9e50000-0000-4000-8000-000000000b11', 'd9e50000-0000-4000-8000-000000000b01', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000501', 10, 'kg', 10, 10000, 'manual', 0),
  ('d9e50000-0000-4000-8000-000000000b12', 'd9e50000-0000-4000-8000-000000000b01', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000503', 10, 'kg', 10, 5000, 'manual', 0);
select set_config('app.pr_po_guard_bypass', 'off', true);
select set_config('app.receiving_guard_bypass', 'on', true);
insert into public.goods_receipts (id, org_id, legal_entity_id, property_id, po_id, warehouse_id, doc_no, receiver_id, status) values
  ('d9e50000-0000-4000-8000-000000000c01', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000b01', 'd9e50000-0000-4000-8000-000000000303', 'GR-RT-A', 'd9e50000-0000-4000-8000-000000000a01', 'draft'),
  ('d9e50000-0000-4000-8000-000000000c02', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000b01', 'd9e50000-0000-4000-8000-000000000303', 'GR-RT-B', 'd9e50000-0000-4000-8000-000000000a01', 'draft');
insert into public.goods_receipt_lines (id, gr_id, org_id, property_id, po_line_id, item_id, gross_qty, tare_qty, uom, net_qty_stock, accepted_qty_stock, qc_status, weigh_count, needs_reweigh) values
  ('d9e50000-0000-4000-8000-000000000c11', 'd9e50000-0000-4000-8000-000000000c01', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000b11', 'd9e50000-0000-4000-8000-000000000501', 10, 0, 'kg', 10, 10, 'pass', 1, false),
  ('d9e50000-0000-4000-8000-000000000c12', 'd9e50000-0000-4000-8000-000000000c02', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000b12', 'd9e50000-0000-4000-8000-000000000503', 10, 0, 'kg', 10, 10, 'pass', 1, false);
select set_config('app.receiving_guard_bypass', 'off', true);
insert into public.attachments (id, org_id, legal_entity_id, property_id, bucket, path, sha256, doc_type, doc_id, uploaded_by) values
  ('d9e50000-0000-4000-8000-000000000d01', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'evidence', 'rt/gr-a.jpg', repeat('ab', 32), 'receiving', 'd9e50000-0000-4000-8000-000000000c01', 'd9e50000-0000-4000-8000-000000000a01'),
  ('d9e50000-0000-4000-8000-000000000d02', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'evidence', 'rt/gr-b.jpg', repeat('cd', 32), 'receiving', 'd9e50000-0000-4000-8000-000000000c02', 'd9e50000-0000-4000-8000-000000000a01');
-- R32: 1 PO treo qua 30 ngay + 1 tam ung overdue.
insert into public.purchase_orders (id, org_id, legal_entity_id, property_id, supplier_id, channel, kind, order_date, expected_date, advance_id, status, created_by, doc_no) values
  ('d9e50000-0000-4000-8000-000000000b02', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', null, 'contract', 'stock', '2026-08-15', '2026-09-01', null, 'partially_received', 'd9e50000-0000-4000-8000-000000000a07', 'PO-RT-002');
select set_config('app.advance_guard_bypass', 'on', true);
insert into public.advances (id, org_id, legal_entity_id, property_id, employee_id, doc_no, amount, purpose, status) values
  ('d9e50000-0000-4000-8000-000000000e01', 'd9e50000-0000-4000-8000-000000000001', 'd9e50000-0000-4000-8000-000000000101', 'd9e50000-0000-4000-8000-000000000201', 'd9e50000-0000-4000-8000-000000000a01', 'ADV-RT-001', 1000000, 'Đi chợ', 'overdue');
select set_config('app.advance_guard_bypass', 'off', true);
create temp table rt_ctx (key text primary key, id uuid);
create temp table rt_resp (key text primary key, resp jsonb);
grant all on rt_ctx, rt_resp to authenticated;
create or replace function public._rt_as(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
end;
$$;
-- SECURITY DEFINER de qua RLS bang settings (test goi duoi role authenticated).
create or replace function public._rt_set_flag(
  p_key text,
  p_value numeric,
  p_property_id uuid
)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  insert into public.settings (org_id, property_id, key, value, updated_by)
  values (
    'd9e50000-0000-4000-8000-000000000001',
    p_property_id,
    p_key,
    to_jsonb(p_value),
    'd9e50000-0000-4000-8000-000000000a01'
  )
  on conflict (org_id, property_id, key) do update
    set value = excluded.value;
$$;
set local role authenticated;

-- ---------------------------------------------------------------------------
-- §0. _rule_enabled: mac dinh + fallback property -> org.
-- ---------------------------------------------------------------------------
select is(
  public._rule_enabled('d9e50000-0000-4000-8000-000000000201', 'R25'),
  true, 'R25 mac dinh BAT khi chua co dong settings nao'
);
select is(
  public._rule_enabled('d9e50000-0000-4000-8000-000000000201', 'R18'),
  true, 'R18 mac dinh BAT khi chua co dong settings nao'
);
select is(
  public._rule_enabled('d9e50000-0000-4000-8000-000000000201', 'R32'),
  true, 'R32 mac dinh BAT khi chua co dong settings nao'
);
select is(
  public._rule_enabled('d9e50000-0000-4000-8000-000000000201', 'R99'),
  true, 'ma co la tra BAT (fail closed)'
);
select is(
  public._rule_enabled(null, 'R25'),
  true, 'property null tra BAT (fail closed)'
);
select public._rt_set_flag('rule.R25.enabled', 0, null);
select is(
  public._rule_enabled('d9e50000-0000-4000-8000-000000000201', 'R25'),
  false, 'dong org 0 -> TAT khi chua co dong property'
);
select public._rt_set_flag('rule.R25.enabled', 1, 'd9e50000-0000-4000-8000-000000000201');
select is(
  public._rule_enabled('d9e50000-0000-4000-8000-000000000201', 'R25'),
  true, 'dong property 1 ghi de dong org 0 -> BAT'
);
select public._rt_set_flag('rule.R25.enabled', 0, 'd9e50000-0000-4000-8000-000000000201');
select is(
  public._rule_enabled('d9e50000-0000-4000-8000-000000000201', 'R25'),
  false, 'dong property 0 -> TAT'
);

-- ---------------------------------------------------------------------------
-- §1. R25 — PIN nop phieu kiem ke.
-- ---------------------------------------------------------------------------
select public._rt_set_flag('rule.R25.enabled', 1, 'd9e50000-0000-4000-8000-000000000201');
select public._rt_as('d9e50000-0000-4000-8000-000000000a01');
insert into rt_resp values ('openOn', public.count_open(
  'd9e50000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
  array['d9e50000-0000-4000-8000-000000000a01', 'd9e50000-0000-4000-8000-000000000a02']::uuid[]
));
insert into rt_ctx values ('cntOn', (select (resp ->> 'id')::uuid from rt_resp where key = 'openOn'));
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOn'),
  'd9e50000-0000-4000-8000-000000000501',
  '{"qty": 100, "uom": "kg"}'::jsonb
);
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOn'),
  'd9e50000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._rt_as('d9e50000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOn'),
  'd9e50000-0000-4000-8000-000000000501',
  '{"qty": 100, "uom": "kg"}'::jsonb
);
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOn'),
  'd9e50000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._rt_as('d9e50000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_submit(
    (select id from rt_ctx where key = 'cntOn'),
    array['1111']
  )$q$,
  'P0001', 'ERR_PIN_INVALID',
  'R25 BAT: nop chi 1 PIN bi chan'
);
select public._rt_set_flag('rule.R25.enabled', 0, 'd9e50000-0000-4000-8000-000000000201');
insert into rt_resp values ('openOff', public.count_open(
  'd9e50000-0000-4000-8000-000000000302', 'monthly_full', '2026-11-09', null,
  array['d9e50000-0000-4000-8000-000000000a01', 'd9e50000-0000-4000-8000-000000000a02']::uuid[]
));
insert into rt_ctx values ('cntOff', (select (resp ->> 'id')::uuid from rt_resp where key = 'openOff'));
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOff'),
  'd9e50000-0000-4000-8000-000000000501',
  '{"qty": 100, "uom": "kg"}'::jsonb
);
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOff'),
  'd9e50000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._rt_as('d9e50000-0000-4000-8000-000000000a02');
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOff'),
  'd9e50000-0000-4000-8000-000000000501',
  '{"qty": 100, "uom": "kg"}'::jsonb
);
select public.count_record_line(
  (select id from rt_ctx where key = 'cntOff'),
  'd9e50000-0000-4000-8000-000000000503',
  '{"qty": 50, "uom": "kg"}'::jsonb
);
select public._rt_as('d9e50000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.count_submit(
    (select id from rt_ctx where key = 'cntOff'),
    array['9999']
  )$q$,
  'P0001', 'ERR_PIN_INVALID',
  'R25 TAT: PIN nguoi nop sai van bi chan'
);
insert into rt_resp values ('submitOff', public.count_submit(
  (select id from rt_ctx where key = 'cntOff'),
  array['1111']
));
select ok(
  (select (resp ->> 'ok')::boolean from rt_resp where key = 'submitOff'),
  'R25 TAT: nop chi PIN nguoi nop thi cho qua'
);
select is(
  (select status from public.stock_counts where id = (select id from rt_ctx where key = 'cntOff')),
  'submitted', 'phieu TAT chuyen submitted sau khi nop 1 PIN'
);

-- ---------------------------------------------------------------------------
-- §2. R18 — PIN post phieu nhan.
-- ---------------------------------------------------------------------------
select public._rt_set_flag('rule.R18.enabled', 1, 'd9e50000-0000-4000-8000-000000000201');
select public._rt_as('d9e50000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.receiving_post('d9e50000-0000-4000-8000-000000000c01', '0000')$q$,
  'P0001', 'ERR_PIN_INVALID',
  'R18 BAT: post sai PIN bi chan'
);
select public._rt_set_flag('rule.R18.enabled', 0, 'd9e50000-0000-4000-8000-000000000201');
insert into rt_resp values ('postOff', public.receiving_post('d9e50000-0000-4000-8000-000000000c02', '0000'));
select ok(
  (select (resp ->> 'ok')::boolean from rt_resp where key = 'postOff'),
  'R18 TAT: post sai PIN van cho qua'
);
select is(
  (select (resp ->> 'lines_posted')::int from rt_resp where key = 'postOff'),
  1, 'R18 TAT: post duoc 1 dong'
);
set local role postgres;
select is(
  (select status from public.goods_receipts where id = 'd9e50000-0000-4000-8000-000000000c02'),
  'posted', 'phieu TAT chuyen posted'
);
set local role authenticated;

-- ---------------------------------------------------------------------------
-- §3. R32 — chan dong ky khi con PO treo / tam ung qua han.
-- ---------------------------------------------------------------------------
select public._rt_as('d9e50000-0000-4000-8000-000000000a07');
select throws_ok(
  $q$select public.period_close('d9e50000-0000-4000-8000-000000000101', 2026, 10)$q$,
  'P0001', 'ERR_PO_UNRESOLVED',
  'R32 BAT: dong ky 10/2026 bi chan vi PO treo qua 30 ngay'
);
select public._rt_set_flag('rule.R32.enabled', 0, 'd9e50000-0000-4000-8000-000000000201');
set local role postgres;
insert into rt_resp values ('alerts_before', jsonb_build_object('n', (select count(*) from public.alerts where code = 'PERIOD_CLOSE_WARNING')));
set local role authenticated;
select public._rt_as('d9e50000-0000-4000-8000-000000000a07');
insert into rt_resp values ('pclose', public.period_close('d9e50000-0000-4000-8000-000000000101', 2026, 10));
select ok(
  (select (resp ->> 'ok')::boolean from rt_resp where key = 'pclose'),
  'R32 TAT: dong ky 10/2026 cho qua'
);
set local role postgres;
insert into rt_resp values ('alerts_after', jsonb_build_object('n', (select count(*) from public.alerts where code = 'PERIOD_CLOSE_WARNING')));
insert into rt_resp values ('alert_po', jsonb_build_object('n', (select count(*) from public.alerts where code = 'PERIOD_CLOSE_WARNING' and payload ->> 'reason' = 'po_unresolved')));
insert into rt_resp values ('alert_adv', jsonb_build_object('n', (select count(*) from public.alerts where code = 'PERIOD_CLOSE_WARNING' and payload ->> 'reason' = 'advance_overdue')));
set local role authenticated;
select is(
  (select ((resp ->> 'n')::int from rt_resp where key = 'alerts_after')
    - ((resp ->> 'n')::int from rt_resp where key = 'alerts_before')),
  2, 'R32 TAT: sinh dung 2 alert PERIOD_CLOSE_WARNING (1 PO + 1 tam ung)'
);
select is(
  (select (resp ->> 'n')::int from rt_resp where key = 'alert_po'),
  1, 'R32 TAT: co alert ly do po_unresolved'
);
select is(
  (select (resp ->> 'n')::int from rt_resp where key = 'alert_adv'),
  1, 'R32 TAT: co alert ly do advance_overdue'
);

select finish();
rollback;
