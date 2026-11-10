-- C2: Hau kiem anh nhan hang (M04) — man `/{property}/receiving/review`.
--
-- Van de (audit §2.4): quyen `receiving.review_photos` da co trong RLS
-- (230000) nhung 0 lan dung trong `src/`; anh chup luc nhan hang khong ai
-- xem lai duoc.
--
-- Giai phap:
--   1. Them 4 cot hau kiem len `goods_receipts` (khong co bang moi, khong
--      co cot trang thai hau kiem nao truoc day): `photo_review_status`
--      ('pending' | 'approved' | 'rejected', mac dinh 'pending' — cac
--      phieu da post truoc day tu dong ve cho hau kiem), nguoi + thoi
--      diem + ly do tu choi. Audit trail co san qua trigger
--      `goods_receipts_audit` (ghi UPDATE + actor = auth.uid()).
--   2. Ba RPC moi (SECURITY DEFINER, cua `receiving.review_photos` qua
--      `require_perm`; chi doc anh qua `attachment_list` + gallery co san):
--        - `receiving_list_photo_reviews`: phieu da post / can can lai,
--          co it nhat 1 anh, loc theo trang thai hau kiem.
--        - `receiving_get_photo_review`: chi tiet 1 phieu + dong hang
--          (khong tra gia tien — hau kiem chi xem anh, khong can gia).
--        - `receiving_review_photos`: duyet / tu choi 1 phieu (theo
--          phieu, khong theo tung anh); tu choi bat buoc co ly do; chi
--          duyet duoc 1 lan tu 'pending'.
--   3. Khong doi RPC cu, khong doi RLS (policy `goods_receipts_select`
--      da cho `receiving.review_photos` xem phieu da post).
--
-- Quyet dinh (ghi ro de Duy chot sau neu can):
--   - Khong ap dung lay mau 20% o M04 §6 (`without_cc`): man nay liet ke
--     TOAN BO phieu co anh de hau kiem; viec chon mau de nguoi dung loc
--     bang bo loc trang thai.
--   - Phieu `reversed` khong dua vao hau kiem (hang da dao, anh khong
--     con dai dien ton kho).
--   - Khong kiem tra SoD (nguoi nhan khong co quyen review_photos nen
--     khong tu duyet phieu cua minh, tru khi dong thoi giu vai tro co
--     quyen nay).
--   - `receiving_post` khong can set gi: cot moi mac dinh 'pending'.

-- ---------------------------------------------------------------------------
-- 1. Cot hau kiem tren goods_receipts
-- ---------------------------------------------------------------------------
alter table public.goods_receipts
  add column if not exists photo_review_status text not null default 'pending'
    check (photo_review_status in ('pending', 'approved', 'rejected')),
  add column if not exists photo_reviewed_by uuid references auth.users(id),
  add column if not exists photo_reviewed_at timestamptz,
  add column if not exists photo_review_reason text;

comment on column public.goods_receipts.photo_review_status is
  'C2: trang thai hau kiem anh nhan hang — pending/approved/rejected (mac dinh pending).';
comment on column public.goods_receipts.photo_reviewed_by is
  'C2: nguoi duyet/tu choi anh nhan hang (receiving.review_photos).';
comment on column public.goods_receipts.photo_reviewed_at is
  'C2: thoi diem duyet/tu choi anh nhan hang.';
comment on column public.goods_receipts.photo_review_reason is
  'C2: ly do tu choi anh nhan hang (bat buoc khi tu choi, null khi duyet).';

create index if not exists goods_receipts_photo_review_idx
  on public.goods_receipts (property_id, photo_review_status, received_at desc);

-- ---------------------------------------------------------------------------
-- 2. RPC — danh sach phieu cho hau kiem anh
-- ---------------------------------------------------------------------------
create or replace function public.receiving_list_photo_reviews(
  p_property_id uuid,
  p_review_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rows jsonb;
  v_total int;
begin
  perform public.require_perm(p_property_id, 'receiving.review_photos');

  if p_review_status is not null
    and p_review_status not in ('pending', 'approved', 'rejected') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select count(*) into v_total
  from public.goods_receipts gr
  where gr.property_id = p_property_id
    and gr.status in ('posted', 'needs_recount')
    and (p_review_status is null
      or gr.photo_review_status = p_review_status)
    and (p_search is null or gr.doc_no ilike '%' || p_search || '%')
    and exists (
      select 1
      from public.goods_receipt_lines grl
      where grl.gr_id = gr.id
        and coalesce(cardinality(grl.photo_ids), 0) > 0
    );

  select coalesce(jsonb_agg(r), '[]'::jsonb) into v_rows
  from (
    select
      gr.id,
      gr.doc_no,
      gr.po_id,
      po.doc_no as po_doc_no,
      coalesce(s.name, 'Mua chợ') as supplier_name,
      gr.status,
      gr.receiver_id,
      gr.received_at,
      (select count(*)::int from public.goods_receipt_lines grl
        where grl.gr_id = gr.id) as line_count,
      (select coalesce(sum(cardinality(grl.photo_ids)), 0)::int
        from public.goods_receipt_lines grl
        where grl.gr_id = gr.id) as photo_count,
      gr.photo_review_status,
      gr.photo_reviewed_by,
      gr.photo_reviewed_at,
      gr.photo_review_reason
    from public.goods_receipts gr
    left join public.purchase_orders po
      on po.id = gr.po_id
    left join public.suppliers s
      on s.id = gr.supplier_id and s.org_id = gr.org_id
    where gr.property_id = p_property_id
      and gr.status in ('posted', 'needs_recount')
      and (p_review_status is null
        or gr.photo_review_status = p_review_status)
      and (p_search is null or gr.doc_no ilike '%' || p_search || '%')
      and exists (
        select 1
        from public.goods_receipt_lines grl
        where grl.gr_id = gr.id
          and coalesce(cardinality(grl.photo_ids), 0) > 0
      )
    order by gr.received_at desc, gr.created_at desc
    limit greatest(p_limit, 1)
    offset greatest(p_offset, 0)
  ) r;

  return jsonb_build_object('ok', true, 'reviews', v_rows, 'total', v_total);
end;
$$;

revoke all on function public.receiving_list_photo_reviews(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.receiving_list_photo_reviews(uuid, text, text, integer, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPC — chi tiet 1 phieu cho hau kiem anh (khong tra gia tien)
-- ---------------------------------------------------------------------------
create or replace function public.receiving_get_photo_review(
  p_gr_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_lines jsonb;
  v_supplier text;
  v_photo_count int;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if not (
    public.has_perm(v_gr.property_id, 'receiving.review_photos')
    or public.has_perm(v_gr.property_id, 'receiving.view')
  ) then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.view';
  end if;

  if v_gr.status not in ('posted', 'needs_recount') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select s.name into v_supplier
  from public.suppliers s
  where s.id = v_gr.supplier_id and s.org_id = v_gr.org_id;

  select coalesce(jsonb_agg(l), '[]'::jsonb) into v_lines
  from (
    select
      grl.id,
      grl.po_line_id,
      grl.item_id,
      i.name as item_name,
      grl.uom,
      grl.qc_status,
      grl.photo_ids,
      coalesce(cardinality(grl.photo_ids), 0) as photo_count
    from public.goods_receipt_lines grl
    join public.items i
      on i.id = grl.item_id and i.org_id = grl.org_id
    where grl.gr_id = p_gr_id
    order by grl.created_at
  ) l;

  select coalesce(sum(cardinality(grl.photo_ids)), 0)::int into v_photo_count
  from public.goods_receipt_lines grl
  where grl.gr_id = p_gr_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_gr.id,
    'doc_no', v_gr.doc_no,
    'po_id', v_gr.po_id,
    'supplier_name', coalesce(v_supplier, 'Mua chợ'),
    'warehouse_id', v_gr.warehouse_id,
    'status', v_gr.status,
    'receiver_id', v_gr.receiver_id,
    'received_at', v_gr.received_at,
    'photo_count', v_photo_count,
    'photo_review_status', v_gr.photo_review_status,
    'photo_reviewed_by', v_gr.photo_reviewed_by,
    'photo_reviewed_at', v_gr.photo_reviewed_at,
    'photo_review_reason', v_gr.photo_review_reason,
    'lines', v_lines
  );
end;
$$;

revoke all on function public.receiving_get_photo_review(uuid)
  from public, anon, authenticated;
grant execute on function public.receiving_get_photo_review(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC — duyet / tu choi anh cua 1 phieu (theo phieu)
-- ---------------------------------------------------------------------------
create or replace function public.receiving_review_photos(
  p_gr_id uuid,
  p_decision text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_has_photo boolean;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.review_photos');

  if p_decision is null or p_decision not in ('approved', 'rejected') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_gr.status not in ('posted', 'needs_recount') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if v_gr.photo_review_status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select exists (
    select 1
    from public.goods_receipt_lines grl
    where grl.gr_id = p_gr_id
      and coalesce(cardinality(grl.photo_ids), 0) > 0
  ) into v_has_photo;
  if not v_has_photo then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  if p_decision = 'rejected'
    and (p_reason is null or btrim(p_reason) = '') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.receiving_guard_bypass', 'on', true);

  update public.goods_receipts
  set photo_review_status = p_decision,
      photo_reviewed_by = auth.uid(),
      photo_reviewed_at = now(),
      photo_review_reason = case
        when p_decision = 'rejected' then btrim(p_reason)
        else null
      end
  where id = p_gr_id;

  return jsonb_build_object(
    'ok', true,
    'id', p_gr_id,
    'photo_review_status', p_decision
  );
end;
$$;

revoke all on function public.receiving_review_photos(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.receiving_review_photos(uuid, text, text)
  to authenticated;

-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109521000_receiving_photo_review',
  'INSERT',
  jsonb_build_object('event', 'receiving_photo_review_created', 'task', 'C2'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
