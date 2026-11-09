-- ===========================================================================
-- T-035 (DB): Minibar theo phong — bang gia, phieu kiem, thu/mien/late
--   charge, doi soat cuoi ngay.
--   (docs/modules/M07-housekeeping-minibar.md + docs/05-BUSINESS-RULES.md
--    §7.2 + docs/03-DATA-MODEL.md A8 + docs/09-API-RPC.md §6
--    + docs/11-TESTING.md §4)
--   Chi DB + RPC + pgTAP + seed cau truc. KHONG UI (man hinh le tan/buong/
--    van phong: nua sau T-035).
--
-- QUYET DINH THIET KE (xem them Q50-Q57 trong docs/OPEN-QUESTIONS.md):
--   1. 3 bang moi (A8) + 4 cot mo rong tren minibar_checks so voi A8:
--      doc_no (quy uoc §5 AGENTS.md: moi chung tu co doc_no), business_date,
--      client_uuid (chong trung submit — mau T-023/T-025), waive_requested_by/
--      waive_requested_at (SoD mien: nguoi de nghi khong duoc duyet),
--      is_loss + trolley_shift_id (kiem dot xuat audit: that thoat gan ca
--      buong gan nhat), late_note, write_off_reason, waive_decided_at.
--      minibar_check_lines co unique (check_id, item_id).
--   2. Quyen: 6 ma minibar.* DA CO trong catalog (141000) va da gan vai tro
--      mau (seed 140000). Chi them 4 ma MOI (chen vao public.permissions,
--      on conflict do nothing): minibar.price.manage (875), minibar.reconcile
--      (885), alert.receive.minibar_loss (1585),
--      alert.receive.minibar_check_requested (1586); gan theo ma role.
--      alert.receive.minibar_mismatch DA CO trong catalog nhung chua gan vai
--      tro nao (seed khong co) nen migration nay gan cho owner/gm/
--      cost_controller — neu khong, alert doi soat khong ai thay.
--   3. Dasani (complimentary) vs Lavie (minibar) la 2 ma KHAC NHAU (§7.2.7):
--      moi RPC nhan item deu chan kind <> 'minibar' bang ERR_INVALID_VALUE
--      (submit_check, refill, price_set) + chan ma tam (is_temp). Dasani
--      cap phong di qua trolley/room setup (T-034), KHONG qua minibar_refill.
--   4. minibar_refill = transfer minibar_main -> minibar_room (khong phai
--      ban): tao 1 dong transfers (status 'received', doc_no TRF) + dong
--      transfer_lines (sent = received = qty) + cap _post_move transfer_out
--      (main, -qty) / transfer_in (room, +qty), source_doc_type 'transfer'.
--      KHONG di qua kho transit va KHONG qua duyet transfer 3 buoc: refill
--      la dich chuyen noi bo tuc thi, nguoi goi chi co minibar.refill (khong
--      co transfer.send/receive). Ton toan cuc item_costs.qty_on_hand khong
--      doi (chuyen kho, khong xuat/nhap).
--   5. Gia tinh theo bang gia TAI THOI DIEM KIEM: _minibar_price_at lay dong
--      valid_from moi nhat <= business_date cua phieu, valid_to null hoac
--      >= business_date. Khong co gia -> ERR_PRICE_NOT_SET (ma T-020).
--   6. minibar_request_check: 1 phieu pending_charge mo / phong — goi lai
--      tra ve phieu dang mo (existing=true) thay vi tao trung (tranh thu
--      trung). Phong co phieu chua xong ma giao khach moi: KHONG chan (khong
--      tich hop PMS) — chi tao alert + UI nua sau doc pending de canh bao.
--   7. Audit (trigger='audit'): thieu ma KHONG co phieu checkout tuong ung
--      (phieu checkout cung phong, business_date trong 30 ngay truoc, da
--      kiem) -> that thoat: status 'written_off', is_loss=true, gan ca xe
--      day gan nhat (trolley_shifts moi nhat <= hom nay), alert MINIBAR_LOSS.
--      Neu CO phieu checkout tuong ung (hang da tinh tien o checkout) ->
--      'written_off', is_loss=false, khong alert (tranh thu trung).
--   8. late_charge / written_off: §6 khong co RPC nao dat 2 trang thai nay
--      nen them minibar_mark_late_charge (frontdesk, tu pending_charge) va
--      minibar_write_off (gm, can ly do). confirm_charge chap nhan ca
--      pending_charge va late_charge (thu muon qua the sau khi khach di).
--   9. Doi soat (§7.2.6): recorded = Σ total cac phieu DA KIEM (checked_by
--      not null) co business_date = ngay doi soat, status trong
--      (pending_charge, charged, waived, late_charge) — written_off (that
--      thoat audit) KHONG tinh vao recorded vi khong phai doanh thu ghi
--      nhan; diff = recorded - charged - waived - late_charge + Σ pending
--      ton tu ngay truoc. diff <> 0 -> alert MINIBAR_MISMATCH (red, dedupe
--      theo alert chua ack cung ngay). Vi vay "bo trong 1 phieu pending qua
--      ngay" van bao alert khi doi soat ngay hom sau.
--  10. minibar_reconcile KHONG require_perm (chay duoc tu pg_cron nhu
--      advance_overdue_maintenance): them minibar_reconcile_all() quet moi
--      property + job pg_cron 'minibar-reconcile-daily' 23:30 hang ngay,
--      guard 2 lop nhu T-022. Nguoi dung goi tay can quyen minibar.reconcile
--      — KHONG chan trong ham vi cron chay voi auth.uid() NULL; kiem soat
--      bang grant execute (authenticated) + UI chi goi tu man doi soat.
--  11. near_expiry: co 2 duong — (a) flag tren dong kiem do buong danh dau
--      khi kiem (cot near_expiry tren minibar_check_lines); (b) RPC
--      minibar_recall_list(p_property_id, p_days default 30) liet ke ton
--      kho phong theo lo co expiry_date <= hom nay + p_days (lo lay tu
--      stock_balances.lot_id). Nguong 30 ngay la tham so, chua co dong cau
--      hinh rieng (xem Q53).
--  12. Gia von khi post minibar_sale: _post_move tu tinh theo phuong phap
--      costing cua phap nhan (unit_cost truyen NULL nhu transfer_send);
--      move ghi lot_id NULL — chech lech theo lo khong phan bo (xem Q33).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Bang gia minibar theo thoi gian (03-DATA-MODEL.md A8).
--    unique (property_id, item_id, valid_from): 1 muc gia / item / moc
--    hieu luc. KHONG seed gia cung — gia that do Duy/team nhap sau qua
--    minibar_price_set (xem Q47).
-- ---------------------------------------------------------------------------
create table public.minibar_price_list (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  item_id uuid not null,
  price numeric(18,2) not null check (price > 0),
  valid_from date not null,
  valid_to date,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (property_id, item_id, valid_from),
  check (valid_to is null or valid_to >= valid_from),
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (property_id, org_id) references public.properties(id, org_id)
);
create index on public.minibar_price_list (property_id, item_id, valid_from desc);

-- ---------------------------------------------------------------------------
-- 2. Phieu kiem minibar (A8 + 4 cot mo rong — xem quyet dinh 1).
-- ---------------------------------------------------------------------------
create table public.minibar_checks (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id),
  legal_entity_id uuid not null references public.legal_entities(id),
  property_id uuid not null references public.properties(id),
  room_id uuid not null,
  doc_no text not null,
  business_date date not null,
  trigger text not null check (trigger in ('checkout', 'daily', 'audit')),
  checked_by uuid references auth.users(id),
  checked_at timestamptz,
  status text not null default 'pending_charge' check (status in (
    'pending_charge', 'charged', 'waived', 'late_charge', 'written_off'
  )),
  total_amount numeric(18,2) not null default 0 check (total_amount >= 0),
  folio_no text,
  charged_by uuid references auth.users(id),
  charged_at timestamptz,
  waive_reason text,
  waive_requested_by uuid references auth.users(id),
  waive_requested_at timestamptz,
  waive_approved_by uuid references auth.users(id),
  waive_decided_at timestamptz,
  late_note text,
  write_off_reason text,
  is_loss boolean not null default false,
  trolley_shift_id uuid references public.trolley_shifts(id),
  client_uuid uuid,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (legal_entity_id, doc_no),
  unique (client_uuid),
  foreign key (room_id, property_id) references public.rooms(id, property_id),
  foreign key (property_id, legal_entity_id, org_id)
    references public.properties(id, legal_entity_id, org_id),
  check (charged_at is null or charged_by is not null),
  check (waive_requested_at is null or waive_requested_by is not null),
  check (waive_decided_at is null or waive_approved_by is not null
    or waive_requested_by is null)
);
create index on public.minibar_checks (property_id, room_id, business_date);
create index on public.minibar_checks (property_id, status, business_date);

-- ---------------------------------------------------------------------------
-- 3. Dong phieu kiem (A8).
-- ---------------------------------------------------------------------------
create table public.minibar_check_lines (
  id uuid primary key default gen_random_uuid(),
  check_id uuid not null,
  org_id uuid not null references public.organizations(id),
  property_id uuid not null references public.properties(id),
  item_id uuid not null,
  missing_qty numeric(18,4) not null check (missing_qty > 0),
  unit_price numeric(18,4) not null check (unit_price >= 0),
  amount numeric(18,2) not null check (amount >= 0),
  near_expiry boolean not null default false,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, org_id),
  unique (check_id, item_id),
  foreign key (check_id, org_id) references public.minibar_checks(id, org_id),
  foreign key (item_id, org_id) references public.items(id, org_id),
  foreign key (property_id, org_id) references public.properties(id, org_id)
);
create index on public.minibar_check_lines (check_id);

-- ---------------------------------------------------------------------------
-- 4. Trigger updated_at + write-guard (mau T-030/T-032/T-034).
--    minibar_price_list la master data: chi RLS SELECT-only (giong items),
--    ghi qua RPC. minibar_checks / _lines la chung tu: them write-guard.
-- ---------------------------------------------------------------------------
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'minibar_price_list', 'minibar_checks', 'minibar_check_lines'
  ] loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_updated_at()',
      'trg_' || v_table || '_updated_at', v_table
    );
  end loop;
end $$;

create or replace function public._minibar_write_guard()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.minibar_guard_bypass', true), '') <> 'on' then
    raise exception using
      errcode = 'P0001',
      message = 'ERR_WRITE_GUARD: ' || TG_TABLE_NAME || ' chi duoc ghi qua RPC';
  end if;
  return coalesce(new, old);
end;
$$;

create trigger trg_minibar_checks_write_guard
before insert or update or delete on public.minibar_checks
for each row execute function public._minibar_write_guard();

create trigger trg_minibar_check_lines_write_guard
before insert or update or delete on public.minibar_check_lines
for each row execute function public._minibar_write_guard();

-- ---------------------------------------------------------------------------
-- 5. RLS: bat 100% + policy SELECT-only (mau T-030 §5 / T-034 §5).
--    Ghi truc tiep bi chan; RPC SECURITY DEFINER ghi.
--    Dung `in (select public.my_property_ids())` — TUYET DOI KHONG dung
--    `= any (public.my_property_ids())` (loi 0A000 khi db push).
-- ---------------------------------------------------------------------------
alter table public.minibar_price_list enable row level security;
alter table public.minibar_checks enable row level security;
alter table public.minibar_check_lines enable row level security;

create policy minibar_price_list_select on public.minibar_price_list
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'minibar.price.manage')
    or public.has_perm(property_id, 'hk.standard.manage')
    or public.has_perm(property_id, 'minibar.check')
  )
);

create policy minibar_checks_select on public.minibar_checks
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'minibar.request_check')
    or public.has_perm(property_id, 'minibar.check')
    or public.has_perm(property_id, 'minibar.charge.confirm')
    or public.has_perm(property_id, 'minibar.waive.request')
    or public.has_perm(property_id, 'minibar.waive.approve')
    or public.has_perm(property_id, 'minibar.refill')
    or public.has_perm(property_id, 'minibar.reconcile')
    or public.has_perm(property_id, 'report.view.rpt_minibar')
  )
);

create policy minibar_check_lines_select on public.minibar_check_lines
for select using (
  property_id in (select public.my_property_ids())
  and (
    public.has_perm(property_id, 'minibar.request_check')
    or public.has_perm(property_id, 'minibar.check')
    or public.has_perm(property_id, 'minibar.charge.confirm')
    or public.has_perm(property_id, 'minibar.waive.request')
    or public.has_perm(property_id, 'minibar.waive.approve')
    or public.has_perm(property_id, 'minibar.refill')
    or public.has_perm(property_id, 'minibar.reconcile')
    or public.has_perm(property_id, 'report.view.rpt_minibar')
  )
);

-- ---------------------------------------------------------------------------
-- 6. Permission code MOI (quyet dinh 2) + gan theo ma role.
--    Chi chen code that su moi; 6 ma minibar.* da co trong catalog (141000).
-- ---------------------------------------------------------------------------
insert into public.permissions
  (code, module, name_vi, description_vi, risk_level, sort_order)
values
  ('minibar.price.manage', 'Buồng phòng', 'Quản lý bảng giá minibar',
   'Thêm/sửa giá minibar theo thời gian.', 'sensitive', 875),
  ('minibar.reconcile', 'Buồng phòng', 'Đối soát minibar',
   'Đối soát tiền minibar cuối ngày và xem lệch.', 'sensitive', 885),
  ('alert.receive.minibar_loss', 'Cảnh báo', 'Nhận cảnh báo thất thoát minibar',
   'Nhận cảnh báo kiểm đột xuất phát hiện thất thoát minibar.', 'normal', 1585),
  ('alert.receive.minibar_check_requested', 'Cảnh báo', 'Nhận yêu cầu kiểm minibar',
   'Nhận yêu cầu kiểm minibar khi khách trả phòng.', 'normal', 1586)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, v.permission_code
from public.roles r
join (values
  ('owner', 'minibar.price.manage'),
  ('gm', 'minibar.price.manage'),
  ('hk_supervisor', 'minibar.price.manage'),
  ('owner', 'minibar.reconcile'),
  ('gm', 'minibar.reconcile'),
  ('cost_controller', 'minibar.reconcile'),
  ('owner', 'alert.receive.minibar_mismatch'),
  ('gm', 'alert.receive.minibar_mismatch'),
  ('cost_controller', 'alert.receive.minibar_mismatch'),
  ('owner', 'alert.receive.minibar_loss'),
  ('gm', 'alert.receive.minibar_loss'),
  ('internal_audit', 'alert.receive.minibar_loss'),
  ('owner', 'alert.receive.minibar_check_requested'),
  ('gm', 'alert.receive.minibar_check_requested'),
  ('hk_supervisor', 'alert.receive.minibar_check_requested'),
  ('hk_attendant', 'alert.receive.minibar_check_requested')
) as v (role_code, permission_code)
  on v.role_code = r.code
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 7. Helper noi bo (khong grant execute — chi RPC SECURITY DEFINER goi).
-- ---------------------------------------------------------------------------
create or replace function public._minibar_room_wh(p_room_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select w.id
  from public.warehouses w
  where w.room_id = p_room_id and w.kind = 'minibar_room'
  order by w.created_at
  limit 1;
$$;

create or replace function public._minibar_main_wh(p_property_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select w.id
  from public.warehouses w
  where w.property_id = p_property_id and w.kind = 'minibar_main'
  order by w.created_at
  limit 1;
$$;

-- Gia tai thoi diem p_date: valid_from moi nhat <= p_date, valid_to null
-- hoac >= p_date. Tra NULL khi chua co gia (nguoi goi doi thanh
-- ERR_PRICE_NOT_SET).
create or replace function public._minibar_price_at(
  p_property_id uuid,
  p_item_id uuid,
  p_date date
)
returns numeric
language sql
stable
security definer
set search_path = public, auth, pg_temp
as $$
  select pl.price
  from public.minibar_price_list pl
  where pl.property_id = p_property_id
    and pl.item_id = p_item_id
    and pl.valid_from <= p_date
    and (pl.valid_to is null or pl.valid_to >= p_date)
  order by pl.valid_from desc
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- 8. RPC: minibar_price_set — upsert gia theo moc hieu luc.
-- ---------------------------------------------------------------------------
create or replace function public.minibar_price_set(
  p_property_id uuid,
  p_item_id uuid,
  p_price numeric,
  p_valid_from date,
  p_valid_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_prop public.properties%rowtype;
  v_item public.items%rowtype;
  v_kind text;
  v_id uuid;
begin
  select * into v_prop from public.properties p where p.id = p_property_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(p_property_id, 'minibar.price.manage');

  if p_price is null or p_price <= 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_valid_from is null or not isfinite(p_valid_from) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_valid_to is not null and p_valid_to < p_valid_from then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select * into v_item from public.items i
  where i.id = p_item_id and i.org_id = v_prop.org_id;
  if not found or v_item.status = 'merged' or v_item.is_temp then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  select ig.kind into v_kind
  from public.item_groups ig where ig.id = v_item.group_id;
  -- Quy tac §7.2.7: chi hang nhom 'minibar' moi co gia ban; Dasani
  -- (complimentary) khong co gia minibar.
  if v_kind is distinct from 'minibar' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  insert into public.minibar_price_list
    (org_id, property_id, item_id, price, valid_from, valid_to)
  values
    (v_prop.org_id, p_property_id, p_item_id, p_price, p_valid_from, p_valid_to)
  on conflict (property_id, item_id, valid_from)
  do update set price = excluded.price,
                valid_to = excluded.valid_to,
                updated_at = now()
  returning id into v_id;

  return jsonb_build_object(
    'ok', true, 'id', v_id,
    'item_id', p_item_id, 'price', p_price,
    'valid_from', p_valid_from, 'valid_to', p_valid_to
  );
end;
$$;

revoke all on function public.minibar_price_set(uuid, uuid, numeric, date, date)
  from public, anon, authenticated;
grant execute on function public.minibar_price_set(uuid, uuid, numeric, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 9. RPC: minibar_request_check — le tan goi khi khach check-out.
--    1 phieu pending mo / phong (goi lai tra ve phieu cu, existing=true).
-- ---------------------------------------------------------------------------
create or replace function public.minibar_request_check(
  p_room_id uuid,
  p_trigger text default 'checkout'
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_room public.rooms%rowtype;
  v_prop public.properties%rowtype;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_wh uuid;
  v_existing public.minibar_checks%rowtype;
  v_doc_no text;
  v_id uuid;
begin
  if p_trigger is null or p_trigger not in ('checkout', 'daily', 'audit') then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select * into v_room from public.rooms r where r.id = p_room_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  select * into v_prop from public.properties p where p.id = v_room.property_id;

  perform public.require_perm(v_room.property_id, 'minibar.request_check');

  v_wh := public._minibar_room_wh(p_room_id);
  if v_wh is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select * into v_existing
  from public.minibar_checks c
  where c.room_id = p_room_id and c.status = 'pending_charge'
  order by c.created_at desc
  limit 1;
  if found then
    return jsonb_build_object(
      'ok', true, 'id', v_existing.id, 'doc_no', v_existing.doc_no,
      'status', 'pending_charge', 'existing', true,
      'room_no', v_room.room_no
    );
  end if;

  v_doc_no := public.next_doc_no(v_prop.legal_entity_id, 'MB', v_today);

  perform set_config('app.minibar_guard_bypass', 'on', true);

  insert into public.minibar_checks
    (org_id, legal_entity_id, property_id, room_id, doc_no, business_date,
     trigger, status, created_by)
  values
    (v_prop.org_id, v_prop.legal_entity_id, v_room.property_id, p_room_id,
     v_doc_no, v_today, p_trigger, 'pending_charge', auth.uid())
  returning id into v_id;

  perform public._create_alert(
    v_room.property_id,
    'MINIBAR_CHECK_REQUESTED',
    'info',
    format('Yêu cầu kiểm minibar phòng %s', v_room.room_no),
    jsonb_build_object(
      'check_id', v_id, 'doc_no', v_doc_no,
      'room_id', p_room_id, 'room_no', v_room.room_no, 'trigger', p_trigger
    ),
    'minibar_check',
    v_id
  );

  return jsonb_build_object(
    'ok', true, 'id', v_id, 'doc_no', v_doc_no,
    'status', 'pending_charge', 'existing', false,
    'room_no', v_room.room_no
  );
end;
$$;

revoke all on function public.minibar_request_check(uuid, text)
  from public, anon, authenticated;
grant execute on function public.minibar_request_check(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 10. RPC: minibar_submit_check — buong nhap so thieu, tinh tien theo
--     bang gia tai thoi diem kiem. p_lines: [{item_id, missing_qty,
--     near_expiry?}]. Idempotent theo p_client_uuid (mau T-023/T-025).
-- ---------------------------------------------------------------------------
create or replace function public.minibar_submit_check(
  p_check_id uuid,
  p_lines jsonb,
  p_client_uuid uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_chk public.minibar_checks%rowtype;
  v_room_no text;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_el jsonb;
  v_item_id uuid;
  v_item public.items%rowtype;
  v_kind text;
  v_qty numeric(18,4);
  v_near boolean;
  v_price numeric(18,4);
  v_amount numeric(18,2);
  v_total numeric(18,2) := 0;
  v_seen uuid[] := '{}';
  v_has_checkout boolean;
  v_shift_id uuid;
  v_shift_attendant uuid;
  v_is_loss boolean := false;
  v_new_status text;
begin
  select * into v_chk from public.minibar_checks c where c.id = p_check_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_chk.property_id, 'minibar.check');

  -- Idempotency: cung client_uuid da nop thi tra ket qua cu, khong ghi lai.
  if p_client_uuid is not null and v_chk.client_uuid = p_client_uuid
    and v_chk.checked_by is not null then
    return jsonb_build_object(
      'ok', true, 'id', v_chk.id, 'doc_no', v_chk.doc_no,
      'status', v_chk.status, 'total_amount', v_chk.total_amount,
      'is_loss', v_chk.is_loss, 'duplicate', true
    );
  end if;

  if v_chk.status <> 'pending_charge' or v_chk.checked_by is not null then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.minibar_guard_bypass', 'on', true);

  for v_el in select * from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_el) <> 'object' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    begin
      v_item_id := (v_el ->> 'item_id')::uuid;
    exception when others then
      raise exception 'ERR_INVALID_VALUE';
    end;
    if v_item_id = any (v_seen) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_seen := v_seen || v_item_id;

    if v_el ->> 'missing_qty' is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    begin
      v_qty := (v_el ->> 'missing_qty')::numeric(18,4);
    exception when others then
      raise exception 'ERR_INVALID_VALUE';
    end;
    if v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_near := coalesce((v_el ->> 'near_expiry')::boolean, false);

    select * into v_item from public.items i
    where i.id = v_item_id and i.org_id = v_chk.org_id;
    if not found or v_item.status = 'merged' or v_item.is_temp then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    select ig.kind into v_kind
    from public.item_groups ig where ig.id = v_item.group_id;
    -- §7.2.7: hang complimentary (Dasani) khong tinh tien minibar.
    if v_kind is distinct from 'minibar' then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    v_price := public._minibar_price_at(
      v_chk.property_id, v_item_id, v_chk.business_date);
    if v_price is null then
      raise exception 'ERR_PRICE_NOT_SET';
    end if;
    v_amount := round(v_qty * v_price, 2);
    v_total := v_total + v_amount;

    insert into public.minibar_check_lines
      (check_id, org_id, property_id, item_id, missing_qty, unit_price,
       amount, near_expiry)
    values
      (p_check_id, v_chk.org_id, v_chk.property_id, v_item_id, v_qty,
       v_price, v_amount, v_near);
  end loop;

  v_new_status := 'pending_charge';

  -- Kiem dot xuat (quyet dinh 7): thieu ma khong co phieu checkout tuong
  -- ung trong 30 ngay truoc -> that thoat, gan ca buong gan nhat.
  if v_chk.trigger = 'audit' and v_total > 0 then
    select exists (
      select 1 from public.minibar_checks c2
      where c2.room_id = v_chk.room_id
        and c2.id <> p_check_id
        and c2.trigger = 'checkout'
        and c2.checked_by is not null
        and c2.business_date >= v_chk.business_date - 30
        and c2.business_date <= v_chk.business_date
    ) into v_has_checkout;

    v_new_status := 'written_off';
    if not v_has_checkout then
      v_is_loss := true;
      select s.id, s.attendant_id into v_shift_id, v_shift_attendant
      from public.trolley_shifts s
      where s.property_id = v_chk.property_id
        and s.business_date <= v_today
      order by s.business_date desc, s.created_at desc
      limit 1;
    end if;
  end if;

  update public.minibar_checks
  set total_amount = v_total,
      checked_by = auth.uid(),
      checked_at = now(),
      client_uuid = p_client_uuid,
      status = v_new_status,
      is_loss = v_is_loss,
      trolley_shift_id = v_shift_id,
      updated_at = now()
  where id = p_check_id;

  if v_chk.trigger = 'audit' and v_total > 0 and v_is_loss then
    select r.room_no into v_room_no
    from public.rooms r where r.id = v_chk.room_id;
    perform public._create_alert(
      v_chk.property_id,
      'MINIBAR_LOSS',
      'warn',
      format('Kiểm đột xuất phòng %s thất thoát minibar %s đ',
             v_room_no, to_char(v_total, 'FM9999999990')),
      jsonb_build_object(
        'check_id', p_check_id, 'doc_no', v_chk.doc_no,
        'room_id', v_chk.room_id, 'room_no', v_room_no,
        'total_amount', v_total, 'trolley_shift_id', v_shift_id,
        'attendant_id', v_shift_attendant
      ),
      'minibar_check',
      p_check_id
    );
  end if;

  return jsonb_build_object(
    'ok', true, 'id', p_check_id, 'doc_no', v_chk.doc_no,
    'status', v_new_status, 'total_amount', v_total,
    'is_loss', v_is_loss, 'trolley_shift_id', v_shift_id,
    'duplicate', false
  );
end;
$$;

revoke all on function public.minibar_submit_check(uuid, jsonb, uuid)
  from public, anon, authenticated;
grant execute on function public.minibar_submit_check(uuid, jsonb, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 11. RPC: minibar_confirm_charge — le tan xac nhan da thu + folio ->
--     post minibar_sale (xuat kho phong). Chap nhan ca pending_charge va
--     late_charge (thu muon qua the sau khi khach di).
-- ---------------------------------------------------------------------------
create or replace function public.minibar_confirm_charge(
  p_check_id uuid,
  p_folio_no text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_chk public.minibar_checks%rowtype;
  v_prop public.properties%rowtype;
  v_wh uuid;
  r record;
begin
  select * into v_chk from public.minibar_checks c where c.id = p_check_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_chk.property_id, 'minibar.charge.confirm');

  if p_folio_no is null or btrim(p_folio_no) = '' then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_chk.status not in ('pending_charge', 'late_charge')
    or v_chk.checked_by is null then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_prop from public.properties p where p.id = v_chk.property_id;
  v_wh := public._minibar_room_wh(v_chk.room_id);
  if v_wh is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  -- _post_move tu tinh gia von theo costing cua phap nhan (unit_cost NULL)
  -- va chan ton am kho phong (ERR_NEGATIVE_STOCK).
  for r in
    select * from public.minibar_check_lines l where l.check_id = p_check_id
    order by l.created_at
  loop
    perform public._post_move(
      v_prop.legal_entity_id, v_chk.property_id, v_wh,
      r.item_id, null,
      'minibar_sale', -r.missing_qty, null,
      v_chk.business_date, 'minibar_check', p_check_id, r.id
    );
  end loop;

  perform set_config('app.minibar_guard_bypass', 'on', true);

  update public.minibar_checks
  set status = 'charged',
      folio_no = btrim(p_folio_no),
      charged_by = auth.uid(),
      charged_at = now(),
      updated_at = now()
  where id = p_check_id;

  return jsonb_build_object(
    'ok', true, 'id', p_check_id, 'doc_no', v_chk.doc_no,
    'status', 'charged', 'folio_no', btrim(p_folio_no),
    'total_amount', v_chk.total_amount
  );
end;
$$;

revoke all on function public.minibar_confirm_charge(uuid, text)
  from public, anon, authenticated;
grant execute on function public.minibar_confirm_charge(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 12. RPC: minibar_request_waive / minibar_decide_waive — mien can gm
--     duyet + ly do (§7.2.5). SoD: nguoi de nghi khong duoc duyet
--     (ERR_SOD_MINIBAR_WAIVE). Trang thai giu pending_charge/late_charge
--     cho toi khi gm quyet dinh.
-- ---------------------------------------------------------------------------
create or replace function public.minibar_request_waive(
  p_check_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_chk public.minibar_checks%rowtype;
begin
  select * into v_chk from public.minibar_checks c where c.id = p_check_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_chk.property_id, 'minibar.waive.request');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;
  if v_chk.status not in ('pending_charge', 'late_charge') then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_chk.waive_requested_by is not null then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.minibar_guard_bypass', 'on', true);

  update public.minibar_checks
  set waive_reason = btrim(p_reason),
      waive_requested_by = auth.uid(),
      waive_requested_at = now(),
      updated_at = now()
  where id = p_check_id;

  return jsonb_build_object(
    'ok', true, 'id', p_check_id, 'doc_no', v_chk.doc_no,
    'status', v_chk.status, 'waive_requested_by', auth.uid()
  );
end;
$$;

revoke all on function public.minibar_request_waive(uuid, text)
  from public, anon, authenticated;
grant execute on function public.minibar_request_waive(uuid, text)
  to authenticated;

create or replace function public.minibar_decide_waive(
  p_check_id uuid,
  p_decision text,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_chk public.minibar_checks%rowtype;
  v_new_status text;
begin
  select * into v_chk from public.minibar_checks c where c.id = p_check_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_chk.property_id, 'minibar.waive.approve');

  if p_decision is null or p_decision not in ('approved', 'rejected') then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if v_chk.waive_requested_by is null then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_chk.status not in ('pending_charge', 'late_charge') then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  -- SoD: nguoi de nghi mien khong duoc tu duyet.
  if auth.uid() = v_chk.waive_requested_by then
    raise exception using errcode = 'P0001',
      message = 'ERR_SOD_MINIBAR_WAIVE';
  end if;

  perform set_config('app.minibar_guard_bypass', 'on', true);

  if p_decision = 'approved' then
    v_new_status := 'waived';
    update public.minibar_checks
    set status = 'waived',
        waive_approved_by = auth.uid(),
        waive_decided_at = now(),
        updated_at = now()
    where id = p_check_id;
  else
    v_new_status := v_chk.status;
    update public.minibar_checks
    set waive_requested_by = null,
        waive_requested_at = null,
        waive_decided_at = now(),
        updated_at = now()
    where id = p_check_id;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', p_check_id, 'doc_no', v_chk.doc_no,
    'status', v_new_status, 'decision', p_decision, 'note', p_note
  );
end;
$$;

revoke all on function public.minibar_decide_waive(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.minibar_decide_waive(uuid, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 13. RPC: minibar_mark_late_charge — phat hien sau khi khach da di
--     (§7.2.4). minibar_write_off — gm duyet xoa (khong thu duoc).
-- ---------------------------------------------------------------------------
create or replace function public.minibar_mark_late_charge(
  p_check_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_chk public.minibar_checks%rowtype;
begin
  select * into v_chk from public.minibar_checks c where c.id = p_check_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_chk.property_id, 'minibar.charge.confirm');

  if v_chk.status <> 'pending_charge' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.minibar_guard_bypass', 'on', true);

  update public.minibar_checks
  set status = 'late_charge',
      late_note = p_note,
      updated_at = now()
  where id = p_check_id;

  return jsonb_build_object(
    'ok', true, 'id', p_check_id, 'doc_no', v_chk.doc_no,
    'status', 'late_charge'
  );
end;
$$;

revoke all on function public.minibar_mark_late_charge(uuid, text)
  from public, anon, authenticated;
grant execute on function public.minibar_mark_late_charge(uuid, text)
  to authenticated;

create or replace function public.minibar_write_off(
  p_check_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_chk public.minibar_checks%rowtype;
begin
  select * into v_chk from public.minibar_checks c where c.id = p_check_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_chk.property_id, 'minibar.waive.approve');

  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'ERR_REASON_REQUIRED';
  end if;
  if v_chk.status not in ('pending_charge', 'late_charge') then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.minibar_guard_bypass', 'on', true);

  update public.minibar_checks
  set status = 'written_off',
      write_off_reason = btrim(p_reason),
      updated_at = now()
  where id = p_check_id;

  return jsonb_build_object(
    'ok', true, 'id', p_check_id, 'doc_no', v_chk.doc_no,
    'status', 'written_off'
  );
end;
$$;

revoke all on function public.minibar_write_off(uuid, text)
  from public, anon, authenticated;
grant execute on function public.minibar_write_off(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 14. RPC: minibar_refill — bo sung phong = transfer minibar_main ->
--     minibar_room (quyet dinh 4). p_lines: [{item_id, qty, lot_id?}].
--     Chi hang nhom 'minibar'; ton kho main khong du -> ERR_INSUFFICIENT_STOCK.
-- ---------------------------------------------------------------------------
create or replace function public.minibar_refill(
  p_room_id uuid,
  p_lines jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_room public.rooms%rowtype;
  v_prop public.properties%rowtype;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_main_wh uuid;
  v_room_wh uuid;
  v_doc_no text;
  v_tr_id uuid;
  v_el jsonb;
  v_item_id uuid;
  v_item public.items%rowtype;
  v_kind text;
  v_qty numeric(18,4);
  v_lot uuid;
  v_line_id uuid;
  v_seen uuid[] := '{}';
  v_avail numeric(18,4);
  v_n integer := 0;
begin
  select * into v_room from public.rooms r where r.id = p_room_id;
  if not found then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  select * into v_prop from public.properties p where p.id = v_room.property_id;

  perform public.require_perm(v_room.property_id, 'minibar.refill');

  v_main_wh := public._minibar_main_wh(v_room.property_id);
  v_room_wh := public._minibar_room_wh(p_room_id);
  if v_main_wh is null or v_room_wh is null then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if p_lines is null or jsonb_typeof(p_lines) <> 'array'
    or jsonb_array_length(p_lines) = 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  -- Validate toan bo dong truoc khi ghi bat ky move nao.
  for v_el in select * from jsonb_array_elements(p_lines) loop
    if jsonb_typeof(v_el) <> 'object' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    begin
      v_item_id := (v_el ->> 'item_id')::uuid;
    exception when others then
      raise exception 'ERR_INVALID_VALUE';
    end;
    if v_item_id = any (v_seen) then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    v_seen := v_seen || v_item_id;

    if v_el ->> 'qty' is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    begin
      v_qty := (v_el ->> 'qty')::numeric(18,4);
    exception when others then
      raise exception 'ERR_INVALID_VALUE';
    end;
    if v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    v_lot := nullif(v_el ->> 'lot_id', '')::uuid;

    select * into v_item from public.items i
    where i.id = v_item_id and i.org_id = v_prop.org_id;
    if not found or v_item.status = 'merged' or v_item.is_temp then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    select ig.kind into v_kind
    from public.item_groups ig where ig.id = v_item.group_id;
    if v_kind is distinct from 'minibar' then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_item.track_lot and v_lot is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if not v_item.track_lot and v_lot is not null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_lot is not null and not exists (
      select 1 from public.lots l
      where l.id = v_lot and l.property_id = v_room.property_id
        and l.item_id = v_item_id and l.org_id = v_prop.org_id
    ) then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    select coalesce(sum(sb.qty), 0) into v_avail
    from public.stock_balances sb
    where sb.warehouse_id = v_main_wh
      and sb.item_id = v_item_id
      and (v_lot is null or sb.lot_id = v_lot);
    if v_avail < v_qty then
      raise exception 'ERR_INSUFFICIENT_STOCK';
    end if;
  end loop;

  v_doc_no := public.next_doc_no(v_prop.legal_entity_id, 'TRF', v_today);

  perform set_config('app.inventory_guard_bypass', 'on', true);
  perform set_config('app.minibar_guard_bypass', 'on', true);

  insert into public.transfers
    (org_id, legal_entity_id, property_id, from_warehouse_id,
     to_warehouse_id, doc_no, business_date, status, note, created_by)
  values
    (v_prop.org_id, v_prop.legal_entity_id, v_room.property_id,
     v_main_wh, v_room_wh, v_doc_no, v_today, 'received',
     format('Minibar refill phòng %s', v_room.room_no), auth.uid())
  returning id into v_tr_id;

  for v_el in select * from jsonb_array_elements(p_lines) loop
    v_item_id := (v_el ->> 'item_id')::uuid;
    v_qty := (v_el ->> 'qty')::numeric(18,4);
    v_lot := nullif(v_el ->> 'lot_id', '')::uuid;
    select * into v_item from public.items i where i.id = v_item_id;

    insert into public.transfer_lines
      (transfer_id, org_id, property_id, item_id, uom, qty, qty_stock,
       sent_qty_stock, received_qty_stock, lot_id)
    values
      (v_tr_id, v_prop.org_id, v_room.property_id, v_item_id,
       v_item.stock_uom, v_qty, v_qty, v_qty, v_qty, v_lot)
    returning id into v_line_id;

    -- transfer_out kho tong + transfer_in kho phong, cung chung tu TRF.
    perform public._post_move(
      v_prop.legal_entity_id, v_room.property_id, v_main_wh,
      v_item_id, nullif(v_el ->> 'lot_id', '')::uuid,
      'transfer_out', -v_qty, null,
      v_today, 'transfer', v_tr_id, v_line_id
    );
    perform public._post_move(
      v_prop.legal_entity_id, v_room.property_id, v_room_wh,
      v_item_id, nullif(v_el ->> 'lot_id', '')::uuid,
      'transfer_in', v_qty, null,
      v_today, 'transfer', v_tr_id, v_line_id
    );
    v_n := v_n + 1;
  end loop;

  return jsonb_build_object(
    'ok', true, 'id', v_tr_id, 'doc_no', v_doc_no,
    'status', 'received', 'lines', v_n,
    'room_no', v_room.room_no
  );
end;
$$;

revoke all on function public.minibar_refill(uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.minibar_refill(uuid, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 15. RPC: minibar_reconcile — doi soat ngay (quyet dinh 9).
--     Khong require_perm de chay duoc tu pg_cron (mau maintenance T-022);
--     grant execute cho authenticated.
-- ---------------------------------------------------------------------------
create or replace function public.minibar_reconcile(
  p_property_id uuid,
  p_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_date date := coalesce(
    p_date, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
  v_recorded numeric(18,2);
  v_charged numeric(18,2);
  v_waived numeric(18,2);
  v_late numeric(18,2);
  v_pending_today numeric(18,2);
  v_pending_stale numeric(18,2);
  v_diff numeric(18,2);
  v_alert_id uuid;
begin
  if not exists (
    select 1 from public.properties p where p.id = p_property_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select
    coalesce(sum(c.total_amount) filter (
      where c.checked_by is not null
        and c.status in ('pending_charge', 'charged', 'waived', 'late_charge')
    ), 0),
    coalesce(sum(c.total_amount) filter (where c.status = 'charged'), 0),
    coalesce(sum(c.total_amount) filter (where c.status = 'waived'), 0),
    coalesce(sum(c.total_amount) filter (where c.status = 'late_charge'), 0),
    coalesce(sum(c.total_amount) filter (where c.status = 'pending_charge'), 0)
  into v_recorded, v_charged, v_waived, v_late, v_pending_today
  from public.minibar_checks c
  where c.property_id = p_property_id
    and c.business_date = v_date;

  select coalesce(sum(c.total_amount), 0)
  into v_pending_stale
  from public.minibar_checks c
  where c.property_id = p_property_id
    and c.business_date < v_date
    and c.status = 'pending_charge';

  v_diff := v_recorded - v_charged - v_waived - v_late + v_pending_stale;

  if v_diff <> 0 then
    if not exists (
      select 1 from public.alerts al
      where al.code = 'MINIBAR_MISMATCH'
        and al.property_id = p_property_id
        and al.ack_at is null
        and (al.payload ->> 'date') = v_date::text
    ) then
      v_alert_id := public._create_alert(
        p_property_id,
        'MINIBAR_MISMATCH',
        'red',
        format('Đối soát minibar ngày %s lệch %s đ',
               to_char(v_date, 'DD/MM/YYYY'),
               to_char(v_diff, 'FM9999999990')),
        jsonb_build_object(
          'date', v_date, 'recorded', v_recorded,
          'charged', v_charged, 'waived', v_waived,
          'late_charge', v_late, 'pending_today', v_pending_today,
          'pending_stale', v_pending_stale, 'diff', v_diff
        ),
        'minibar_reconcile',
        null
      );
    end if;
  end if;

  return jsonb_build_object(
    'ok', true, 'property_id', p_property_id, 'date', v_date,
    'recorded', v_recorded, 'charged', v_charged,
    'waived', v_waived, 'late_charge', v_late,
    'pending_today', v_pending_today, 'pending_stale', v_pending_stale,
    'diff', v_diff, 'alert_id', v_alert_id
  );
end;
$$;

revoke all on function public.minibar_reconcile(uuid, date)
  from public, anon;
grant execute on function public.minibar_reconcile(uuid, date)
  to authenticated;

create or replace function public.minibar_reconcile_all()
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_props integer := 0;
  v_alerts integer := 0;
  r record;
  v_res jsonb;
begin
  for r in select p.id from public.properties p order by p.id loop
    v_res := public.minibar_reconcile(r.id, v_today);
    v_props := v_props + 1;
    if v_res ->> 'alert_id' is not null then
      v_alerts := v_alerts + 1;
    end if;
  end loop;
  return jsonb_build_object(
    'ok', true, 'date', v_today,
    'properties', v_props, 'alerts', v_alerts
  );
end;
$$;

revoke all on function public.minibar_reconcile_all()
  from public, anon;
grant execute on function public.minibar_reconcile_all()
  to authenticated;

-- ---------------------------------------------------------------------------
-- 16. pg_cron: doi soat minibar 23:30 hang ngay (mau T-022 §7).
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron with schema extensions;
exception when others then
  raise notice 'T-035: pg_cron khong cai duoc (%), bo qua lich chay.', sqlerrm;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    if not exists (
      select 1 from cron.job where jobname = 'minibar-reconcile-daily'
    ) then
      perform cron.schedule(
        'minibar-reconcile-daily',
        '30 23 * * *',
        'select public.minibar_reconcile_all()'
      );
    end if;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 17. RPC: minibar_recall_list — hang sap het han trong kho phong
--     (quyet dinh 11). Tra jsonb {ok, days, items: [...]}.
-- ---------------------------------------------------------------------------
create or replace function public.minibar_recall_list(
  p_property_id uuid,
  p_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_items jsonb;
begin
  if not exists (
    select 1 from public.properties p where p.id = p_property_id
  ) then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_days is null or p_days < 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(p_property_id, 'minibar.check')
    or public.has_perm(p_property_id, 'minibar.refill')
    or public.has_perm(p_property_id, 'report.view.rpt_minibar')
  ) then
    raise exception using errcode = '42501',
      message = 'ERR_FORBIDDEN:minibar_recall_list';
  end if;

  select coalesce(jsonb_agg(t order by t.expiry_date, t.room_no), '[]'::jsonb)
  into v_items
  from (
    select
      r.room_no,
      i.id as item_id,
      i.code as item_code,
      l.id as lot_id,
      l.lot_no,
      l.expiry_date,
      (l.expiry_date - v_today) as days_left,
      sb.qty
    from public.stock_balances sb
    join public.warehouses w on w.id = sb.warehouse_id
    join public.rooms r on r.id = w.room_id
    join public.items i on i.id = sb.item_id
    join public.lots l on l.id = sb.lot_id
    where w.property_id = p_property_id
      and w.kind = 'minibar_room'
      and sb.qty > 0
      and l.expiry_date is not null
      and l.expiry_date <= v_today + p_days
  ) t;

  return jsonb_build_object(
    'ok', true, 'property_id', p_property_id,
    'days', p_days, 'items', v_items
  );
end;
$$;

revoke all on function public.minibar_recall_list(uuid, integer)
  from public, anon, authenticated;
grant execute on function public.minibar_recall_list(uuid, integer)
  to authenticated;

comment on function public.minibar_reconcile_all() is
  'T-035: cron 23:30 hang ngay — doi soat minibar moi property, alert MINIBAR_MISMATCH khi lech.';
