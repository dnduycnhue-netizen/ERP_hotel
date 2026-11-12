-- Q232: buoc outlet_head cua PO khong bao gio tu duyet.
-- Nguyen nhan: _generate_approval_steps chi tu duyet khi PR nguon con
-- status = 'approved', nhung po_create_from_pr da chuyen PR sang
-- 'converted' ngay khi tao PO (truoc khi po_submit goi ham nay).
-- PR 'converted' tat yeu da tung 'approved' (po_create_from_pr chi nhan
-- PR status = 'approved'), nen chap nhan ca hai trang thai.
-- Chi doi dung 1 dong dieu kien; toan bo than ham lay nguyen van tu
-- migration 20261109210000 (ham nay khong co ban redefine nao khac).
--
create or replace function public._generate_approval_steps(
  p_doc_type text,
  p_doc_id uuid,
  p_property_id uuid,
  p_org_id uuid,
  p_total_amount numeric(18,2)
)
returns integer
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_sod_profile text;
  v_accountant_role_id uuid;
  v_group_ids uuid[];
  v_over_ceiling boolean := false;
  v_manual boolean := false;
  v_pr_ids uuid[];
  v_pr_approver uuid;
  v_steps integer;
begin
  delete from public.approvals
  where doc_type = p_doc_type and doc_id = p_doc_id;

  select p.sod_profile into v_sod_profile
  from public.properties p where p.id = p_property_id;

  select r.id into v_accountant_role_id
  from public.roles r
  where r.org_id = p_org_id and r.code = 'accountant';

  if p_doc_type = 'pr' then
    select coalesce(array_agg(distinct i.group_id), '{}'::uuid[])
      into v_group_ids
    from public.purchase_request_lines prl
    join public.items i on i.id = prl.item_id
    where prl.pr_id = p_doc_id;
  elsif p_doc_type = 'po' then
    select coalesce(array_agg(distinct i.group_id), '{}'::uuid[])
      into v_group_ids
    from public.purchase_order_lines pol
    join public.items i on i.id = pol.item_id
    where pol.po_id = p_doc_id;
    select exists (
      select 1 from public.purchase_order_lines pol
      where pol.po_id = p_doc_id and pol.over_ceiling
    ) into v_over_ceiling;
    select exists (
      select 1 from public.purchase_order_lines pol
      where pol.po_id = p_doc_id and pol.price_source = 'manual'
    ) into v_manual;
  end if;

  insert into public.approvals (
    org_id, property_id, doc_type, doc_id, step,
    approver_role_id, approver_user_id, required_perm,
    decision, comment, decided_by, decided_at
  )
  select distinct on (r.step)
    p_org_id,
    p_property_id,
    p_doc_type,
    p_doc_id,
    r.step,
    case
      when rc.code = 'cost_controller' and v_sod_profile = 'without_cc'
        and v_accountant_role_id is not null
      then v_accountant_role_id
      else r.approver_role_id
    end,
    r.approver_user_id,
    r.required_perm,
    'pending',
    null,
    null,
    null
  from public.approval_rules r
  left join public.roles rc on rc.id = r.approver_role_id
  where r.org_id = p_org_id
    and (r.property_id is null or r.property_id = p_property_id)
    and r.doc_type = p_doc_type
    and r.min_amount <= p_total_amount
    and (r.item_group_id is null or r.item_group_id = any(v_group_ids))
    and (
      (r.condition - 'over_ceiling' - 'manual_price') = '{}'::jsonb
      and (not (r.condition ? 'over_ceiling')
        or (r.condition ->> 'over_ceiling')::boolean = v_over_ceiling)
      and (not (r.condition ? 'manual_price')
        or (r.condition ->> 'manual_price')::boolean = v_manual)
    )
  order by r.step, (r.property_id is not null) desc;

  -- Buoc gm bo sung khi vuot tran hoac gia tay (quyet dinh 3): 1 buoc
  -- duy nhat, dung quyen over_ceiling khi co vuot tran.
  if p_doc_type = 'po' and (v_over_ceiling or v_manual) then
    insert into public.approvals (
      org_id, property_id, doc_type, doc_id, step,
      approver_role_id, approver_user_id, required_perm, decision
    )
    select
      p_org_id,
      p_property_id,
      'po',
      p_doc_id,
      coalesce((select max(step) from public.approvals where doc_type = 'po' and doc_id = p_doc_id), 0) + 1,
      r.id,
      null,
      case when v_over_ceiling then 'po.approve.over_ceiling' else 'po.approve' end,
      'pending'
    from public.roles r
    where r.org_id = p_org_id and r.code = 'gm';
  end if;

  -- Tu dong duyet buoc outlet_head cua PO tao tu PR da duyet (quyet dinh 2).
  if p_doc_type = 'po' then
    select array_agg(distinct pr.id) into v_pr_ids
    from public.purchase_order_lines pol
    join public.purchase_request_lines prl on prl.id = pol.pr_line_id
    join public.purchase_requests pr on pr.id = prl.pr_id
    where pol.po_id = p_doc_id;

    if v_pr_ids is not null and array_length(v_pr_ids, 1) > 0
      and not exists (
        select 1 from public.purchase_requests pr
        where pr.id = any(v_pr_ids) and pr.status not in ('approved', 'converted')
      )
    then
      select a.decided_by into v_pr_approver
      from public.approvals a
      where a.doc_type = 'pr'
        and a.doc_id = any(v_pr_ids)
        and a.decision = 'approved'
      order by a.decided_at desc nulls last
      limit 1;

      if v_pr_approver is not null then
        update public.approvals a
        set decision = 'approved',
            decided_by = v_pr_approver,
            decided_at = now(),
            comment = 'Tự động duyệt: PR đã được trưởng outlet duyệt'
        where a.doc_type = 'po'
          and a.doc_id = p_doc_id
          and a.decision = 'pending'
          and a.approver_role_id in (
            select r.id from public.roles r
            where r.org_id = p_org_id and r.code = 'outlet_head'
          );
      end if;
    end if;
  end if;

  select count(*) into v_steps
  from public.approvals
  where doc_type = p_doc_type and doc_id = p_doc_id;
  return v_steps;
end;
$$;
