-- T-016 pgTAP: Storage evidence + attachments + RPC dang ky anh + alert PHOTO_REUSED.
-- Kiem tra: buckets private + storage policy (INSERT theo phap nhan, SELECT qua bang
-- attachments), bang attachments (RLS, bat bien), attachment_prepare_upload
-- (duong dan theo spec, quyen), attachment_register (dang ky, luy thua cung chung tu,
-- trung hash khac chung tu -> reused_from_id + alert PHOTO_REUSED muc red, sai
-- SHA/duong dan/bucket/quyen bi chan).
-- Chu y: pgTAP chua chay (khong co Docker tren VM).
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(38);

-- 1. Setup Fixture (chay duoi role mac dinh cua test, bypass RLS).
insert into public.organizations (id, name) values
  ('d0160000-1600-4000-8000-000000000001', 'T-016 Master Org');

insert into public.legal_entities (id, org_id, code, name) values
  ('d0160000-1600-4000-8000-000000000101', 'd0160000-1600-4000-8000-000000000001', 'T016', 'Entity T-016'),
  ('d0160000-1600-4000-8000-000000000102', 'd0160000-1600-4000-8000-000000000001', 'T016B', 'Entity T-016 B');

insert into public.properties (id, org_id, legal_entity_id, code, name) values
  ('d0160000-1600-4000-8000-000000000201', 'd0160000-1600-4000-8000-000000000001', 'd0160000-1600-4000-8000-000000000101', 'P016', 'Property T-016'),
  ('d0160000-1600-4000-8000-000000000202', 'd0160000-1600-4000-8000-000000000001', 'd0160000-1600-4000-8000-000000000102', 'P016B', 'Property T-016 B');

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
values
  ('d0160000-1600-4000-8000-000000000a01', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'receiver016@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0160000-1600-4000-8000-000000000a02', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'cc016@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0160000-1600-4000-8000-000000000a03', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewer016@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb),
  ('d0160000-1600-4000-8000-000000000a04', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'viewerb016@test.com', '', now(), now(), now(), '{}'::jsonb, '{}'::jsonb);

insert into public.profiles (id, employee_code, full_name) values
  ('d0160000-1600-4000-8000-000000000a01', 'NV01601', 'Nhan vien nhan hang'),
  ('d0160000-1600-4000-8000-000000000a02', 'NV01602', 'Cost Controller'),
  ('d0160000-1600-4000-8000-000000000a03', 'NV01603', 'Nguoi chi xem KS A'),
  ('d0160000-1600-4000-8000-000000000a04', 'NV01604', 'Nguoi chi xem KS B');

insert into public.roles (id, org_id, code, name_vi) values
  ('d0160000-1600-4000-8000-000000000601', 'd0160000-1600-4000-8000-000000000001', 'r_recv016', 'Nhan hang'),
  ('d0160000-1600-4000-8000-000000000602', 'd0160000-1600-4000-8000-000000000001', 'r_cc016', 'Cost Controller'),
  ('d0160000-1600-4000-8000-000000000603', 'd0160000-1600-4000-8000-000000000001', 'r_view016', 'Chi xem KS A'),
  ('d0160000-1600-4000-8000-000000000604', 'd0160000-1600-4000-8000-000000000001', 'r_viewb016', 'Chi xem KS B');

insert into public.role_permissions (role_id, permission_code) values
  ('d0160000-1600-4000-8000-000000000601', 'attachment.upload'),
  ('d0160000-1600-4000-8000-000000000601', 'attachment.view'),
  ('d0160000-1600-4000-8000-000000000602', 'attachment.view'),
  ('d0160000-1600-4000-8000-000000000602', 'alert.receive.photo_reused'),
  ('d0160000-1600-4000-8000-000000000603', 'item.view'),
  ('d0160000-1600-4000-8000-000000000604', 'attachment.view');

insert into public.user_property_roles (user_id, role_id, property_id) values
  ('d0160000-1600-4000-8000-000000000a01', 'd0160000-1600-4000-8000-000000000601', null),
  ('d0160000-1600-4000-8000-000000000a02', 'd0160000-1600-4000-8000-000000000602', null),
  ('d0160000-1600-4000-8000-000000000a03', 'd0160000-1600-4000-8000-000000000603', 'd0160000-1600-4000-8000-000000000201'),
  ('d0160000-1600-4000-8000-000000000a04', 'd0160000-1600-4000-8000-000000000604', 'd0160000-1600-4000-8000-000000000202');

-- Dong attachments mau (de test trigger bat bien duoi role mac dinh).
insert into public.attachments (id, org_id, legal_entity_id, property_id, bucket, path, sha256, doc_type, doc_id, uploaded_by)
values (
  'd0160000-1600-4000-8000-000000000901',
  'd0160000-1600-4000-8000-000000000001',
  'd0160000-1600-4000-8000-000000000101',
  'd0160000-1600-4000-8000-000000000201',
  'evidence',
  'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000901.jpg',
  'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
  'receiving',
  'd0160000-1600-4000-8000-000000000700',
  'd0160000-1600-4000-8000-000000000a01'
);

-- 2. Schema: RLS bat, buckets private, policies ton tai.
select ok(
  (select relrowsecurity from pg_class where oid = 'public.attachments'::regclass),
  'RLS bat tren bang attachments'
);
select is(
  (select public from storage.buckets where id = 'evidence'),
  false,
  'bucket evidence la private'
);
select is(
  (select public from storage.buckets where id = 'attachments'),
  false,
  'bucket attachments la private'
);
select ok(
  exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'evidence_insert'),
  'co storage policy evidence_insert'
);
select ok(
  exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname = 'evidence_select'),
  'co storage policy evidence_select'
);
select ok(
  exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'attachments' and policyname = 'attachments_select'),
  'co policy attachments_select'
);

-- 3. Bat bien: UPDATE/DELETE dong attachments bi chan ngay ca duoi role mac dinh.
select throws_ok(
  $q$update public.attachments set doc_type = 'count' where id = 'd0160000-1600-4000-8000-000000000901'$q$,
  'ERR_ATTACHMENT_IMMUTABLE',
  'UPDATE dong attachments bi chan'
);
select throws_ok(
  $q$delete from public.attachments where id = 'd0160000-1600-4000-8000-000000000901'$q$,
  'ERR_ATTACHMENT_IMMUTABLE',
  'DELETE dong attachments bi chan'
);

-- Chuyen sang role authenticated; doi user bang set_config request.jwt.claim.sub.
set local role authenticated;

-- Helper u1 (receiver, chain-wide, attachment.upload + attachment.view).
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a01","role":"authenticated"}', true);

-- 4. attachment_prepare_upload: tra duong dan dung dinh dang spec.
select lives_ok(
  $q$select public.attachment_prepare_upload(
    'd0160000-1600-4000-8000-000000000201', 'receiving'
  )$q$,
  'prepare_upload chay duoc cho nguoi co quyen'
);
select ok(
  (public.attachment_prepare_upload(
    'd0160000-1600-4000-8000-000000000201', 'receiving'
  ) ->> 'path') like 'd0160000-1600-4000-8000-000000000101/receiving/%'
  and (public.attachment_prepare_upload(
    'd0160000-1600-4000-8000-000000000201', 'receiving'
  ) ->> 'path') like '%.jpg'
  and (public.attachment_prepare_upload(
    'd0160000-1600-4000-8000-000000000201', 'receiving'
  ) ->> 'bucket') = 'evidence',
  'prepare_upload tra duong dan {legal_entity_id}/{doc_type}/{yyyy}/{mm}/{uuid}.jpg, bucket evidence'
);

-- 5. prepare_upload: nguoi khong co quyen bi chan; doc_type rong bi chan.
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a03","role":"authenticated"}', true);
select throws_ok(
  $q$select public.attachment_prepare_upload(
    'd0160000-1600-4000-8000-000000000201', 'receiving'
  )$q$,
  'ERR_FORBIDDEN:attachment.upload',
  'viewer khong chuan bi duoc duong dan upload'
);

select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a01","role":"authenticated"}', true);
select throws_ok(
  $q$select public.attachment_prepare_upload(
    'd0160000-1600-4000-8000-000000000201', '   '
  )$q$,
  'ERR_INVALID_VALUE',
  'prepare_upload voi doc_type rong bi chan'
);

-- 6. attachment_register: dang ky anh moi ok, khong reused.
select lives_ok(
  $q$select public.attachment_register(
    'd0160000-1600-4000-8000-000000000201', 'evidence',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000801.jpg',
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'receiving', 'd0160000-1600-4000-8000-000000000701'
  )$q$,
  'dang ky anh moi chay duoc'
);
select is(
  (select count(*) from public.attachments where doc_id = 'd0160000-1600-4000-8000-000000000701'),
  1::bigint,
  'dang ky 1 dong attachments cho chung tu 701'
);
select is(
  (select sha256 from public.attachments where doc_id = 'd0160000-1600-4000-8000-000000000701'),
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'sha256 luu dung gia tri client gui'
);

-- 7. Dang ky lai cung anh cho CUNG chung tu: luy thua, khong tao dong moi.
select lives_ok(
  $q$select public.attachment_register(
    'd0160000-1600-4000-8000-000000000201', 'evidence',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000802.jpg',
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'receiving', 'd0160000-1600-4000-8000-000000000701'
  )$q$,
  'dang ky lai cung anh cung chung tu chay duoc (luy thua)'
);
select is(
  (select count(*) from public.attachments where doc_id = 'd0160000-1600-4000-8000-000000000701'),
  1::bigint,
  'dang ky lai khong tao dong attachments moi'
);

-- 8. Chua co alert PHOTO_REUSED nao truoc khi dung lai (kiem tra duoi u2 co quyen nhan alert).
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a02","role":"authenticated"}', true);
select is(
  (select count(*) from public.alerts where code = 'PHOTO_REUSED'),
  0::bigint,
  'chua co alert PHOTO_REUSED truoc khi dung lai anh'
);

-- 9. Dang ky cung anh cho chung tu KHAC -> reused + alert PHOTO_REUSED muc red.
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a01","role":"authenticated"}', true);
select lives_ok(
  $q$select public.attachment_register(
    'd0160000-1600-4000-8000-000000000201', 'evidence',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000803.jpg',
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'receiving', 'd0160000-1600-4000-8000-000000000702'
  )$q$,
  'dang ky cung anh cho chung tu khac chay duoc'
);
select is(
  (select reused_from_id from public.attachments where doc_id = 'd0160000-1600-4000-8000-000000000702'),
  (select id from public.attachments where doc_id = 'd0160000-1600-4000-8000-000000000701'),
  'dong dung lai ghi reused_from_id tro ve anh goc'
);

select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a02', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a02","role":"authenticated"}', true);
select is(
  (select count(*) from public.alerts where code = 'PHOTO_REUSED'),
  1::bigint,
  'dung lai anh tao dung 1 alert PHOTO_REUSED'
);
select is(
  (select severity from public.alerts where code = 'PHOTO_REUSED' order by created_at limit 1),
  'red',
  'alert PHOTO_REUSED muc red'
);
select is(
  (select payload ->> 'sha256' from public.alerts where code = 'PHOTO_REUSED' order by created_at limit 1),
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'payload alert chua dung sha256'
);

-- 10. Nguoi khong co alert.receive.photo_reused khong thay alert.
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a01","role":"authenticated"}', true);
select is(
  (select count(*) from public.alerts where code = 'PHOTO_REUSED'),
  0::bigint,
  'receiver khong co quyen nhan alert thi khong thay PHOTO_REUSED'
);

-- 11. attachment_register: sai SHA / sai duong dan / sai bucket / sai quyen.
select throws_ok(
  $q$select public.attachment_register(
    'd0160000-1600-4000-8000-000000000201', 'evidence',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000804.jpg',
    'khong-phai-sha256',
    'receiving', 'd0160000-1600-4000-8000-000000000703'
  )$q$,
  'ERR_ATTACHMENT_INVALID_SHA',
  'sha256 sai dinh dang bi chan'
);
select throws_ok(
  $q$select public.attachment_register(
    'd0160000-1600-4000-8000-000000000201', 'evidence',
    'd0160000-1600-4000-8000-000000000102/receiving/2026/11/d0160000-1600-4000-8000-000000000804.jpg',
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'receiving', 'd0160000-1600-4000-8000-000000000703'
  )$q$,
  'ERR_ATTACHMENT_PATH_MISMATCH',
  'duong dan thuoc phap nhan khac bi chan'
);
select throws_ok(
  $q$select public.attachment_register(
    'd0160000-1600-4000-8000-000000000201', 'khong-co-bucket',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000804.jpg',
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'receiving', 'd0160000-1600-4000-8000-000000000703'
  )$q$,
  'ERR_INVALID_VALUE',
  'bucket la bi chan'
);

select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a03","role":"authenticated"}', true);
select throws_ok(
  $q$select public.attachment_register(
    'd0160000-1600-4000-8000-000000000201', 'evidence',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000804.jpg',
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    'receiving', 'd0160000-1600-4000-8000-000000000703'
  )$q$,
  'ERR_FORBIDDEN:attachment.upload',
  'viewer khong dang ky duoc anh'
);

-- 12b. attachment_list: nguoi co attachment.view thay duoc anh cua chung tu;
--      nguoi khong co quyen bi chan.
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a01","role":"authenticated"}', true);
select is(
  (select jsonb_array_length(public.attachment_list(
    'd0160000-1600-4000-8000-000000000201', 'receiving', 'd0160000-1600-4000-8000-000000000701'
  ))),
  1,
  'attachment_list tra 1 anh cua chung tu 701 cho nguoi co attachment.view'
);

select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a03","role":"authenticated"}', true);
select throws_ok(
  $q$select public.attachment_list(
    'd0160000-1600-4000-8000-000000000201', 'receiving', 'd0160000-1600-4000-8000-000000000701'
  )$q$,
  'ERR_FORBIDDEN:attachment.view',
  'viewer khong liet ke duoc anh (thieu attachment.view)'
);

-- 12. RLS bang attachments: user KS B khong thay anh KS A; user khong co
--     attachment.view khong thay anh nao.
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a04', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a04","role":"authenticated"}', true);
select is(
  (select count(*) from public.attachments where property_id = 'd0160000-1600-4000-8000-000000000201'),
  0::bigint,
  'user KS B khong SELECT duoc attachments cua KS A'
);

select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a03', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a03","role":"authenticated"}', true);
select is(
  (select count(*) from public.attachments where property_id = 'd0160000-1600-4000-8000-000000000201'),
  0::bigint,
  'user khong co attachment.view khong SELECT duoc attachments'
);

-- 13. Storage policy INSERT: user chi co quyen KS A chen duoc object duoi phap
--     nhan A, khong chen duoc duoi phap nhan B.
select lives_ok(
  $q$insert into storage.objects (bucket_id, name)
  values (
    'evidence',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000805.jpg'
  )$q$,
  'user KS A chen duoc object duoi phap nhan A'
);
select lives_ok(
  $q$insert into storage.objects (bucket_id, name)
  values (
    'evidence',
    'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000801.jpg'
  )$q$,
  'user KS A chen duoc object co dong attachments tro toi (duong dan cua chung tu 701)'
);
select throws_ok(
  $q$insert into storage.objects (bucket_id, name)
  values (
    'evidence',
    'd0160000-1600-4000-8000-000000000102/receiving/2026/11/d0160000-1600-4000-8000-000000000804.jpg'
  )$q$,
  'row-level security',
  'user KS A khong chen duoc object duoi phap nhan B'
);

-- 14. Storage policy SELECT: object chi thay duoc khi co dong attachments tro
--     toi no (va co attachment.view); object khong co attachments thi khong thay.
select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a01', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a01","role":"authenticated"}', true);
select is(
  (select count(*) from storage.objects
   where name = 'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000805.jpg'),
  0::bigint,
  'object khong co dong attachments thi khong SELECT duoc'
);
select is(
  (select count(*) from storage.objects
   where name = 'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000801.jpg'),
  1::bigint,
  'object co dong attachments thi SELECT duoc (u1 co attachment.view)'
);

select set_config('request.jwt.claim.sub', 'd0160000-1600-4000-8000-000000000a04', true);
select set_config('request.jwt.claims', '{"sub":"d0160000-1600-4000-8000-000000000a04","role":"authenticated"}', true);
select is(
  (select count(*) from storage.objects
   where name = 'd0160000-1600-4000-8000-000000000101/receiving/2026/11/d0160000-1600-4000-8000-000000000801.jpg'),
  0::bigint,
  'user KS B khong SELECT duoc object cua KS A du co dong attachments'
);

select * from finish();
rollback;
