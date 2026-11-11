-- C2 pgTAP: hau kiem anh nhan hang (M04) — 3 RPC moi o migration
-- 20261109521000: `receiving_list_photo_reviews`,
-- `receiving_get_photo_review`, `receiving_review_photos` + 4 cot hau
-- kiem tren `goods_receipts`.
-- Kiem tra: cot + default 'pending', list chi phieu posted/needs_recount
-- co anh, loc theo trang thai hau kiem, get khong tra gia, quyen
-- (review_photos de duyet, receiving.view chi xem, receiver khong co
-- quyen nao), duyet 1 lan, tu choi bat buoc ly do, phieu khong anh /
-- nhap khong duyet duoc, audit_log ghi UPDATE.
-- CHUA CHAY: khong co Docker tren VM (giong cac test truoc).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(38);

-- 0. Fixture
insert into public.organizations (id, name) values
  ('dc020000-0000-4000-8000-000000000001', 'C2 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('dc020000-0000-4000-8000-000000000101', 'dc020000-0000-4000-8000-000000000001', 'TC2', 'Entity C2');

insert into public.properties (id, org_id, legal_entity_id, code, name, sod_profile) values
  ('dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000101', 'PC21', 'Property C2', 'with_cc');

insert into public.uoms (code, name_vi) values
  ('kg', 'Kilôgam')
on conflict do nothing;

insert into public.item_groups (id, org_id, code_prefix, name, kind) values
  ('dc020000-0000-4000-8000-000000000401', 'dc020000-0000-4000-8000-000000000001', 'GAO', 'Gạo', 'food');

insert into public.items (id, org_id, code, name, group_id, stock_uom, is_key_item, track_lot, shelf_life_days, allowed_channels) values
  ('dc020000-0000-4000-8000-000000000501', 'dc020000-0000-4000-8000-000000000001', 'ITM_GAO', 'Gạo ST25', 'dc020000-0000-4000-8000-000000000401', 'kg', true, false, null, array['contract', 'market']),
  ('dc020000-0000-4000-8000-000000000502', 'dc020000-0000-4000-8000-000000000001', 'ITM_THIT', 'Thịt ba chỉ', 'dc020000-0000-4000-8000-000000000401', 'kg', true, true, 30, array['contract']);

insert into public.suppliers (id, org_id, code, name, kind, status) values
  ('dc020000-0000-4000-8000-000000000701', 'dc020000-0000-4000-8000-000000000001', 'NCC_GAO', 'Công ty Gạo Sạch', 'company', 'active');

insert into public.warehouses (id, property_id, code, name, kind, outlet_id) values
  ('dc020000-0000-4000-8000-000000000301', 'dc020000-0000-4000-8000-000000000201', 'WH_MAIN', 'Kho chính', 'main', null);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('dc020000-0000-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1-cc0c2@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('dc020000-0000-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2-rec0c2@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('dc020000-0000-4000-8000-000000000a03', '00000000-0000-4000-8000-000000000000', 'authenticated', 'authenticated', 'u3-gm0c2@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.roles (id, org_id, code, name_vi) values
  ('dc020000-0000-4000-8000-000000000601', 'dc020000-0000-4000-8000-000000000001', 'cost_controller', 'Cost Controller'),
  ('dc020000-0000-4000-8000-000000000602', 'dc020000-0000-4000-8000-000000000001', 'receiver', 'Nhận hàng'),
  ('dc020000-0000-4000-8000-000000000603', 'dc020000-0000-4000-8000-000000000001', 'gm', 'Tổng quản lý');

insert into public.role_permissions (role_id, permission_code) values
  ('dc020000-0000-4000-8000-000000000601', 'receiving.review_photos'),
  ('dc020000-0000-4000-8000-000000000602', 'receiving.perform'),
  ('dc020000-0000-4000-8000-000000000603', 'receiving.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('dc020000-0000-4000-8000-000000000a01', 'dc020000-0000-4000-8000-000000000601', 'dc020000-0000-4000-8000-000000000201'),
  ('dc020000-0000-4000-8000-000000000a02', 'dc020000-0000-4000-8000-000000000602', 'dc020000-0000-4000-8000-000000000201'),
  ('dc020000-0000-4000-8000-000000000a03', 'dc020000-0000-4000-8000-000000000603', 'dc020000-0000-4000-8000-000000000201');

-- Phieu nhan fixture (chen truc tiep, bypass write-guard vi chi can phieu
-- o trang thai cho san; photo_ids la uuid[] khong co FK nen dung uuid gia).
select set_config('app.receiving_guard_bypass', 'on', true);
insert into public.goods_receipts (id, org_id, legal_entity_id, property_id, warehouse_id, doc_no, receiver_id, status, supplier_id) values
  ('dc020000-0000-4000-8000-000000000e01', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000101', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000301', 'GRN-C2-001', 'dc020000-0000-4000-8000-000000000a02', 'posted', 'dc020000-0000-4000-8000-000000000701'),
  ('dc020000-0000-4000-8000-000000000e02', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000101', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000301', 'GRN-C2-002', 'dc020000-0000-4000-8000-000000000a02', 'posted', 'dc020000-0000-4000-8000-000000000701'),
  ('dc020000-0000-4000-8000-000000000e03', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000101', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000301', 'GRN-C2-003', 'dc020000-0000-4000-8000-000000000a02', 'draft', 'dc020000-0000-4000-8000-000000000701'),
  ('dc020000-0000-4000-8000-000000000e04', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000101', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000301', 'GRN-C2-004', 'dc020000-0000-4000-8000-000000000a02', 'needs_recount', 'dc020000-0000-4000-8000-000000000701'),
  ('dc020000-0000-4000-8000-000000000e05', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000101', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000301', 'GRN-C2-005', 'dc020000-0000-4000-8000-000000000a02', 'posted', 'dc020000-0000-4000-8000-000000000701');
update public.goods_receipts
set photo_review_status = 'approved',
    photo_reviewed_by = 'dc020000-0000-4000-8000-000000000a01',
    photo_reviewed_at = now()
where id = 'dc020000-0000-4000-8000-000000000e05';

insert into public.goods_receipt_lines (id, gr_id, org_id, property_id, item_id, gross_qty, uom, net_qty_stock, qc_status, photo_ids) values
  ('dc020000-0000-4000-8000-000000000f01', 'dc020000-0000-4000-8000-000000000e01', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000501', 10, 'kg', 10, 'pass', array['dc020000-0000-4000-8000-000000000a11', 'dc020000-0000-4000-8000-000000000a12']::uuid[]),
  ('dc020000-0000-4000-8000-000000000f02', 'dc020000-0000-4000-8000-000000000e01', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000502', 5, 'kg', 5, 'pass', array['dc020000-0000-4000-8000-000000000a13']::uuid[]),
  ('dc020000-0000-4000-8000-000000000f03', 'dc020000-0000-4000-8000-000000000e02', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000501', 10, 'kg', 10, 'pass', '{}'::uuid[]),
  ('dc020000-0000-4000-8000-000000000f04', 'dc020000-0000-4000-8000-000000000e03', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000501', 10, 'kg', 10, 'pass', array['dc020000-0000-4000-8000-000000000a14']::uuid[]),
  ('dc020000-0000-4000-8000-000000000f05', 'dc020000-0000-4000-8000-000000000e04', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000501', 10, 'kg', 10, 'pass', array['dc020000-0000-4000-8000-000000000a15']::uuid[]),
  ('dc020000-0000-4000-8000-000000000f06', 'dc020000-0000-4000-8000-000000000e05', 'dc020000-0000-4000-8000-000000000001', 'dc020000-0000-4000-8000-000000000201', 'dc020000-0000-4000-8000-000000000501', 10, 'kg', 10, 'pass', array['dc020000-0000-4000-8000-000000000a16']::uuid[]);
select set_config('app.receiving_guard_bypass', 'off', true);

-- Bang tam giu response JSON cua cac lan goi RPC duyet (goi 1 lan,
-- assert nhieu truong) — mau T-023.
create temp table t0c2_resp (key text primary key, resp jsonb);
grant all on t0c2_resp to authenticated;

-- Helper doi user: dat lai JWT claim (mau T-020/T-023).
create or replace function public._t0c2_as(p_user uuid)
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

-- 1. Cot hau kiem ton tai + mac dinh 'pending'.
select has_column('public', 'goods_receipts', 'photo_review_status',
  'goods_receipts has photo_review_status column');
select has_column('public', 'goods_receipts', 'photo_reviewed_by',
  'goods_receipts has photo_reviewed_by column');
select has_column('public', 'goods_receipts', 'photo_reviewed_at',
  'goods_receipts has photo_reviewed_at column');
select has_column('public', 'goods_receipts', 'photo_review_reason',
  'goods_receipts has photo_review_reason column');
select is(
  (select photo_review_status from public.goods_receipts
    where id = 'dc020000-0000-4000-8000-000000000e01'),
  'pending', 'New posted receipt defaults to photo_review_status pending'
);

-- Tu day tro di chay duoi role authenticated (RLS + has_perm co hieu luc).
set local role authenticated;

-- 2. List: chi phieu posted/needs_recount co anh; loc + tim kiem + quyen.
select public._t0c2_as('dc020000-0000-4000-8000-000000000a01');
select is(
  (select (public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201'
  ) ->> 'total')::int),
  3, 'List returns 3 receipts with photos (posted + needs_recount)'
);
select is(
  (select jsonb_array_length(public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201'
  ) -> 'reviews')),
  3, 'List reviews array has 3 rows'
);
select is(
  (select (r ->> 'photo_count')::int
   from jsonb_array_elements(public.receiving_list_photo_reviews(
     'dc020000-0000-4000-8000-000000000201'
   ) -> 'reviews') r
   where r ->> 'id' = 'dc020000-0000-4000-8000-000000000e01'),
  3, 'GRN-C2-001 has photo_count 3 across its lines'
);
select is(
  (select (public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201', 'pending'
  ) ->> 'total')::int),
  2, 'Pending filter returns 2 receipts'
);
select is(
  (select (public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201', 'approved'
  ) ->> 'total')::int),
  1, 'Approved filter returns 1 receipt'
);
select is(
  (select (public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201', 'rejected'
  ) ->> 'total')::int),
  0, 'Rejected filter returns 0 receipts before any rejection'
);
select is(
  (select (public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201', null, 'GRN-C2-001'
  ) ->> 'total')::int),
  1, 'Search by doc_no returns 1 receipt'
);
select throws_ok(
  $q$select public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201', 'done'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'List with invalid review_status throws ERR_INVALID_VALUE'
);
select public._t0c2_as('dc020000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201'
  )$q$,
  '42501', 'ERR_FORBIDDEN:receiving.review_photos',
  'Receiver without review_photos cannot list photo reviews'
);

-- 3. Get: chi tiet + dong hang, khong tra gia; phieu nhap khong xem duoc.
select public._t0c2_as('dc020000-0000-4000-8000-000000000a01');
select is(
  (select jsonb_array_length(public.receiving_get_photo_review(
    'dc020000-0000-4000-8000-000000000e01'
  ) -> 'lines')),
  2, 'Get returns 2 lines for GRN-C2-001'
);
select is(
  (select public.receiving_get_photo_review(
    'dc020000-0000-4000-8000-000000000e01'
  ) ->> 'photo_review_status'),
  'pending', 'Get returns photo_review_status pending'
);
select is(
  (select (public.receiving_get_photo_review(
    'dc020000-0000-4000-8000-000000000e01'
  ) ->> 'photo_count')::int),
  3, 'Get returns photo_count 3'
);
select throws_ok(
  $q$select public.receiving_get_photo_review(
    'dc020000-0000-4000-8000-000000000e03'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Get on draft receipt throws ERR_INVALID_STATUS'
);
select throws_ok(
  $q$select public.receiving_get_photo_review(
    'dc020000-0000-4000-8000-00000000ffff'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Get on missing receipt throws ERR_INVALID_VALUE'
);
select public._t0c2_as('dc020000-0000-4000-8000-000000000a03');
select is(
  (select (public.receiving_get_photo_review(
    'dc020000-0000-4000-8000-000000000e01'
  ) ->> 'ok')::boolean),
  true, 'User with receiving.view can view photo review detail'
);
select public._t0c2_as('dc020000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.receiving_get_photo_review(
    'dc020000-0000-4000-8000-000000000e01'
  )$q$,
  'P0001', 'ERR_FORBIDDEN:receiving.view',
  'Receiver without view/review perm cannot get photo review'
);

-- 4. Review: quyen, gia tri, duyet 1 lan, ly do bat buoc, audit.
select public._t0c2_as('dc020000-0000-4000-8000-000000000a02');
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e01', 'approved'
  )$q$,
  '42501', 'ERR_FORBIDDEN:receiving.review_photos',
  'Receiver without review_photos cannot approve'
);
select public._t0c2_as('dc020000-0000-4000-8000-000000000a01');
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e01', 'maybe'
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Review with invalid decision throws ERR_INVALID_VALUE'
);
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e01', 'rejected', null
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Reject without reason throws ERR_INVALID_VALUE'
);
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e01', 'rejected', '   '
  )$q$,
  'P0001', 'ERR_INVALID_VALUE',
  'Reject with blank reason throws ERR_INVALID_VALUE'
);
insert into t0c2_resp values ('review_gr1_approve', (select public.receiving_review_photos(
  'dc020000-0000-4000-8000-000000000e01', 'approved'
)));
select is(
  (select resp ->> 'photo_review_status' from t0c2_resp
    where key = 'review_gr1_approve'),
  'approved', 'Approve returns photo_review_status approved'
);
select is(
  (select photo_reviewed_by from public.goods_receipts
    where id = 'dc020000-0000-4000-8000-000000000e01'),
  'dc020000-0000-4000-8000-000000000a01'::uuid,
  'Approve records reviewer'
);
select ok(
  (select photo_reviewed_at is not null from public.goods_receipts
    where id = 'dc020000-0000-4000-8000-000000000e01'),
  'Approve records reviewed_at'
);
select ok(
  (select photo_review_reason is null from public.goods_receipts
    where id = 'dc020000-0000-4000-8000-000000000e01'),
  'Approve clears review reason'
);
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e01', 'rejected', 'Ảnh mờ'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Second review on decided receipt throws ERR_INVALID_STATUS'
);
insert into t0c2_resp values ('review_gr4_reject', (select public.receiving_review_photos(
  'dc020000-0000-4000-8000-000000000e04', 'rejected', 'Ảnh mờ, không đọc được hạn dùng'
)));
select is(
  (select resp ->> 'photo_review_status' from t0c2_resp
    where key = 'review_gr4_reject'),
  'rejected', 'Reject returns photo_review_status rejected'
);
select is(
  (select photo_review_reason from public.goods_receipts
    where id = 'dc020000-0000-4000-8000-000000000e04'),
  'Ảnh mờ, không đọc được hạn dùng', 'Reject stores the reason'
);
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e02', 'approved'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Review on receipt without photos throws ERR_INVALID_STATUS'
);
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e03', 'approved'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Review on draft receipt throws ERR_INVALID_STATUS'
);
select throws_ok(
  $q$select public.receiving_review_photos(
    'dc020000-0000-4000-8000-000000000e05', 'approved'
  )$q$,
  'P0001', 'ERR_INVALID_STATUS',
  'Review on already approved receipt throws ERR_INVALID_STATUS'
);
-- Audit: chi doc duoc voi audit.view_all (has_perm(null, ...) doi hoi
-- gan quyen cap chuoi, khong phai pham vi property) nen doc bang role
-- postgres nhu mau T-014, roi tra lai authenticated + u1 cho 2 assert cuoi.
reset role;
select ok(
  (select exists (
    select 1 from public.audit_log
    where table_name = 'goods_receipts'
      and row_id = 'dc020000-0000-4000-8000-000000000e01'
      and action = 'UPDATE'
  )),
  'Audit log records the photo review UPDATE'
);
set local role authenticated;
select public._t0c2_as('dc020000-0000-4000-8000-000000000a01');
select is(
  (select (public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201', 'rejected'
  ) ->> 'total')::int),
  1, 'Rejected filter returns 1 receipt after rejection'
);
select is(
  (select (public.receiving_list_photo_reviews(
    'dc020000-0000-4000-8000-000000000201', 'pending'
  ) ->> 'total')::int),
  0, 'Pending filter returns 0 receipts after all reviews decided'
);

select * from finish();
rollback;
