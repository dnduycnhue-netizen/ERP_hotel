-- audit_triggers_business_tables_test.sql
--
-- Q213: kiem chung migration 20261109536000_audit_triggers_business_tables.
--   §0: 16 bang bat buoc deu co trigger trg_<bang>_audit tro dung
--       public.audit_trigger(); 8 bang bo qua KHONG co trigger audit.
--   §1-§5: 5 bang dai dien (profiles, purpose_issues, requisitions,
--       stock_counts, transfers): ghi 1 dong qua RPC roi kiem tra co DUNG
--       1 dong audit_log moi voi actor = auth.uid() va dung table/row_id.
--
-- CHI chay file nay sau khi db push migration 536000. Khong chay ca bo.
-- Chay trong 1 transaction begin...rollback; khong ghi gi len production.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(40);

-- ---------------------------------------------------------------------------
-- Fixture: prefix a7d00000 (audit).
-- ---------------------------------------------------------------------------
insert into public.organizations (id, name) values
  ('a7d00000-0000-4000-8000-000000000001', 'A7D Audit Org');
insert into public.legal_entities (id, org_id, code, name) values
  ('a7d00000-0000-4000-8000-000000000101', 'a7d00000-0000-4000-8000-000000000001', 'A7D', 'Entity A7D');
insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('a7d00000-0000-4000-8000-000000000201', 'a7d00000-0000-4000-8000-000000000001', 'a7d00000-0000-4000-8000-000000000101', 'PA7D', 'Property A7D', 'with_cc');
insert into public.uoms (code, name_vi) values ('kg', 'Kilôgam') on conflict do nothing;
insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('a7d00000-0000-4000-8000-000000000401', 'a7d00000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');
insert into public.items (id, org_id, code, name, group_id, stock_uom) values
  ('a7d00000-0000-4000-8000-000000000501', 'a7d00000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'a7d00000-0000-4000-8000-000000000401', 'kg');
insert into public.outlet_types (id, org_id, code, name) values
  ('a7d00000-0000-4000-8000-000000000801', 'a7d00000-0000-4000-8000-000000000001', 'KIT', 'Bếp');
insert into public.outlets (id, property_id, outlet_type_id, code, name) values
  ('a7d00000-0000-4000-8000-000000000802', 'a7d00000-0000-4000-8000-000000000201', 'a7d00000-0000-4000-8000-000000000801', 'KITCHEN', 'Bếp chính');
insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('a7d00000-0000-4000-8000-000000000301', 'a7d00000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null),
  ('a7d00000-0000-4000-8000-000000000302', 'a7d00000-0000-4000-8000-000000000201', 'WH_OUT', 'Kho bếp', 'outlet', 'a7d00000-0000-4000-8000-000000000802');
insert into public.cost_centers (id, org_id, code, name) values
  ('a7d00000-0000-4000-8000-000000000901', 'a7d00000-0000-4000-8000-000000000001', 'FB', 'F&B');
insert into public.expense_categories (id, org_id, code, name) values
  ('a7d00000-0000-4000-8000-000000000902', 'a7d00000-0000-4000-8000-000000000001', 'FOOD', 'Thực phẩm');
insert into public.stock_balances (org_id, legal_entity_id, property_id, warehouse_id, item_id, qty) values
  ('a7d00000-0000-4000-8000-000000000001', 'a7d00000-0000-4000-8000-000000000101', 'a7d00000-0000-4000-8000-000000000201', 'a7d00000-0000-4000-8000-000000000301', 'a7d00000-0000-4000-8000-000000000501', 10);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data) values
  ('a7d00000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-a7d@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a7d00000-0000-4000-8000-000000000a02', '00000000-0000-4000-0000-000000000000', 'authenticated', 'authenticated', 'u2-a7d@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('a7d00000-0000-4000-8000-000000000a03', '00000000-0000-4000-0000-000000000000', 'authenticated', 'authenticated', 'u3-a7d@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);
insert into public.profiles (id, employee_code, full_name) values
  ('a7d00000-0000-4000-8000-000000000a01', 'NV A7D01', 'Thủ kho'),
  ('a7d00000-0000-4000-8000-000000000a02', 'NV A7D02', 'Bếp trưởng'),
  ('a7d00000-0000-4000-8000-000000000a03', 'NV A7D03', 'Quản trị viên')
on conflict (id) do update set
  employee_code = excluded.employee_code,
  full_name = excluded.full_name;
insert into public.roles (id, org_id, code, name_vi) values
  ('a7d00000-0000-4000-8000-000000000601', 'a7d00000-0000-4000-8000-000000000001', 'storekeeper', 'Thủ kho'),
  ('a7d00000-0000-4000-8000-000000000602', 'a7d00000-0000-4000-8000-000000000001', 'chef', 'Bếp trưởng'),
  ('a7d00000-0000-4000-8000-000000000603', 'a7d00000-0000-4000-8000-000000000001', 'a7d_admin', 'Quản trị viên A7D');
insert into public.role_permissions (role_id, permission_code) values
  ('a7d00000-0000-4000-8000-000000000601', 'count.open'),
  ('a7d00000-0000-4000-8000-000000000601', 'count.perform'),
  ('a7d00000-0000-4000-8000-000000000601', 'purpose_issue.post'),
  ('a7d00000-0000-4000-8000-000000000601', 'requisition.create'),
  ('a7d00000-0000-4000-8000-000000000601', 'transfer.send'),
  ('a7d00000-0000-4000-8000-000000000602', 'count.perform'),
  ('a7d00000-0000-4000-8000-000000000603', 'admin.users.manage');
insert into public.user_property_roles (user_id, role_id, property_id) values
  ('a7d00000-0000-4000-8000-000000000a01', 'a7d00000-0000-4000-8000-000000000601', 'a7d00000-0000-4000-8000-000000000201'),
  ('a7d00000-0000-4000-8000-000000000a02', 'a7d00000-0000-4000-8000-000000000602', 'a7d00000-0000-4000-8000-000000000201'),
  ('a7d00000-0000-4000-8000-000000000a03', 'a7d00000-0000-4000-8000-000000000603', null);
create temp table a7d_ctx (key text primary key, id uuid);
create temp table a7d_resp (key text primary key, resp jsonb);
create temp table a7d_num (key text primary key, n bigint);
grant all on a7d_ctx, a7d_resp, a7d_num to authenticated;
create or replace function public._a7d_as(p_user uuid)
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
create or replace function public._a7d_has_audit_trigger(p_table text)
returns boolean
language sql
stable
as $$
  select exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    join pg_namespace pn on pn.oid = p.pronamespace
    where n.nspname = 'public'
      and c.relname = p_table
      and t.tgname = 'trg_' || p_table || '_audit'
      and p.proname = 'audit_trigger'
      and pn.nspname = 'public'
  );
$$;

-- ---------------------------------------------------------------------------
-- §0: 16 bang bat buoc co trigger; 8 bang bo qua khong co trigger audit.
-- ---------------------------------------------------------------------------
select ok(public._a7d_has_audit_trigger('stock_counts'), 'stock_counts has trg_stock_counts_audit');
select ok(public._a7d_has_audit_trigger('stock_count_lines'), 'stock_count_lines has trg_stock_count_lines_audit');
select ok(public._a7d_has_audit_trigger('requisitions'), 'requisitions has trg_requisitions_audit');
select ok(public._a7d_has_audit_trigger('purpose_issues'), 'purpose_issues has trg_purpose_issues_audit');
select ok(public._a7d_has_audit_trigger('transfers'), 'transfers has trg_transfers_audit');
select ok(public._a7d_has_audit_trigger('waste_reports'), 'waste_reports has trg_waste_reports_audit');
select ok(public._a7d_has_audit_trigger('supplier_invoices'), 'supplier_invoices has trg_supplier_invoices_audit');
select ok(public._a7d_has_audit_trigger('payment_requests'), 'payment_requests has trg_payment_requests_audit');
select ok(public._a7d_has_audit_trigger('advance_settlements'), 'advance_settlements has trg_advance_settlements_audit');
select ok(public._a7d_has_audit_trigger('minibar_checks'), 'minibar_checks has trg_minibar_checks_audit');
select ok(public._a7d_has_audit_trigger('trolley_shifts'), 'trolley_shifts has trg_trolley_shifts_audit');
select ok(public._a7d_has_audit_trigger('recipes'), 'recipes has trg_recipes_audit');
select ok(public._a7d_has_audit_trigger('dish_sales'), 'dish_sales has trg_dish_sales_audit');
select ok(public._a7d_has_audit_trigger('banquets'), 'banquets has trg_banquets_audit');
select ok(public._a7d_has_audit_trigger('service_acceptances'), 'service_acceptances has trg_service_acceptances_audit');
select ok(public._a7d_has_audit_trigger('profiles'), 'profiles has trg_profiles_audit');
select ok(not public._a7d_has_audit_trigger('stock_moves'), 'stock_moves has no audit trigger (ledger, skipped)');
select ok(not public._a7d_has_audit_trigger('stock_balances'), 'stock_balances has no audit trigger (ledger, skipped)');
select ok(not public._a7d_has_audit_trigger('item_costs'), 'item_costs has no audit trigger (ledger, skipped)');
select ok(not public._a7d_has_audit_trigger('ap_ledger'), 'ap_ledger has no audit trigger (ledger, skipped)');
select ok(not public._a7d_has_audit_trigger('audit_log'), 'audit_log has no audit trigger (log itself, skipped)');
select ok(not public._a7d_has_audit_trigger('report_snapshots'), 'report_snapshots has no audit trigger (cache, skipped)');
select ok(not public._a7d_has_audit_trigger('notification_deliveries'), 'notification_deliveries has no audit trigger (queue, skipped)');
select ok(not public._a7d_has_audit_trigger('push_subscriptions'), 'push_subscriptions has no audit trigger (queue, skipped)');

set local role authenticated;

-- ---------------------------------------------------------------------------
-- §1: profiles — admin_user_set_pin doi PIN cua a02 (UPDATE).
-- ---------------------------------------------------------------------------
select public._a7d_as('a7d00000-0000-4000-8000-000000000a03');
insert into a7d_num values ('profiles_before', (select count(*) from public.audit_log where table_name = 'profiles' and row_id = 'a7d00000-0000-4000-8000-000000000a02'));
select public.admin_user_set_pin('a7d00000-0000-4000-8000-000000000a02', '1234');
select is(
  (select count(*) from public.audit_log where table_name = 'profiles' and row_id = 'a7d00000-0000-4000-8000-000000000a02')
  - (select n from a7d_num where key = 'profiles_before'),
  1::bigint, 'admin_user_set_pin writes exactly 1 new audit_log row for profiles'
);
select is(
  (select actor from public.audit_log where table_name = 'profiles' and row_id = 'a7d00000-0000-4000-8000-000000000a02' order by id desc limit 1),
  'a7d00000-0000-4000-8000-000000000a03'::uuid, 'profiles audit row actor is the admin caller'
);
select is(
  (select action from public.audit_log where table_name = 'profiles' and row_id = 'a7d00000-0000-4000-8000-000000000a02' order by id desc limit 1),
  'UPDATE', 'profiles audit row action is UPDATE'
);

-- ---------------------------------------------------------------------------
-- §2: purpose_issues — purpose_issue_save_draft (INSERT).
-- ---------------------------------------------------------------------------
select public._a7d_as('a7d00000-0000-4000-8000-000000000a01');
insert into a7d_num values ('pi_before', (select count(*) from public.audit_log where table_name = 'purpose_issues'));
insert into a7d_resp values ('pi', public.purpose_issue_save_draft(jsonb_build_object(
  'property_id', 'a7d00000-0000-4000-8000-000000000201',
  'warehouse_id', 'a7d00000-0000-4000-8000-000000000301',
  'purpose_code', 'other',
  'cost_center_id', 'a7d00000-0000-4000-8000-000000000901',
  'expense_category_id', 'a7d00000-0000-4000-8000-000000000902',
  'lines', jsonb_build_array(jsonb_build_object(
    'item_id', 'a7d00000-0000-4000-8000-000000000501',
    'qty', 2, 'uom', 'kg'
  ))
)));
select is(
  (select count(*) from public.audit_log where table_name = 'purpose_issues' and row_id = (select resp ->> 'id' from a7d_resp where key = 'pi'))
  - (select n from a7d_num where key = 'pi_before'),
  1::bigint, 'purpose_issue_save_draft writes exactly 1 new audit_log row for purpose_issues'
);
select is(
  (select actor from public.audit_log where table_name = 'purpose_issues' and row_id = (select resp ->> 'id' from a7d_resp where key = 'pi') order by id desc limit 1),
  'a7d00000-0000-4000-8000-000000000a01'::uuid, 'purpose_issues audit row actor is the caller'
);
select is(
  (select action from public.audit_log where table_name = 'purpose_issues' and row_id = (select resp ->> 'id' from a7d_resp where key = 'pi') order by id desc limit 1),
  'INSERT', 'purpose_issues audit row action is INSERT'
);

-- ---------------------------------------------------------------------------
-- §3: requisitions — requisition_save_draft (INSERT).
-- ---------------------------------------------------------------------------
insert into a7d_num values ('req_before', (select count(*) from public.audit_log where table_name = 'requisitions'));
insert into a7d_resp values ('req', public.requisition_save_draft(jsonb_build_object(
  'property_id', 'a7d00000-0000-4000-8000-000000000201',
  'outlet_id', 'a7d00000-0000-4000-8000-000000000802',
  'from_warehouse_id', 'a7d00000-0000-4000-8000-000000000301',
  'to_warehouse_id', 'a7d00000-0000-4000-8000-000000000302',
  'lines', jsonb_build_array(jsonb_build_object(
    'item_id', 'a7d00000-0000-4000-8000-000000000501',
    'qty', 2, 'uom', 'kg'
  ))
)));
select is(
  (select count(*) from public.audit_log where table_name = 'requisitions' and row_id = (select resp ->> 'id' from a7d_resp where key = 'req'))
  - (select n from a7d_num where key = 'req_before'),
  1::bigint, 'requisition_save_draft writes exactly 1 new audit_log row for requisitions'
);
select is(
  (select actor from public.audit_log where table_name = 'requisitions' and row_id = (select resp ->> 'id' from a7d_resp where key = 'req') order by id desc limit 1),
  'a7d00000-0000-4000-8000-000000000a01'::uuid, 'requisitions audit row actor is the caller'
);
select is(
  (select action from public.audit_log where table_name = 'requisitions' and row_id = (select resp ->> 'id' from a7d_resp where key = 'req') order by id desc limit 1),
  'INSERT', 'requisitions audit row action is INSERT'
);

-- ---------------------------------------------------------------------------
-- §4: stock_counts — count_open monthly_full (INSERT).
-- ---------------------------------------------------------------------------
insert into a7d_num values ('cnt_before', (select count(*) from public.audit_log where table_name = 'stock_counts'));
insert into a7d_resp values ('cnt', public.count_open(
  'a7d00000-0000-4000-8000-000000000301', 'monthly_full', '2026-11-09', null,
  array['a7d00000-0000-4000-8000-000000000a01', 'a7d00000-0000-4000-8000-000000000a02']::uuid[],
  'a7d00000-0000-4000-8000-00000000aa01'
));
select is(
  (select (resp ->> 'lines_created')::int from a7d_resp where key = 'cnt'),
  1, 'count_open snapshot creates 1 line (GAO)'
);
select is(
  (select count(*) from public.audit_log where table_name = 'stock_counts' and row_id = (select resp ->> 'id' from a7d_resp where key = 'cnt'))
  - (select n from a7d_num where key = 'cnt_before'),
  1::bigint, 'count_open writes exactly 1 new audit_log row for stock_counts'
);
select is(
  (select actor from public.audit_log where table_name = 'stock_counts' and row_id = (select resp ->> 'id' from a7d_resp where key = 'cnt') order by id desc limit 1),
  'a7d00000-0000-4000-8000-000000000a01'::uuid, 'stock_counts audit row actor is the caller'
);
select is(
  (select action from public.audit_log where table_name = 'stock_counts' and row_id = (select resp ->> 'id' from a7d_resp where key = 'cnt') order by id desc limit 1),
  'INSERT', 'stock_counts audit row action is INSERT'
);

-- ---------------------------------------------------------------------------
-- §5: transfers — transfer_save_draft (INSERT).
-- ---------------------------------------------------------------------------
insert into a7d_num values ('trf_before', (select count(*) from public.audit_log where table_name = 'transfers'));
insert into a7d_resp values ('trf', public.transfer_save_draft(jsonb_build_object(
  'property_id', 'a7d00000-0000-4000-8000-000000000201',
  'from_warehouse_id', 'a7d00000-0000-4000-8000-000000000301',
  'to_warehouse_id', 'a7d00000-0000-4000-8000-000000000302',
  'lines', jsonb_build_array(jsonb_build_object(
    'item_id', 'a7d00000-0000-4000-8000-000000000501',
    'qty', 2, 'uom', 'kg'
  ))
)));
select is(
  (select count(*) from public.audit_log where table_name = 'transfers' and row_id = (select resp ->> 'id' from a7d_resp where key = 'trf'))
  - (select n from a7d_num where key = 'trf_before'),
  1::bigint, 'transfer_save_draft writes exactly 1 new audit_log row for transfers'
);
select is(
  (select actor from public.audit_log where table_name = 'transfers' and row_id = (select resp ->> 'id' from a7d_resp where key = 'trf') order by id desc limit 1),
  'a7d00000-0000-4000-8000-000000000a01'::uuid, 'transfers audit row actor is the caller'
);
select is(
  (select action from public.audit_log where table_name = 'transfers' and row_id = (select resp ->> 'id' from a7d_resp where key = 'trf') order by id desc limit 1),
  'INSERT', 'transfers audit row action is INSERT'
);

select finish();
rollback;
