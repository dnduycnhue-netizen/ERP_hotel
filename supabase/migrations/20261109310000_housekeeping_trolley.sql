-- ===========================================================================
-- T-034: DB foundation buong phong — chuan setup, kho tang/xe day, ca xe day.
--   (docs/modules/M07-housekeeping-minibar.md + docs/05-BUSINESS-RULES.md §7.1
--    + docs/03-DATA-MODEL.md A8 + docs/09-API-RPC.md)
--   Chi DB + RPC + seed. KHONG UI (man hinh minibar/buong phong: T-035+).
--
-- QUYET DINH THIET KE (da kiem chung tu repo, xem them Q41-Q49):
--   1. Par xe day luu o bang rieng `trolley_par_levels` (trolley_wh, item,
--      par_qty) thay vi cot tren warehouses: par thay doi theo mua/ca, can
--      lich su qua RPC upsert; warehouses chi giu cau truc kho.
--   2. Check `warehouses` (141000 ~dong 142) bat outlet_id voi kind
--      outlet/floor/trolley KHONG mau thuan voi spec: kho tang/xe day GAN
--      outlet HOUSEKEEPING (requisition_save_draft cung bat to_wh.outlet_id
--      = outlet cua phieu). Khong can sua migration cu, khong mo Q ve viec nay.
--   3. `item_groups.kind` (030000) DA co du 8 kind cua M07 (amenity,
--      complimentary, collateral, linen, loan, chemical, tool, minibar):
--      khong can ALTER gi.
--   4. Khong co permission code moi: dung lai `hk.standard.manage` (quan ly
--      chuan + par) va `hk.trolley.operate` (mo/dong ca) da co trong catalog
--      (141000) va da gan cho hk_supervisor / hk_attendant (140000).
--   5. Phieu linh bu top-up: tao NOI BO trong trolley_shift_open (ghi truc
--      tiep + goi _generate_approval_steps), KHONG goi requisition_save_draft
--      vi RPC do doi `requisition.create` (nhan vien buong khong co).
--      Trang thai 'submitted' + 1 buoc duyet outlet_head theo ma tran mac
--      dinh da seed o 260000 §15; duyet/xuat/nhan di theo luong T-030 binh
--      thuong (xem Q48: nguoi duyet).
--   6. Dong ca: tieu hao = dau + linh - cuoi, ghi purpose_issue
--      purpose_code 'housekeeping' (MOI — ALTER CHECK cua purpose_issues
--      trong migration nay, khong sua file 260000), cost center ROOMS,
--      khoan muc GUEST_SUPPLIES, post truc tiep bang _post_move (khong goi
--      purpose_issue_post vi RPC do doi `purpose_issue.post` — nhan vien
--      buong khong co; cap quyen do cho attendant thi qua rong).
--   7. Kho tang nguon: chon kho kind='floor' DUY NHAT cung outlet_id +
--      property voi xe day. Neu co 0 hoac >1 kho tang thi van mo ca duoc,
--      khong sinh phieu linh (ly do ghi trong top_up_note cua response) —
--      xem Q41.
--   8. Tieu hao am (dem cuoi > dau + linh): KHONG ghi tieu hao am — clamp ve
--      0, liet ke vao surplus_lines (response) + ghi chu tren purpose_issue.
--      Hang thua tra ve kho tang bang phieu rieng, chua co trong task nay
--      (xem Q44).
--   9. Dem mo/dong ca la dem MU: book_qty luon NULL tren stock_count_lines
--      (khong dien ton so), dong count o status 'submitted' ngay khi tao.
--      Count kind='trolley' KHONG dong bang kho (freeze guard 280000 chi
--      dong monthly_full) nen xe day van xuat/nhap binh thuong trong ca.
--  10. Chenh lech dem cuoi ca so voi ton so tinh tu moves KHONG tu dong
--      dieu chinh ton kho trolley (doi chieu ly thuyet P2 thuoc T-035+).
--      Ton trolley sau dong ca = dau + linh - tieu hao (theo cong thuc).
--  11. Dinh muc tham khao thang 5/2019 (M07 §4: ban chai 0,89; giay ve sinh
--      0,72 cuon; nuoc 1,94 chai; ca phe 0,77 goi / dem phong) KHONG seed
--      cung trong migration vi seed khong co items; nhap qua RPC
--      room_setup_standard_set / trolley_par_set sau khi co items that
--      (xem Q47).
--  12. Cost center ROOMS + khoan muc GUEST_SUPPLIES duoc tu tao (idempotent)
--      cho moi org hien co neu thieu — theo tien le seed ma tran duyet o
--      210000 §8 / 260000 §15. Org moi tao sau nay: admin tao qua CRUD
--      master-data (xem Q47).
--  13. `requisition.receive` gan them cho role `hk_attendant` (join theo ma
--      role, no-op neu role chua co) de nhan vien buong xac nhan nhan hang
--      top-up vao xe day. hk_supervisor da co quyen nay (140000).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Bang chuan setup phong (03-DATA-MODEL.md A8).
--    unique (room_type_id, clean_type, item_id, per_guest): cung 1 item co
--    the vua co dinh muc/phong vua co dinh muc/khach (vd nuoc 2 chai/phong
--    + 1 chai/khach). Xem Q43.
-- ---------------------------------------------------------------------------
create table public.room_setup_standards (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  room_type_id uuid not null,
  clean_type text not null check (clean_type in (
    'checkout', 'stayover', 'vip', 'child'
  )),
  item_id uuid not null,
  qty numeric(18,4) not null check (qty >= 0),
  per_guest boolean not null default false,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (room_type_id, clean_type, item_id, per_guest),
  foreign key (room_type_id, property_id)
    references public.room_types(id, property_id),
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (property_id, org_id) references public.properties(id, org_id)
);
create index on public.room_setup_standards (property_id, room_type_id, clean_type);

-- ---------------------------------------------------------------------------
-- 2. Muc par tren xe day (quyet dinh 1).
-- ---------------------------------------------------------------------------
create table public.trolley_par_levels (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  trolley_warehouse_id uuid not null references public.warehouses(id),
  item_id uuid not null,
  par_qty numeric(18,4) not null check (par_qty >= 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (trolley_warehouse_id, item_id),
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (property_id, org_id) references public.properties(id, org_id)
);
create index on public.trolley_par_levels (trolley_warehouse_id);

-- ---------------------------------------------------------------------------
-- 3. Bang ca xe day (03-DATA-MODEL.md dong 116) + 2 cot lien ket chung tu
--    (requisition_id: phieu linh bu top-up; purpose_issue_id: phieu tieu hao)
--    + 2 cot audit dong ca (closed_by/closed_at). status 'cancelled' giu
--    cho RPC huy ca tuong lai (Q42) — hien chua co RPC nao dat trang thai nay.
-- ---------------------------------------------------------------------------
create table public.trolley_shifts (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  trolley_warehouse_id uuid not null references public.warehouses(id),
  attendant_id uuid not null references auth.users(id),
  business_date date not null,
  shift text not null default 'day',
  opening_count_id uuid references public.stock_counts(id),
  closing_count_id uuid references public.stock_counts(id),
  rooms_done jsonb not null default '[]'::jsonb
    check (jsonb_typeof(rooms_done) = 'array'),
  status text not null default 'open' check (status in (
    'open', 'closed', 'cancelled'
  )),
  requisition_id uuid references public.requisitions(id),
  purpose_issue_id uuid references public.purpose_issues(id),
  closed_by uuid references auth.users(id),
  closed_at timestamptz,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  foreign key (property_id, org_id) references public.properties(id, org_id)
);
create index on public.trolley_shifts (property_id, trolley_warehouse_id, business_date);
-- Chi 1 ca dang mo cho 1 xe day / ngay / ten ca (ca mac dinh 'day'; KS 2 ca
-- thi truyen shift khac nhau, vd 'morning'/'evening' — xem Q46).
create unique index trolley_shifts_one_open_idx
  on public.trolley_shifts (trolley_warehouse_id, business_date, shift)
  where status = 'open';

-- ---------------------------------------------------------------------------
-- 4. Trigger updated_at + write-guard (mau T-030/T-032).
--    room_setup_standards / trolley_par_levels la master data: chi RLS
--    SELECT-only (khong trigger guard), giong bang items — ghi qua RPC.
--    trolley_shifts la chung tu nghiep vu: them write-guard.
-- ---------------------------------------------------------------------------
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'room_setup_standards', 'trolley_par_levels', 'trolley_shifts'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || v_table || '_updated_at', v_table
    );
  end loop;
end $$;

create or replace function public._hk_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.hk_guard_bypass', true), '') <> 'on' then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_WRITE_GUARD: ' || TG_TABLE_NAME || ' chi duoc ghi qua RPC';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger trg_trolley_shifts_write_guard
before insert or update or delete on public.trolley_shifts
for each row execute function public._hk_write_guard();

-- ---------------------------------------------------------------------------
-- 5. RLS: bat 100% + policy SELECT-only (mau T-030 §5). Ghi truc tiep bi
--    chan (khong co policy INSERT/UPDATE/DELETE); RPC SECURITY DEFINER ghi.
--    Dung `in (select public.my_property_ids())` — TUYET DOI KHONG dung
--    `= any (public.my_property_ids())` (loi 0A000 khi db push).
-- ---------------------------------------------------------------------------
alter table public.room_setup_standards enable row level security;
alter table public.trolley_par_levels enable row level security;
alter table public.trolley_shifts enable row level security;

create policy room_setup_standards_select on public.room_setup_standards
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'hk.standard.manage')
    or public.has_perm(property_id, 'hk.trolley.operate')
  )
);

create policy trolley_par_levels_select on public.trolley_par_levels
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'hk.standard.manage')
    or public.has_perm(property_id, 'hk.trolley.operate')
  )
);

create policy trolley_shifts_select on public.trolley_shifts
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'hk.trolley.operate')
    or public.has_perm(property_id, 'hk.standard.manage')
  )
);

-- ---------------------------------------------------------------------------
-- 6. Du lieu tham chieu idempotent cho moi org hien co (quyet dinh 12):
--    cost center ROOMS + khoan muc GUEST_SUPPLIES. Org moi: tao qua CRUD.
-- ---------------------------------------------------------------------------
insert into public.cost_centers (org_id, code, name, usali_department)
select o.id, 'ROOMS', 'Buồng phòng', 'Rooms'
from public.organizations o
where not exists (
  select 1 from public.cost_centers cc
  where cc.org_id = o.id and cc.code = 'ROOMS'
);

insert into public.expense_categories (org_id, code, name, usali_line)
select o.id, 'GUEST_SUPPLIES', 'Guest supplies', 'Rooms'
from public.organizations o
where not exists (
  select 1 from public.expense_categories ec
  where ec.org_id = o.id and ec.code = 'GUEST_SUPPLIES'
);

-- ---------------------------------------------------------------------------
-- 7. Gan `requisition.receive` cho hk_attendant (quyet dinh 13).
--    Chi grant code DA CO; khong co permission code moi trong migration nay.
-- ---------------------------------------------------------------------------
insert into public.role_permissions (role_id, permission_code)
select r.id, 'requisition.receive'
from public.roles r
where r.code = 'hk_attendant'
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 8. Them purpose_code 'housekeeping' cho phieu tieu hao ca (quyet dinh 6).
--    Ten constraint tim dong (constraint goc do 260000 tao, ten mac dinh
--    cua Postgres) roi tao lai voi ten tuong minh.
-- ---------------------------------------------------------------------------
do $$
declare
  v_con name;
begin
  select conname into v_con
  from pg_constraint
  where conrelid = 'public.purpose_issues'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%purpose_code%';
  if v_con is not null then
    execute format('alter table public.purpose_issues drop constraint %I', v_con);
  end if;
end $$;

alter table public.purpose_issues
add constraint purpose_issues_purpose_code_check
check (purpose_code in (
  'staff_meal', 'vip_comp', 'marketing', 'meeting', 'training', 'repair',
  'other', 'housekeeping'
));

-- ---------------------------------------------------------------------------
-- 9. Helper noi bo: parse p_counts jsonb [{item_id, qty}] thanh tap dong.
--    qty tinh theo stock UOM cua item. Khong grant execute: chi cac RPC
--    SECURITY DEFINER (chay duoi quyen postgres) moi goi duoc.
-- ---------------------------------------------------------------------------
create or replace function public._hk_parse_counts(
  p_counts jsonb,
  p_org_id uuid
)
returns table (item_id uuid, qty numeric)
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_el jsonb;
  v_item uuid;
  v_qty numeric;
  v_seen uuid[] := '{}';
begin
  if p_counts is null or jsonb_typeof(p_counts) <> 'array' then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: p_counts phai la mang JSON';
  end if;

  for v_el in select * from jsonb_array_elements(p_counts) loop
    if jsonb_typeof(v_el) <> 'object' then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: moi phan tu p_counts phai la object';
    end if;

    begin
      v_item := (v_el ->> 'item_id')::uuid;
    exception when others then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: item_id khong hop le';
    end;

    if v_item = any (v_seen) then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: trung item_id trong p_counts';
    end if;
    v_seen := v_seen || v_item;

    if v_el ->> 'qty' is null then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: thieu qty trong p_counts';
    end if;
    begin
      v_qty := (v_el ->> 'qty')::numeric;
    exception when others then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: qty khong hop le';
    end;
    if v_qty < 0 then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: qty khong duoc am';
    end if;

    if not exists (
      select 1 from public.items i
      where i.id = v_item and i.org_id = p_org_id
    ) then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: item khong ton tai hoac khac org';
    end if;

    item_id := v_item;
    qty := v_qty;
    return next;
  end loop;
end;
$$;

revoke all on function public._hk_parse_counts(jsonb, uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 10. RPC quan ly chuan setup: upsert theo
--     (room_type_id, clean_type, item_id, per_guest).
-- ---------------------------------------------------------------------------
create or replace function public.room_setup_standard_set(
  p_property_id uuid,
  p_room_type_id uuid,
  p_clean_type text,
  p_item_id uuid,
  p_qty numeric,
  p_per_guest boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_rt record;
  v_it record;
  v_id uuid;
begin
  perform public.require_perm(p_property_id, 'hk.standard.manage');

  if p_clean_type not in ('checkout', 'stayover', 'vip', 'child') then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: clean_type khong hop le';
  end if;
  if p_qty is null or p_qty < 0 then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: qty khong duoc am';
  end if;

  select p.org_id into v_org_id
  from public.properties p where p.id = p_property_id;
  if v_org_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: property khong ton tai';
  end if;

  select * into v_rt from public.room_types rt where rt.id = p_room_type_id;
  if v_rt is null or v_rt.property_id <> p_property_id then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: room_type khong thuoc property';
  end if;

  select * into v_it from public.items i where i.id = p_item_id;
  if v_it is null or v_it.org_id <> v_org_id then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: item khong ton tai hoac khac org';
  end if;
  if v_it.is_temp then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: khong dung ma tam lam chuan setup';
  end if;

  insert into public.room_setup_standards (
    org_id, property_id, room_type_id, clean_type, item_id, qty, per_guest,
    created_by
  ) values (
    v_org_id, p_property_id, p_room_type_id, p_clean_type, p_item_id,
    p_qty, coalesce(p_per_guest, false), auth.uid()
  )
  on conflict (room_type_id, clean_type, item_id, per_guest)
  do update set qty = excluded.qty, updated_at = now()
  returning id into v_id;

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'room_type_id', p_room_type_id,
    'clean_type', p_clean_type, 'item_id', p_item_id, 'qty', p_qty,
    'per_guest', coalesce(p_per_guest, false)
  );
end;
$$;

revoke all on function public.room_setup_standard_set(uuid, uuid, text, uuid, numeric, boolean)
  from public, anon, authenticated;
grant execute on function public.room_setup_standard_set(uuid, uuid, text, uuid, numeric, boolean)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 11. RPC quan ly par xe day: upsert theo (trolley_warehouse_id, item_id).
-- ---------------------------------------------------------------------------
create or replace function public.trolley_par_set(
  p_property_id uuid,
  p_trolley_warehouse_id uuid,
  p_item_id uuid,
  p_par_qty numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_wh record;
  v_it record;
  v_id uuid;
begin
  perform public.require_perm(p_property_id, 'hk.standard.manage');

  if p_par_qty is null or p_par_qty < 0 then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: par_qty khong duoc am';
  end if;

  select p.org_id into v_org_id
  from public.properties p where p.id = p_property_id;
  if v_org_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: property khong ton tai';
  end if;

  select * into v_wh from public.warehouses w
  where w.id = p_trolley_warehouse_id;
  if v_wh is null or v_wh.property_id <> p_property_id
    or v_wh.kind <> 'trolley' then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: kho xe day khong ton tai hoac sai kind';
  end if;

  select * into v_it from public.items i where i.id = p_item_id;
  if v_it is null or v_it.org_id <> v_org_id then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: item khong ton tai hoac khac org';
  end if;
  if v_it.is_temp then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: khong dung ma tam lam muc par';
  end if;

  insert into public.trolley_par_levels (
    org_id, property_id, trolley_warehouse_id, item_id, par_qty, created_by
  ) values (
    v_org_id, p_property_id, p_trolley_warehouse_id, p_item_id,
    p_par_qty, auth.uid()
  )
  on conflict (trolley_warehouse_id, item_id)
  do update set par_qty = excluded.par_qty, updated_at = now()
  returning id into v_id;

  return jsonb_build_object(
    'ok', true, 'id', v_id,
    'trolley_warehouse_id', p_trolley_warehouse_id,
    'item_id', p_item_id, 'par_qty', p_par_qty
  );
end;
$$;

revoke all on function public.trolley_par_set(uuid, uuid, uuid, numeric)
  from public, anon, authenticated;
grant execute on function public.trolley_par_set(uuid, uuid, uuid, numeric)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 12. RPC mo ca xe day.
--     p_counts: [{item_id, qty}] — so dem dau ca theo stock UOM (dem mu:
--     book_qty luon NULL). p_shift: ten ca, mac dinh 'day' (xem Q46).
--     Tra ve: shift_id, opening_count_id, requisition_id (null neu khong
--     can bu), top_up_lines, top_up_note (ly do khong sinh phieu linh).
-- ---------------------------------------------------------------------------
create or replace function public.trolley_shift_open(
  p_property_id uuid,
  p_trolley_wh uuid,
  p_counts jsonb,
  p_shift text default null,
  p_business_date date default (now() at time zone 'Asia/Ho_Chi_Minh')::date
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_entity_id uuid;
  v_wh record;
  v_shift text := coalesce(nullif(btrim(coalesce(p_shift, '')), ''), 'day');
  v_biz date := coalesce(
    p_business_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date
  );
  v_count_id uuid;
  v_doc_no text;
  v_floor_wh uuid;
  v_floor_n integer;
  v_req_id uuid;
  v_topup_n integer := 0;
  v_topup_note text;
  v_steps integer;
  v_shift_id uuid;
begin
  perform public.require_perm(p_property_id, 'hk.trolley.operate');

  select p.org_id, p.legal_entity_id into v_org_id, v_entity_id
  from public.properties p where p.id = p_property_id;
  if v_org_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: property khong ton tai';
  end if;

  select * into v_wh from public.warehouses w
  where w.id = p_trolley_wh and w.property_id = p_property_id;
  if v_wh is null or v_wh.kind <> 'trolley' then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: kho xe day khong ton tai hoac sai kind';
  end if;

  if exists (
    select 1 from public.trolley_shifts s
    where s.trolley_warehouse_id = p_trolley_wh
      and s.business_date = v_biz and s.shift = v_shift
      and s.status = 'open'
  ) then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_STATUS: da co ca dang mo cho xe day nay';
  end if;

  -- Dem dau ca (mu): tao stock_counts kind='trolley' o status 'submitted'
  -- ngay khi tao, book_qty NULL — khong lo ton so (quyet dinh 9).
  perform set_config('app.count_guard_bypass', 'on', true);
  v_doc_no := public.next_doc_no(v_entity_id, 'CNT', v_biz);
  insert into public.stock_counts (
    org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind,
    business_date, shift, status, counter_ids, opened_by, created_by
  ) values (
    v_org_id, v_entity_id, p_property_id, p_trolley_wh, v_doc_no,
    'trolley', v_biz, v_shift, 'submitted', array[auth.uid()],
    auth.uid(), auth.uid()
  )
  returning id into v_count_id;

  insert into public.stock_count_lines (
    count_id, org_id, item_id, count_detail,
    counted_qty_1, counted_by_1, final_qty, flag
  )
  select v_count_id, v_org_id, c.item_id, '{}'::jsonb,
    c.qty, auth.uid(), c.qty, 'ok'
  from public._hk_parse_counts(p_counts, v_org_id) c;

  -- Tim kho tang nguon: kind='floor' duy nhat cung outlet + property (Q41).
  select count(*), min(w.id) into v_floor_n, v_floor_wh
  from public.warehouses w
  where w.property_id = p_property_id
    and w.kind = 'floor'
    and w.outlet_id = v_wh.outlet_id;

  if v_floor_n = 1 then
    -- So can linh = par - ton dau ca (chi dong > 0), theo stock_count_lines
    -- vua ghi (item khong dem = 0).
    select count(*) into v_topup_n
    from public.trolley_par_levels tpl
    where tpl.trolley_warehouse_id = p_trolley_wh
      and tpl.par_qty > coalesce((
        select l.final_qty from public.stock_count_lines l
        where l.count_id = v_count_id and l.item_id = tpl.item_id
      ), 0);

    if v_topup_n > 0 then
      perform set_config('app.inventory_guard_bypass', 'on', true);
      -- _generate_approval_steps ghi bang approvals (co write-guard rieng
      -- o 210000): phai bat ca pr_po bypass nhu requisition_submit (260000).
      perform set_config('app.pr_po_guard_bypass', 'on', true);
      v_doc_no := public.next_doc_no(v_entity_id, 'REQ', v_biz);
      insert into public.requisitions (
        org_id, legal_entity_id, property_id, outlet_id,
        from_warehouse_id, to_warehouse_id, doc_no, business_date,
        status, note, created_by
      ) values (
        v_org_id, v_entity_id, p_property_id, v_wh.outlet_id,
        v_floor_wh, p_trolley_wh, v_doc_no, v_biz, 'submitted',
        'Top-up xe day ' || v_wh.code || ' ca ' || v_shift
          || ' ' || v_biz::text,
        auth.uid()
      )
      returning id into v_req_id;

      insert into public.requisition_lines (
        requisition_id, org_id, property_id, item_id, uom,
        qty, qty_stock, created_by
      )
      select v_req_id, v_org_id, p_property_id, tpl.item_id, i.stock_uom,
        tpl.par_qty - coalesce(l.final_qty, 0),
        tpl.par_qty - coalesce(l.final_qty, 0), auth.uid()
      from public.trolley_par_levels tpl
      join public.items i on i.id = tpl.item_id
      left join public.stock_count_lines l
        on l.count_id = v_count_id and l.item_id = tpl.item_id
      where tpl.trolley_warehouse_id = p_trolley_wh
        and tpl.par_qty > coalesce(l.final_qty, 0);

      v_steps := public._generate_approval_steps(
        'requisition', v_req_id, p_property_id, v_org_id, 0
      );
      if v_steps = 0 then
        raise exception using errcode = 'P0001',
          message = 'ERR_INVALID_VALUE: thieu ma tran duyet requisition (outlet_head)';
      end if;
    end if;
  elsif v_floor_n = 0 then
    v_topup_note := 'khong co kho tang cho outlet ' || v_wh.code;
  else
    v_topup_note := 'nhieu kho tang cho outlet ' || v_wh.code
      || ', can gan kho tang cho xe day';
  end if;

  perform set_config('app.hk_guard_bypass', 'on', true);
  insert into public.trolley_shifts (
    org_id, legal_entity_id, property_id, trolley_warehouse_id,
    attendant_id, business_date, shift, opening_count_id,
    requisition_id, status, created_by
  ) values (
    v_org_id, v_entity_id, p_property_id, p_trolley_wh,
    auth.uid(), v_biz, v_shift, v_count_id,
    v_req_id, 'open', auth.uid()
  )
  returning id into v_shift_id;

  return jsonb_build_object(
    'ok', true, 'shift_id', v_shift_id,
    'opening_count_id', v_count_id,
    'requisition_id', v_req_id,
    'top_up_lines', v_topup_n,
    'top_up_note', v_topup_note
  );
end;
$$;

revoke all on function public.trolley_shift_open(uuid, uuid, jsonb, text, date)
  from public, anon, authenticated;
grant execute on function public.trolley_shift_open(uuid, uuid, jsonb, text, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 13. RPC dong ca xe day.
--     Tieu hao = ton dau + linh (issue_in tu phieu linh bu cua ca) - dem
--     cuoi; chi dong > 0 moi ghi purpose_issue (purpose_code 'housekeeping',
--     cost center ROOMS, khoan muc GUEST_SUPPLIES, status 'posted').
--     Tieu hao am -> clamp 0 + surplus_lines (quyet dinh 8).
--     p_rooms_done: [{room_id, clean_type, guests?}] — phuc vu doi chieu
--     ly thuyet P2 o T-035+ (Q45).
-- ---------------------------------------------------------------------------
create or replace function public.trolley_shift_close(
  p_shift_id uuid,
  p_counts jsonb,
  p_rooms_done jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_s record;
  v_org_id uuid;
  v_entity_id uuid;
  v_property_id uuid;
  v_biz date;
  v_closing_id uuid;
  v_doc_no text;
  v_cc_id uuid;
  v_ec_id uuid;
  v_pi_id uuid;
  v_pi_lines integer := 0;
  v_pi_items uuid[] := '{}';
  v_pi_qtys numeric[] := '{}';
  v_line_id uuid;
  v_surplus jsonb := '[]'::jsonb;
  v_el jsonb;
  v_room_id uuid;
  v_guests integer;
  r record;
begin
  select * into v_s from public.trolley_shifts s where s.id = p_shift_id;
  if v_s is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: ca xe day khong ton tai';
  end if;

  perform public.require_perm(v_s.property_id, 'hk.trolley.operate');
  if v_s.status <> 'open' then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_STATUS: ca khong o trang thai mo';
  end if;

  v_org_id := v_s.org_id;
  v_entity_id := v_s.legal_entity_id;
  v_property_id := v_s.property_id;
  v_biz := v_s.business_date;

  -- Kiem tra rooms_done: mang cac {room_id, clean_type, guests?}.
  if p_rooms_done is not null
    and jsonb_typeof(p_rooms_done) <> 'array' then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: p_rooms_done phai la mang JSON';
  end if;
  for v_el in select * from jsonb_array_elements(
    coalesce(p_rooms_done, '[]'::jsonb)
  ) loop
    if jsonb_typeof(v_el) <> 'object' then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: moi phan tu p_rooms_done phai la object';
    end if;
    begin
      v_room_id := (v_el ->> 'room_id')::uuid;
    exception when others then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: room_id khong hop le';
    end;
    if not exists (
      select 1 from public.rooms rm
      where rm.id = v_room_id and rm.property_id = v_property_id
    ) then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: room khong thuoc property';
    end if;
    if (v_el ->> 'clean_type') not in ('checkout', 'stayover', 'vip', 'child') then
      raise exception using errcode = 'P0001',
        message = 'ERR_INVALID_VALUE: clean_type khong hop le';
    end if;
    if v_el ->> 'guests' is not null then
      begin
        v_guests := (v_el ->> 'guests')::integer;
      exception when others then
        raise exception using errcode = 'P0001',
          message = 'ERR_INVALID_VALUE: guests khong hop le';
      end;
      if v_guests < 0 then
        raise exception using errcode = 'P0001',
          message = 'ERR_INVALID_VALUE: guests khong duoc am';
      end if;
    end if;
  end loop;

  -- Dem cuoi ca (mu): nhu dem dau ca, book_qty NULL.
  perform set_config('app.count_guard_bypass', 'on', true);
  v_doc_no := public.next_doc_no(v_entity_id, 'CNT', v_biz);
  insert into public.stock_counts (
    org_id, legal_entity_id, property_id, warehouse_id, doc_no, kind,
    business_date, shift, status, counter_ids, opened_by, created_by
  ) values (
    v_org_id, v_entity_id, v_property_id, v_s.trolley_warehouse_id,
    v_doc_no, 'trolley', v_biz, v_s.shift, 'submitted',
    array[auth.uid()], auth.uid(), auth.uid()
  )
  returning id into v_closing_id;

  insert into public.stock_count_lines (
    count_id, org_id, item_id, count_detail,
    counted_qty_1, counted_by_1, final_qty, flag
  )
  select v_closing_id, v_org_id, c.item_id, '{}'::jsonb,
    c.qty, auth.uid(), c.qty, 'ok'
  from public._hk_parse_counts(p_counts, v_org_id) c;

  -- Giai quyet cost center + khoan muc truoc khi ghi so.
  select id into v_cc_id from public.cost_centers
  where org_id = v_org_id and code = 'ROOMS';
  if v_cc_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: thieu cost center ROOMS';
  end if;
  select id into v_ec_id from public.expense_categories
  where org_id = v_org_id and code = 'GUEST_SUPPLIES';
  if v_ec_id is null then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: thieu khoan muc GUEST_SUPPLIES';
  end if;

  -- Tieu hao theo item: dau (opening count) + linh (issue_in tu phieu linh
  -- bu cua ca) - cuoi (closing count). Item chi xuat hien o 1 trong 3 nguon
  -- van tinh (thieu = 0).
  for r in
    with o as (
      select item_id, final_qty
      from public.stock_count_lines where count_id = v_s.opening_count_id
    ),
    c as (
      select item_id, final_qty
      from public.stock_count_lines where count_id = v_closing_id
    ),
    recv as (
      select sm.item_id, sum(sm.qty) as qty
      from public.stock_moves sm
      where sm.warehouse_id = v_s.trolley_warehouse_id
        and sm.move_type = 'issue_in'
        and sm.source_doc_type = 'requisition'
        and sm.source_doc_id = v_s.requisition_id
      group by sm.item_id
    ),
    u as (
      select item_id from o
      union select item_id from c
      union select item_id from recv
    )
    select u.item_id,
      coalesce(o.final_qty, 0) + coalesce(recv.qty, 0)
        - coalesce(c.final_qty, 0) as cons
    from u
    left join o on o.item_id = u.item_id
    left join c on c.item_id = u.item_id
    left join recv on recv.item_id = u.item_id
  loop
    if r.cons > 0 then
      v_pi_items := v_pi_items || r.item_id;
      v_pi_qtys := v_pi_qtys || r.cons;
    elsif r.cons < 0 then
      -- Thua hang cuoi ca: KHONG ghi tieu hao am (quyet dinh 8).
      v_surplus := v_surplus || jsonb_build_object(
        'item_id', r.item_id, 'surplus_qty', -r.cons
      );
    end if;
  end loop;

  if array_length(v_pi_items, 1) > 0 then
    perform set_config('app.inventory_guard_bypass', 'on', true);
    v_doc_no := public.next_doc_no(v_entity_id, 'PIS', v_biz);
    insert into public.purpose_issues (
      org_id, legal_entity_id, property_id, warehouse_id, doc_no,
      business_date, status, purpose_code, cost_center_id,
      expense_category_id, note, created_by
    ) values (
      v_org_id, v_entity_id, v_property_id, v_s.trolley_warehouse_id,
      v_doc_no, v_biz, 'posted', 'housekeeping', v_cc_id, v_ec_id,
      'Tieu hao ca xe day ' || v_s.shift || ' ' || v_biz::text
        || case when v_surplus <> '[]'::jsonb
           then ' | Thua hang cuoi ca (khong ghi tieu hao am): '
             || v_surplus::text
           else '' end,
      auth.uid()
    )
    returning id into v_pi_id;

    for i in 1 .. array_length(v_pi_items, 1) loop
      insert into public.purpose_issue_lines (
        purpose_issue_id, org_id, property_id, item_id, uom,
        qty, qty_stock, created_by
      )
      select v_pi_id, v_org_id, v_property_id, v_pi_items[i],
        it.stock_uom, v_pi_qtys[i], v_pi_qtys[i], auth.uid()
      from public.items it where it.id = v_pi_items[i]
      returning id into v_line_id;

      perform public._post_move(
        v_entity_id, v_property_id, v_s.trolley_warehouse_id,
        v_pi_items[i], null,
        'purpose_issue', -v_pi_qtys[i], null,
        v_biz, 'purpose_issue', v_pi_id, v_line_id,
        v_cc_id, v_ec_id, 'housekeeping'
      );
      v_pi_lines := v_pi_lines + 1;
    end loop;
  end if;

  perform set_config('app.hk_guard_bypass', 'on', true);
  update public.trolley_shifts
  set status = 'closed',
    closing_count_id = v_closing_id,
    rooms_done = coalesce(p_rooms_done, '[]'::jsonb),
    purpose_issue_id = v_pi_id,
    closed_by = auth.uid(),
    closed_at = now(),
    updated_at = now()
  where id = p_shift_id;

  return jsonb_build_object(
    'ok', true, 'shift_id', p_shift_id,
    'closing_count_id', v_closing_id,
    'purpose_issue_id', v_pi_id,
    'consumption_lines', v_pi_lines,
    'surplus_lines', v_surplus
  );
end;
$$;

revoke all on function public.trolley_shift_close(uuid, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.trolley_shift_close(uuid, jsonb, jsonb)
  to authenticated;

-- Audit trail for the migration itself (pattern 210000/260000).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109310000_housekeeping_trolley',
  'INSERT',
  '{"tables": ["room_setup_standards", "trolley_par_levels", "trolley_shifts"], "rpcs": ["room_setup_standard_set", "trolley_par_set", "trolley_shift_open", "trolley_shift_close"]}'::jsonb,
  'migration',
  'T-034 housekeeping trolley foundation'
);
