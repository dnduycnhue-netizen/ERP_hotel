-- Q221 (11/11/2026): _decide_approval mat nhanh 'requisition'/'waste'.
-- Migration 527000 dinh nghia lai ham chi voi 2 nhanh pr/po, lam
-- requisition_decide / waste_decide luon raise ERR_INVALID_VALUE (duyet
-- phieu linh / phieu huy khong bao gio thanh cong). Khoi phuc toan bo
-- ban 260000 (2 nhanh + khoi ghi so huy + bypass inventory) va GIU
-- NGUYEN khoi alert OVER_CEILING_APPROVED cua 527000 (C8 kiem tra su
-- hien dien cua chuoi nay trong pg_get_functiondef).
-- Anh huong: T-030 (requisition_decide/waste_decide), T-034 §G,
-- trolley_shift_get §F-I. Khong doi chu ky ham, khong doi quyen.
create or replace function public._decide_approval(
  p_property_id uuid,
  p_doc_type text,
  p_doc_id uuid,
  p_decision text,
  p_comment text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_doc record;
  v_step public.approvals%rowtype;
  v_sod_code text;
  v_pending integer;
  v_new_status text;
begin
  if p_decision not in ('approved', 'rejected') then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if p_doc_type = 'pr' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.purchase_requests where id = p_doc_id;
    v_sod_code := 'SOD_PR_CREATOR_APPROVER';
  elsif p_doc_type = 'po' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.purchase_orders where id = p_doc_id;
    v_sod_code := 'SOD_PO_CREATOR_APPROVER';
  elsif p_doc_type = 'requisition' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.requisitions where id = p_doc_id;
    v_sod_code := 'SOD_REQUISITION_CREATOR_APPROVER';
  elsif p_doc_type = 'waste' then
    select id, org_id, property_id, created_by, status
      into v_doc
    from public.waste_reports where id = p_doc_id;
    v_sod_code := 'SOD_WASTE';
  else
    raise exception 'ERR_INVALID_VALUE';
  end if;

  if not found or v_doc.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_doc.status <> 'submitted' then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_step
  from public.approvals a
  where a.doc_type = p_doc_type
    and a.doc_id = p_doc_id
    and a.decision = 'pending'
  order by a.step asc
  limit 1;
  if not found then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(p_property_id, v_step.required_perm);

  if not public._approval_can_decide(p_property_id, v_step.id) then
    raise exception 'ERR_NOT_APPROVER';
  end if;

  if v_doc.created_by = auth.uid() then
    perform public._sod_check(p_property_id, v_sod_code);
  end if;

  if p_decision = 'rejected'
    and (p_comment is null or btrim(p_comment) = '')
  then
    raise exception 'ERR_REASON_REQUIRED';
  end if;

  perform set_config('app.pr_po_guard_bypass', 'on', true);
  perform set_config('app.inventory_guard_bypass', 'on', true);

  update public.approvals a
  set decision = p_decision,
      comment = p_comment,
      decided_by = auth.uid(),
      decided_at = now(),
      delegated_from = case
        when auth.uid() <> coalesce(v_step.approver_user_id, auth.uid())
          and v_step.approver_user_id is not null
        then v_step.approver_user_id
        else (
          select d.from_user
          from public.approval_delegations d
          where d.org_id = v_step.org_id
            and d.to_user = auth.uid()
            and (d.property_id is null or d.property_id = p_property_id)
            and (now() at time zone 'Asia/Ho_Chi_Minh')::date
              between d.valid_from and d.valid_to
          order by d.valid_from desc
          limit 1
        )
      end
  where a.id = v_step.id;

  if p_decision = 'rejected' then
    v_new_status := 'rejected';
  else
    select count(*) into v_pending
    from public.approvals a
    where a.doc_type = p_doc_type
      and a.doc_id = p_doc_id
      and a.decision = 'pending';
    v_new_status := case when v_pending = 0 then 'approved' else 'submitted' end;
  end if;


  -- Huy hang: duyet du buoc thi ghi so luon, khong dung 'approved'.
  if p_doc_type = 'waste' and v_new_status = 'approved' then
    perform public._waste_post_moves(p_doc_id);
    v_new_status := 'posted';
  end if;

  if p_doc_type = 'pr' then
    update public.purchase_requests
    set status = v_new_status where id = p_doc_id;
  elsif p_doc_type = 'po' then
    update public.purchase_orders
    set status = v_new_status where id = p_doc_id;
  elsif p_doc_type = 'requisition' then
    update public.requisitions
    set status = v_new_status where id = p_doc_id;
  else
    update public.waste_reports
    set status = v_new_status where id = p_doc_id;
  end if;

  -- C8: PO duoc duyet het buoc ma co dong vuot tran -> alert
  -- OVER_CEILING_APPROVED (08 §3: warn, App). Chi bao, khong chan
  -- duyet. Chi phat 1 lan khi PO chuyen sang 'approved'.
  if p_doc_type = 'po' and p_decision = 'approved'
    and v_new_status = 'approved'
    and exists (
      select 1 from public.purchase_order_lines pol
      where pol.po_id = p_doc_id and pol.over_ceiling
    ) then
    perform public._create_alert(
      p_property_id,
      'OVER_CEILING_APPROVED',
      'warn',
      'PO duyệt vượt giá trần',
      jsonb_build_object(
        'doc_no', (select doc_no from public.purchase_orders where id = p_doc_id),
        'approved_by', auth.uid()
      ),
      'purchase_order',
      p_doc_id
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'doc_type', p_doc_type,
    'doc_id', p_doc_id,
    'status', v_new_status,
    'pending_steps', coalesce(v_pending, 0)
  );
end;
$$;

revoke all on function public._decide_approval(uuid, text, uuid, text, text)
  from public, anon, authenticated;
-- Audit trail for the migration itself (pattern from earlier migrations).
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109547000_decide_approval_requisition_waste',
  'INSERT',
  jsonb_build_object('event', 'q221_decide_approval_req_waste', 'task', 'T-030/T-034/T-046'),
  auth.uid(),
  jsonb_build_object('source', 'migration')
);
