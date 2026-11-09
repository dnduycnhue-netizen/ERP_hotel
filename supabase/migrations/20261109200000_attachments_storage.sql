-- T-016: Storage `evidence` + `attachments` + bang `attachments` + RPC dang ky anh
-- + alert PHOTO_REUSED khi trung SHA-256.
--
-- Dac ta: docs/03-DATA-MODEL.md (bang attachments, migration 05), docs/02-ARCHITECTURE.md
-- muc 6 (chup trong app, nen 1280px JPEG 0.7, SHA-256 o may, bucket private, duong dan
-- {legal_entity_id}/{doc_type}/{yyyy}/{mm}/{uuid}.jpg, xem bang signed URL),
-- docs/04-SECURITY-RLS.md muc 9 (bucket evidence private; INSERT theo phap nhan co quyen;
-- SELECT qua bang attachments; khong UPDATE/DELETE object), docs/08-REPORTS-ALERTS.md
-- (PHOTO_REUSED, muc red, kenh App).
--
-- Decisions (spec im lang hoac mo):
--   1. Hai bucket: `evidence` (anh chup bang chung, theo spec) + `attachments` (bucket
--      chung cho tai lieu dinh kem khong phai anh chup, vd. hop dong/hdon o T-040+).
--      Cung mo hinh bao mat: private, duong dan bat dau bang legal_entity_id.
--   2. Bang `attachments` la bang chung: chi ghi qua RPC (SECURITY DEFINER), khong co
--      policy INSERT/UPDATE/DELETE cho authenticated; trigger chan UPDATE/DELETE
--      (anh chung tu bat bien — sua sai = tai anh moi). Audit trigger ghi INSERT.
--   3. Trung hash duoc xet TOAN CHUOI (cung org_id): cung mot anh dung lai o KS khac
--      trong chuoi van la dung lai. Dang ky lai cung anh cho CUNG chung tu thi tra ve
--      ban ghi cu (luy thua), khong tao alert, khong tao dong moi.
--   4. Trung hash chi tao ALERT (khong chan upload): spec chi yeu cau alert
--      PHOTO_REUSED; viec chan hay cho phep dung lai la quyet dinh cua nguoi
--      hau kiem (quyen receiving.review_photos) o T-023/T-024.
--   5. Quyen `attachment.upload` / `attachment.view` CHUA co trong danh muc quyen
--      (chi co `receiving.review_photos` + `alert.receive.photo_reused` da seed san
--      o 20261108141000) nen migration nay chen moi 2 ma quyen, module 'Nhan hang'.
--   6. Vai tro `owner` DUOC gan ca 3 quyen moi. Ly do: `has_perm` khong co dac cach
--      owner/sys_admin (chi doc role_permissions); tren production owner dang co
--      dung 109 quyen tu luc setup tay 09/11, cac quyen moi cua T-013/T-014/T-015
--      (supplier.view, item.import, alert.receive.temp_item_stale...) deu KHONG
--      tu dong ve owner. Khong gan owner thi chuoi khong xem duoc anh bang chung
--      cua chinh minh. `sys_admin` KHONG duoc gan (theo thiet ke chi co quyen
--      quan tri, khong co quyen nghiep vu). Luu y: cac quyen moi cua T-013/T-014/
--      T-015 hien cung thieu tren owner production — can mot migration sua rieng
--      hoac cap tay 1 cau SQL (xem Q17).
--   7. `doc_type` de dang text tu do (receiving, count, waste, minibar, ...) — chua
--      co bang tham chieu vi nguoi dung dau tien (T-023) moi dinh nghia tap gia tri
--      (xem Q15).
--   8. Signed URL het han 300 giay ("thoi han ngan" theo spec) — do server action
--      quyet dinh, khong luu trong DB.
--   9. `taken_at` lay gio may chu (now()); `device_time` chi de doi chieu, khong
--      dung lam thoi diem nghiep vu (AGENTS.md muc 2 rule 8).

-- ---------------------------------------------------------------------------
-- 1. Ma quyen moi (chen vao danh muc; alert.receive.photo_reused da seed san).
-- ---------------------------------------------------------------------------
insert into public.permissions (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('attachment.upload', 'Nhận hàng', 'Tải ảnh chứng từ', 'Chụp và tải ảnh chứng từ (nhận hàng, kiểm kê, hủy hàng, minibar).', 'sensitive', 435),
  ('attachment.view', 'Nhận hàng', 'Xem ảnh chứng từ', 'Xem ảnh chứng từ trong phạm vi khách sạn được cấp.', 'normal', 436)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- 2. Buckets (private).
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('evidence', 'evidence', false),
  ('attachments', 'attachments', false)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- 3. Bang attachments (03-DATA-MODEL.md A5 + cot pham vi theo AGENTS.md rule 5).
-- ---------------------------------------------------------------------------
create table if not exists public.attachments (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  bucket text not null check (bucket in ('evidence', 'attachments')),
  path text not null unique,
  sha256 text not null check (sha256 ~ '^[0-9a-f]{64}$'),
  doc_type text not null check (btrim(doc_type) <> ''),
  doc_id uuid not null,
  line_id uuid,
  taken_at timestamptz not null default now(),
  device_time timestamptz,
  uploaded_by uuid not null references auth.users(id) default auth.uid(),
  device_info jsonb not null default '{}'::jsonb
    check (jsonb_typeof(device_info) = 'object'),
  reused_from_id uuid references public.attachments(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists attachments_doc_idx
  on public.attachments (doc_type, doc_id);
create index if not exists attachments_sha256_idx
  on public.attachments (sha256);
create index if not exists attachments_property_created_idx
  on public.attachments (property_id, created_at desc);

alter table public.attachments enable row level security;

-- Chi SELECT qua RLS; ghi chi qua RPC (khong co policy INSERT/UPDATE/DELETE).
drop policy if exists attachments_select on public.attachments;
create policy attachments_select on public.attachments
for select to authenticated
using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'attachment.view')
    or public.has_perm(null, 'attachment.view')
  )
);

-- Anh chung tu bat bien: sua sai = tai anh moi (tuong tu so cai, AGENTS.md rule 2).
create or replace function public._attachments_forbid_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'ERR_ATTACHMENT_IMMUTABLE';
end;
$$;

drop trigger if exists trg_attachments_forbid_mutation on public.attachments;
create trigger trg_attachments_forbid_mutation
before update or delete on public.attachments
for each row execute function public._attachments_forbid_mutation();

drop trigger if exists trg_attachments_audit on public.attachments;
create trigger trg_attachments_audit
after insert on public.attachments
for each row execute function public.audit_trigger();

-- ---------------------------------------------------------------------------
-- 4. Storage policies (04-SECURITY-RLS.md muc 9): INSERT theo phap nhan co
--    quyen; SELECT qua bang attachments; KHONG co policy UPDATE/DELETE.
-- ---------------------------------------------------------------------------
drop policy if exists evidence_insert on storage.objects;
create policy evidence_insert on storage.objects
for insert to authenticated
with check (
  bucket_id in ('evidence', 'attachments')
  and exists (
    select 1
    from public.properties p
    where p.legal_entity_id::text = (storage.foldername(name))[1]
      and p.id in (select public.my_property_ids())
  )
);

drop policy if exists evidence_select on storage.objects;
create policy evidence_select on storage.objects
for select to authenticated
using (
  bucket_id in ('evidence', 'attachments')
  and exists (
    select 1
    from public.attachments a
    where a.bucket = storage.objects.bucket_id
      and a.path = storage.objects.name
      and a.property_id in (select public.my_property_ids())
      and (
        public.has_perm(a.property_id, 'attachment.view')
        or public.has_perm(null, 'attachment.view')
      )
  )
);

-- ---------------------------------------------------------------------------
-- 5. RPC: chuan bi duong dan upload (quyen + duong dan theo spec).
--    Tra ve jsonb { ok, bucket, legal_entity_id, path }.
-- ---------------------------------------------------------------------------
create or replace function public.attachment_prepare_upload(
  p_property_id uuid,
  p_doc_type text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_le uuid;
  v_path text;
begin
  perform public.require_perm(p_property_id, 'attachment.upload');
  if p_doc_type is null or btrim(p_doc_type) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select legal_entity_id into v_le
  from public.properties
  where id = p_property_id;
  if v_le is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  -- {legal_entity_id}/{doc_type}/{yyyy}/{mm}/{uuid}.jpg (02-ARCHITECTURE.md muc 6).
  v_path := v_le::text || '/' || btrim(p_doc_type) || '/'
    || to_char(now() at time zone 'Asia/Ho_Chi_Minh', 'YYYY/MM') || '/'
    || gen_random_uuid()::text || '.jpg';

  return jsonb_build_object(
    'ok', true,
    'bucket', 'evidence',
    'legal_entity_id', v_le,
    'path', v_path
  );
end;
$$;

revoke all on function public.attachment_prepare_upload(uuid, text)
  from public, anon;
grant execute on function public.attachment_prepare_upload(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6. RPC: dang ky anh sau khi upload xong (kiem tra quyen + duong dan, ghi
--    dong attachments, phat hien trung SHA-256 toan chuoi -> alert PHOTO_REUSED
--    muc red). Tra ve jsonb { ok, id, reused, reused_attachment_id }.
-- ---------------------------------------------------------------------------
create or replace function public.attachment_register(
  p_property_id uuid,
  p_bucket text,
  p_path text,
  p_sha256 text,
  p_doc_type text,
  p_doc_id uuid,
  p_line_id uuid default null,
  p_device_time timestamptz default null,
  p_device_info jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org uuid;
  v_le uuid;
  v_same_doc_id uuid;
  v_existing_id uuid;
  v_existing_doc_type text;
  v_existing_doc_id uuid;
  v_reused boolean := false;
  v_id uuid;
begin
  perform public.require_perm(p_property_id, 'attachment.upload');

  if p_bucket not in ('evidence', 'attachments') then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_sha256 is null or p_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'ERR_ATTACHMENT_INVALID_SHA';
  end if;
  if p_doc_type is null or btrim(p_doc_type) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_doc_id is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_path is null or btrim(p_path) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select org_id, legal_entity_id into v_org, v_le
  from public.properties
  where id = p_property_id;
  if v_org is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  -- Duong dan phai nam dung thu muc phap nhan + loai chung tu (chong gia mao).
  if split_part(btrim(p_path), '/', 1) <> v_le::text
    or split_part(btrim(p_path), '/', 2) <> btrim(p_doc_type)
    or right(btrim(p_path), 4) <> '.jpg' then
    raise exception 'ERR_ATTACHMENT_PATH_MISMATCH';
  end if;

  -- Cung anh + cung chung tu: tra ve ban ghi cu (luy thua), khong tao alert.
  select id into v_same_doc_id
  from public.attachments
  where org_id = v_org
    and sha256 = p_sha256
    and doc_type = btrim(p_doc_type)
    and doc_id = p_doc_id
  order by created_at asc
  limit 1;
  if v_same_doc_id is not null then
    return jsonb_build_object(
      'ok', true,
      'id', v_same_doc_id,
      'reused', false,
      'reused_attachment_id', null
    );
  end if;

  -- Trung hash voi anh cu o chung tu khac (toan chuoi) -> danh dau dung lai.
  select id, doc_type, doc_id
    into v_existing_id, v_existing_doc_type, v_existing_doc_id
  from public.attachments
  where org_id = v_org
    and sha256 = p_sha256
  order by created_at asc
  limit 1;
  v_reused := v_existing_id is not null;

  insert into public.attachments (
    org_id, legal_entity_id, property_id, bucket, path, sha256,
    doc_type, doc_id, line_id, device_time, device_info, reused_from_id
  )
  values (
    v_org, v_le, p_property_id, p_bucket, btrim(p_path), p_sha256,
    btrim(p_doc_type), p_doc_id, p_line_id, p_device_time,
    coalesce(p_device_info, '{}'::jsonb), v_existing_id
  )
  returning id into v_id;

  if v_reused then
    perform public._create_alert(
      p_property_id,
      'PHOTO_REUSED',
      'red',
      'Ảnh chứng từ bị dùng lại',
      jsonb_build_object(
        'sha256', p_sha256,
        'reused_from_id', v_existing_id,
        'original_doc_type', v_existing_doc_type,
        'original_doc_id', v_existing_doc_id,
        'new_doc_type', btrim(p_doc_type),
        'new_doc_id', p_doc_id
      ),
      btrim(p_doc_type),
      p_doc_id
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'id', v_id,
    'reused', v_reused,
    'reused_attachment_id', v_existing_id
  );
end;
$$;

revoke all on function public.attachment_register(uuid, text, text, text, text, uuid, uuid, timestamptz, jsonb)
  from public, anon;
grant execute on function public.attachment_register(uuid, text, text, text, text, uuid, uuid, timestamptz, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6b. RPC: liet ke anh cua mot chung tu (doc tra ve jsonb; server action dung
--     de tao signed URL tung anh). Quyen attachment.view kiem tra trong ham
--     (ham SECURITY DEFINER nen RLS bang khong ap dung truc tiep).
-- ---------------------------------------------------------------------------
create or replace function public.attachment_list(
  p_property_id uuid,
  p_doc_type text,
  p_doc_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_rows jsonb;
begin
  perform public.require_perm(p_property_id, 'attachment.view');
  if p_doc_type is null or btrim(p_doc_type) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_doc_id is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', a.id,
        'bucket', a.bucket,
        'path', a.path,
        'sha256', a.sha256,
        'doc_type', a.doc_type,
        'doc_id', a.doc_id,
        'line_id', a.line_id,
        'taken_at', a.taken_at,
        'device_time', a.device_time,
        'uploaded_by', a.uploaded_by,
        'reused_from_id', a.reused_from_id,
        'created_at', a.created_at
      )
      order by a.created_at desc
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.attachments a
  where a.property_id = p_property_id
    and a.doc_type = btrim(p_doc_type)
    and a.doc_id = p_doc_id;

  return v_rows;
end;
$$;

revoke all on function public.attachment_list(uuid, text, uuid)
  from public, anon;
grant execute on function public.attachment_list(uuid, text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Gan quyen cho vai tro mau (join theo ma vai tro, khong loc them).
--    attachment.upload: nguoi chup anh hien truong. attachment.view: nguoi
--    xem/duyet chung tu + kiem soat. alert.receive.photo_reused: nguoi hau
--    kiem (giong TEMP_ITEM_STALE / BANK_ACCOUNT_CHANGE).
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('owner', 'attachment.upload'),
  ('owner', 'attachment.view'),
  ('owner', 'alert.receive.photo_reused'),
  ('gm', 'attachment.view'),
  ('gm', 'alert.receive.photo_reused'),
  ('chief_accountant', 'attachment.view'),
  ('chief_accountant', 'alert.receive.photo_reused'),
  ('cost_controller', 'attachment.view'),
  ('cost_controller', 'alert.receive.photo_reused'),
  ('accountant', 'attachment.view'),
  ('internal_audit', 'attachment.view'),
  ('receiver', 'attachment.upload'),
  ('receiver', 'attachment.view'),
  ('storekeeper', 'attachment.upload'),
  ('storekeeper', 'attachment.view'),
  ('purchaser', 'attachment.upload'),
  ('purchaser', 'attachment.view'),
  ('outlet_head', 'attachment.upload'),
  ('outlet_head', 'attachment.view'),
  ('chef', 'attachment.upload'),
  ('chef', 'attachment.view'),
  ('bartender', 'attachment.upload'),
  ('bartender', 'attachment.view'),
  ('engineer', 'attachment.upload'),
  ('engineer', 'attachment.view'),
  ('hk_supervisor', 'attachment.upload'),
  ('hk_supervisor', 'attachment.view'),
  ('hk_attendant', 'attachment.upload'),
  ('hk_attendant', 'attachment.view'),
  ('front_desk', 'attachment.upload'),
  ('front_desk', 'attachment.view')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109200000_attachments_storage',
  'INSERT',
  jsonb_build_object('event', 'attachments_storage_created', 'task', 'T-016'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
