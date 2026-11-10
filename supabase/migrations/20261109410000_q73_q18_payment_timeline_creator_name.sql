-- Q73 + Q18: mo duong doc timeline duyet de nghi thanh toan + tra ten
-- nguoi tao o danh sach PR/PO.
--
-- Q73 (T-041): policy `approvals_select` (210000) va RPC
-- `approval_timeline` chi ho tro doc_type 'pr'/'po' nen timeline duyet
-- de nghi thanh toan khong doc duoc tu client (RPC khac loai bao
-- ERR_INVALID_VALUE, policy khong cho doc dong 'payment_request').
-- Migration nay mo ca hai cho doc_type 'payment_request', gioi han
-- quyen payment.request / payment.approve / payment.mark_paid (theo
-- de xuat o Q73). Khong doi hanh vi duyet: `payment_request_decide`
-- van kiem tra lai nguoi duyet buoc dang cho.
--
-- Q18 (T-021): RPC `pr_list`/`po_list` chi tra `created_by` la uuid.
-- Migration nay join `profiles` de tra them `created_by_name`
-- (full_name, null neu chua co profile); UI danh sach hien cot
-- "Nguoi tao".
--
-- Quyet dinh:
--  D1. Khong mo them quyen ap.view / report.view.rpt_ap_aging cho
--      timeline de nghi thanh toan (du policy `payment_requests_select`
--      co cac quyen do): Q73 de xuat gioi han 3 quyen payment.* de
--      nguoi chi xem cong no khong thay chi tiet tung buoc duyet.
--  D2. `pr_get`/`po_get` (chi tiet) KHONG doi o dot nay — task chi
--      yeu cau danh sach; chi tiet van tra `created_by` uuid.
--  D3. Chi CREATE OR REPLACE RPC + drop/create lai 1 policy; khong
--      them bang, khong doi RLS nao khac, khong doi SoD/guard.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1. Policy approvals_select: them nhanh doc_type 'payment_request'.
-- ---------------------------------------------------------------------------
drop policy if exists approvals_select on public.approvals;

create policy approvals_select on public.approvals
  for select to authenticated
  using (
    (
      doc_type = 'pr'
      and exists (
        select 1 from public.purchase_requests pr
        where pr.id = doc_id
          and pr.property_id in (select public.my_property_ids())
          and (
            public.has_perm(pr.property_id, 'pr.create')
            or public.has_perm(pr.property_id, 'pr.approve')
            or public.has_perm(pr.property_id, 'po.create')
            or public.has_perm(pr.property_id, 'po.view')
          )
      )
    )
    or (
      doc_type = 'po'
      and exists (
        select 1 from public.purchase_orders po
        where po.id = doc_id
          and po.property_id in (select public.my_property_ids())
          and (
            public.has_perm(po.property_id, 'po.view')
            or public.has_perm(po.property_id, 'po.create')
            or public.has_perm(po.property_id, 'po.approve')
            or public.has_perm(po.property_id, 'po.close')
          )
      )
    )
    or (
      doc_type = 'payment_request'
      and exists (
        select 1 from public.payment_requests prq
        where prq.id = doc_id
          and prq.property_id in (select public.my_property_ids())
          and (
            public.has_perm(prq.property_id, 'payment.request')
            or public.has_perm(prq.property_id, 'payment.approve')
            or public.has_perm(prq.property_id, 'payment.mark_paid')
          )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 2. RPC approval_timeline: them nhanh 'payment_request' (Q73).
--    Phan than ham giu nguyen — truy van buoc duyet da loc theo
--    doc_type/doc_id nen dung chung cho ca 3 loai chung tu.
-- ---------------------------------------------------------------------------
create or replace function public.approval_timeline(
  p_property_id uuid,
  p_doc_type text,
  p_doc_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_result jsonb;
begin
  if p_doc_type = 'pr' then
    if not (
      public.has_perm(p_property_id, 'pr.create')
      or public.has_perm(p_property_id, 'pr.approve')
      or public.has_perm(p_property_id, 'po.create')
      or public.has_perm(p_property_id, 'po.view')
    ) then
      raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
    end if;
  elsif p_doc_type = 'po' then
    if not (
      public.has_perm(p_property_id, 'po.view')
      or public.has_perm(p_property_id, 'po.create')
      or public.has_perm(p_property_id, 'po.approve')
      or public.has_perm(p_property_id, 'po.close')
    ) then
      raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
    end if;
  elsif p_doc_type = 'payment_request' then
    if not (
      public.has_perm(p_property_id, 'payment.request')
      or public.has_perm(p_property_id, 'payment.approve')
      or public.has_perm(p_property_id, 'payment.mark_paid')
    ) then
      raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
    end if;
  else
    raise exception 'ERR_INVALID_VALUE';
  end if;

  select jsonb_build_object(
    'ok', true,
    'steps', coalesce((
      select jsonb_agg(to_jsonb(s))
      from (
        select
          a.id, a.step, a.approver_role_id, r.name_vi as approver_role_name,
          a.approver_user_id, a.required_perm, a.decision, a.comment,
          a.decided_by, p1.full_name as decided_by_name,
          a.decided_at, a.delegated_from, p2.full_name as delegated_from_name,
          a.created_at
        from public.approvals a
        left join public.roles r on r.id = a.approver_role_id
        left join public.profiles p1 on p1.id = a.decided_by
        left join public.profiles p2 on p2.id = a.delegated_from
        where a.doc_type = p_doc_type and a.doc_id = p_doc_id
        order by a.step asc
      ) s
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.approval_timeline(uuid, text, uuid)
  from public, anon, authenticated;
grant execute on function public.approval_timeline(uuid, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPC pr_list: them created_by_name (join profiles, Q18).
-- ---------------------------------------------------------------------------
create or replace function public.pr_list(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'pr.create')
    or public.has_perm(p_property_id, 'pr.approve')
    or public.has_perm(p_property_id, 'po.create')
    or public.has_perm(p_property_id, 'po.view')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      pr.id, pr.doc_no, pr.kind, pr.need_date, pr.status, pr.note,
      pr.outlet_id, o.name as outlet_name,
      pr.created_by, pf.full_name as created_by_name,
      pr.created_at, pr.updated_at,
      count(prl.id) as line_count
    from public.purchase_requests pr
    left join public.outlets o on o.id = pr.outlet_id
    left join public.profiles pf on pf.id = pr.created_by
    left join public.purchase_request_lines prl on prl.pr_id = pr.id
    where pr.property_id = p_property_id
      and (p_status is null or pr.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or pr.doc_no ilike '%' || p_search || '%'
        or pr.note ilike '%' || p_search || '%'
      )
    group by pr.id, o.name, pf.full_name
  )
  select jsonb_build_object(
    'ok', true,
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f))
      from (select * from filtered order by created_at desc limit v_limit offset v_offset) f
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.pr_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.pr_list(uuid, text, text, integer, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC po_list: them created_by_name (join profiles, Q18).
-- ---------------------------------------------------------------------------
create or replace function public.po_list(
  p_property_id uuid,
  p_status text default null,
  p_search text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_result jsonb;
begin
  if not (
    public.has_perm(p_property_id, 'po.view')
    or public.has_perm(p_property_id, 'po.create')
    or public.has_perm(p_property_id, 'po.approve')
    or public.has_perm(p_property_id, 'po.close')
  ) then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  with filtered as (
    select
      po.id, po.doc_no, po.kind, po.channel, po.supplier_id,
      s.name as supplier_name, po.order_date, po.expected_date,
      po.total_amount, po.status, po.over_ceiling_reason,
      po.created_by, pf.full_name as created_by_name,
      po.created_at, po.updated_at,
      count(pol.id) as line_count,
      coalesce(sum(pol.received_qty_stock), 0) as received_qty_stock
    from public.purchase_orders po
    join public.suppliers s on s.id = po.supplier_id
    left join public.profiles pf on pf.id = po.created_by
    left join public.purchase_order_lines pol on pol.po_id = po.id
    where po.property_id = p_property_id
      and (p_status is null or po.status = p_status)
      and (
        p_search is null or btrim(p_search) = ''
        or po.doc_no ilike '%' || p_search || '%'
        or s.name ilike '%' || p_search || '%'
      )
    group by po.id, s.name, pf.full_name
  )
  select jsonb_build_object(
    'ok', true,
    'total', (select count(*) from filtered),
    'rows', coalesce((
      select jsonb_agg(to_jsonb(f))
      from (select * from filtered order by created_at desc limit v_limit offset v_offset) f
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.po_list(uuid, text, text, integer, integer)
  from public, anon, authenticated;
grant execute on function public.po_list(uuid, text, text, integer, integer) to authenticated;

-- Audit trail for the migration itself (pattern 210000: actor la uuid,
-- khong bao gio ghi text 'migration').
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109410000_q73_q18_payment_timeline_creator_name',
  'INSERT',
  jsonb_build_object('event', 'q73_q18_payment_timeline_creator_name_created', 'task', 'Q73-Q18'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
