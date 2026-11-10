-- ===========================================================================
-- C8 (completion-2): 3 RPC con thieu + diem phat canh bao cho 4 ma chet.
--   (audit chuc nang 10/11/2026 §2.5/§2.7/§2.8/§2.9 + §3 muc 9;
--    docs/05-BUSINESS-RULES.md §10, docs/09-API-RPC.md §9,
--    docs/11-TESTING.md §6.8, docs/OPEN-QUESTIONS.md Q31/Q42/Q80/Q101)
--
--   1. RPC moi (theo dung mau RPC anh em gan nhat — cung quyen + SoD +
--      write-guard; khong tu bia luat moi; gia dinh ghi o Q tuong ung):
--        count_adjust_reject   (anh em count_adjust_post, 280000; Q31)
--        trolley_shift_cancel  (anh em trolley_shift_open/close, 310000; Q42)
--        service_accept_reverse (anh em service_accept, 350000; Q80)
--   2. Diem phat canh bao (chi them _create_alert, khong doi luat chan):
--        UNLOCK                      <- day_unlock (120000; 05 §10)
--        OVER_CEILING_APPROVED       <- _decide_approval (210000)
--        PRICE_SPIKE                 <- receiving_post qua helper
--                                       _check_price_spike moi (05 §2/§10:
--                                       > TB 7 ngay + price_spike_pct,
--                                       mac dinh 10%)
--        PERMISSION_CRITICAL_CHANGED <- admin_role_set_permissions /
--                                       admin_user_assign_role /
--                                       admin_permission_override_set
--                                       (400000; 09 §9)
--   3. Ham dinh nghia lai o day duoc trich byte-exact tu migration goc
--      (chi chen them khoi _create_alert / kiem tra gia) — khong doi
--      hanh vi khac: quyen, SoD, trang thai, write-guard giu nguyen.
--
--   LUU Y (SERVICE_UNACCEPTED_PAYMENT — KHONG them alert, xem Q101):
--   alert chen truoc `raise ERR_SERVICE_NOT_ACCEPTED` se bi rollback
--   cung transaction cua RPC khi loi truyen ra ngoai, nen giu lenh
--   _create_alert o do chi la code chet. Quyet dinh (fix 11/11/2026):
--   KHONG chen alert vao invoice_match / payment_request_create —
--   2 ham nay giu nguyen ban 350000 (khong dinh nghia lai o day);
--   hanh vi chan (Q72) giu nguyen. Muon bao ben vung can co che
--   hang doi alert rieng hoac alert o phia caller sau khi bat loi
--   (quyet dinh sau).
--
--   KHONG doi: khong them ma quyen moi (3 RPC moi dung lai quyen cua
--   anh em); khong sua seed; khong cham route mobile; khong cham
--   period_reopen (UNLOCK cho mo lai ky — de task sau quyet, xem Q101
--   khong bao gom; chi day_unlock thuoc pham vi C8).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Schema: cot audit cho 2 RPC moi + mo rong check trang thai.
--    count_adjustments.status them 'rejected' (truoc chi
--    'pending'/'approved'); trolley_shifts them cot huy ca (bang goc
--    310000 da co status 'cancelled' nhung chua co cot ly do/nguoi huy).
--    service_acceptances KHONG them cot: reverse xoa dong + ghi audit_log
--    rieng (mau admin_user_revoke_role o 010000), nghiem thu lai chay
--    binh thuong nho unique index partial san co.
-- ---------------------------------------------------------------------------
do $$
declare
  v_con name;
begin
  select conname into v_con
  from pg_constraint
  where conrelid = 'public.count_adjustments'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) like '%pending%';
  if v_con is not null then
    execute format('alter table public.count_adjustments drop constraint %I', v_con);
  end if;
end $$;

alter table public.count_adjustments
add constraint count_adjustments_status_check
check (status in ('pending', 'approved', 'rejected'));

alter table public.count_adjustments
add column if not exists rejected_by uuid references auth.users(id),
add column if not exists rejected_at timestamptz,
add column if not exists reject_reason text;

alter table public.trolley_shifts
add column if not exists cancel_reason text,
add column if not exists cancelled_by uuid references auth.users(id),
add column if not exists cancelled_at timestamptz;

-- ---------------------------------------------------------------------------
-- 2. RPC moi: count_adjust_reject — tu choi dieu chinh chenh lech kiem dem.
--    Anh em: count_adjust_post (280000 §11) — cung quyen
--    'count.adjust.approve' (Q31 chua chot; gia dinh: nguoi duoc duyet
--    cung duoc tu choi — xem docs/OPEN-QUESTIONS.md Q31). Khong co SoD
--    moi (anh em cung khong co). Tra dot ve 'submitted' de dem lai /
--    khoa lai; ly do tu choi bat buoc (mau count_cancel).
--    locked_by/locked_at giu nguyen lam lich su (count_lock ghi de khi
--    khoa lai).
-- ---------------------------------------------------------------------------
create or replace function public.count_adjust_reject(
  p_count_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_count public.stock_counts%rowtype;
  v_adj public.count_adjustments%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_count_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  select * into v_count from public.stock_counts where id = p_count_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if v_count.status <> 'locked' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform public.require_perm(v_count.property_id, 'count.adjust.approve');

  select * into v_adj from public.count_adjustments
  where count_id = p_count_id;
  if not found or v_adj.status <> 'pending' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  perform set_config('app.count_guard_bypass', 'on', true);

  update public.count_adjustments
  set status = 'rejected', rejected_by = auth.uid(), rejected_at = now(),
    reject_reason = p_reason
  where id = v_adj.id;

  update public.stock_counts
  set status = 'submitted'
  where id = p_count_id;

  return jsonb_build_object(
    'ok', true, 'id', p_count_id, 'status', 'submitted'
  );
end;
$$;

revoke all on function public.count_adjust_reject(uuid, text)
  from public, anon;
grant execute on function public.count_adjust_reject(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPC moi: trolley_shift_cancel — huy ca xe day dang mo.
--    Anh em: trolley_shift_open/trolley_shift_close (310000) — cung
--    quyen 'hk.trolley.operate' (Q42 chua chot; gia dinh: nguoi duoc
--    mo/dong ca cung duoc huy ca — xem docs/OPEN-QUESTIONS.md Q42).
--    Chi huy khi ca con 'open'; ly do bat buoc (mau count_cancel).
--    Phieu linh bu top-up KHONG huy kem: neu con 'submitted' thi huy
--    rieng bang requisition_cancel, neu da duyet/xuat thi hang da vao
--    kho xe day (xem Q42). Dem dau ca (stock_counts kind='trolley',
--    'submitted') giu nguyen nhu khi dong ca (trolley_shift_close
--    cung khong doi trang thai dem dau ca).
-- ---------------------------------------------------------------------------
create or replace function public.trolley_shift_cancel(
  p_shift_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_s record;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_shift_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

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

  perform set_config('app.hk_guard_bypass', 'on', true);

  update public.trolley_shifts
  set status = 'cancelled',
    cancel_reason = p_reason,
    cancelled_by = auth.uid(),
    cancelled_at = now(),
    updated_at = now()
  where id = p_shift_id;

  return jsonb_build_object(
    'ok', true, 'shift_id', p_shift_id,
    'status', 'cancelled',
    'requisition_id', v_s.requisition_id
  );
end;
$$;

revoke all on function public.trolley_shift_cancel(uuid, text)
  from public, anon, authenticated;
grant execute on function public.trolley_shift_cancel(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RPC moi: service_accept_reverse — dao nghiem thu dich vu.
--    Anh em: service_accept (350000 D3/D4, sua boi 430000 them p_note)
--    — cung quyen 'service.accept' (Q80 chua chot; gia dinh: nguoi
--    duoc nghiem thu cung duoc dao nghiem thu — xem
--    docs/OPEN-QUESTIONS.md Q80). SoD giong anh em: nguoi tu nghiem
--    thu khong duoc tu dao nghiem thu cua chinh minh neu khong co
--    ngoai le SOD_SERVICE_ACCEPTOR hop le (mau _sod_check o
--    service_accept). Ly do bat buoc.
--    - Nhan (p_acceptance_id): xoa dong nghiem thu + tra ky ve
--      'performed' (nguoc voi service_accept: 'scheduled'/'performed'
--      -> 'accepted'; gia dinh ky truoc nghiem thu da 'performed' vi
--      nghiem thu chi co nghia sau khi dich vu da thuc hien — xem Q80).
--      PO le khong doi trang thai (service_accept cung khong doi).
--    - Chan dao khi da co hoa don da khop tro di cho ky/PO do: giu
--      khop 3 chieu (Q72) khong bi vo.
--    - Dong nghiem thu bi xoa nen ghi audit_log rieng (mau
--      admin_user_revoke_role o 010000) de giu dau vet ai dao, ly do gi.
--    - Nghiem thu lai sau khi dao chay binh thuong: unique index
--      partial cua service_acceptances chi chan khi dong cu con ton tai.
-- ---------------------------------------------------------------------------
create or replace function public.service_accept_reverse(
  p_acceptance_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_acc public.service_acceptances%rowtype;
  v_sched public.service_schedules%rowtype;
  v_property uuid;
begin
  if p_acceptance_id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  select * into v_acc from public.service_acceptances
  where id = p_acceptance_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  v_property := v_acc.property_id;

  perform public.require_perm(v_property, 'service.accept');

  if v_acc.schedule_id is not null then
    select * into v_sched from public.service_schedules
    where id = v_acc.schedule_id;
    if not found or v_sched.status <> 'accepted' then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    -- Da len hoa don (da khop tro di) cho ky nay thi khong dao.
    if exists (
      select 1
      from public.supplier_invoice_lines sil
      join public.supplier_invoices si on si.id = sil.invoice_id
      join public.purchase_order_lines pol on pol.id = sil.po_line_id
      join public.purchase_orders po on po.id = pol.po_id
      where po.service_contract_id = v_sched.contract_id
        and si.status in ('matched', 'approved', 'partially_paid', 'paid')
        and si.invoice_date between v_sched.period_start and v_sched.period_end
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
  else
    -- PO dich vu le: chan dao neu da co hoa don da khop tro di cho PO.
    if exists (
      select 1
      from public.supplier_invoice_lines sil
      join public.supplier_invoices si on si.id = sil.invoice_id
      join public.purchase_order_lines pol on pol.id = sil.po_line_id
      where pol.po_id = v_acc.po_id
        and si.status in ('matched', 'approved', 'partially_paid', 'paid')
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
  end if;

  -- SoD (giong service_accept D4): nguoi tu nghiem thu khong duoc tu
  -- dao nghiem thu cua chinh minh neu khong co ngoai le SoD hop le.
  if v_acc.accepted_by = auth.uid() then
    perform public._sod_check(v_property, 'SOD_SERVICE_ACCEPTOR');
  end if;

  perform set_config('app.service_guard_bypass', 'on', true);

  delete from public.service_acceptances where id = p_acceptance_id;

  if v_acc.schedule_id is not null then
    update public.service_schedules
    set status = 'performed', updated_at = now()
    where id = v_acc.schedule_id;
  end if;

  insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
  values (
    'service_acceptances',
    p_acceptance_id::text,
    'DELETE',
    jsonb_build_object(
      'event', 'service_accept_reverse',
      'reason', p_reason,
      'schedule_id', v_acc.schedule_id,
      'po_id', v_acc.po_id
    ),
    auth.uid(),
    jsonb_build_object('source', 'service_accept_reverse')
  );

  return jsonb_build_object(
    'ok', true, 'id', p_acceptance_id, 'status', 'reversed',
    'schedule_id', v_acc.schedule_id, 'po_id', v_acc.po_id
  );
end;
$$;

revoke all on function public.service_accept_reverse(uuid, text)
  from public, anon, authenticated;
grant execute on function public.service_accept_reverse(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Helper noi bo: kiem tra gia nhap dot bien (PRICE_SPIKE).
--    Khong grant execute — chi RPC SECURITY DEFINER goi (mau
--    _service_po_accepted o 350000 §5).
--    Quy tac (05 §2/§10, 08 §3): don gia nhap > TB 7 ngay (gom ngay
--    hien tai) cua cung ma tai cung KS + nguong price_spike_pct
--    (mac dinh 10%, doc qua _setting_get 3 tang KS -> chuoi -> mac
--    dinh). Chi tinh move 'receipt' da post truoc do, loai move cua
--    chinh chung tu dang post. Chong spam: 1 alert chua ack cho
--    1 ma / 1 ngay / 1 KS (mau MINIBAR_MISMATCH o 320000).
-- ---------------------------------------------------------------------------
create or replace function public._check_price_spike(
  p_property_id uuid,
  p_org_id uuid,
  p_item_id uuid,
  p_unit_cost numeric,
  p_business_date date,
  p_doc_type text,
  p_doc_id uuid
)
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_pct numeric;
  v_avg numeric;
begin
  if p_unit_cost is null or p_unit_cost <= 0 then
    return;
  end if;

  v_pct := ((public._setting_get(p_org_id, p_property_id, 'price_spike_pct'))::text)::numeric;

  select avg(sm.unit_cost) into v_avg
  from public.stock_moves sm
  where sm.property_id = p_property_id
    and sm.item_id = p_item_id
    and sm.move_type = 'receipt'
    and sm.business_date between p_business_date - 6 and p_business_date
    and not (sm.source_doc_type = p_doc_type and sm.source_doc_id = p_doc_id);

  if v_avg is null or v_avg <= 0 then
    return;
  end if;
  if p_unit_cost <= v_avg * (1 + v_pct / 100) then
    return;
  end if;

  if exists (
    select 1 from public.alerts al
    where al.code = 'PRICE_SPIKE'
      and al.property_id = p_property_id
      and al.ack_at is null
      and (al.payload ->> 'item_id') = p_item_id::text
      and (al.payload ->> 'business_date') = p_business_date::text
  ) then
    return;
  end if;

  perform public._create_alert(
    p_property_id,
    'PRICE_SPIKE',
    'warn',
    'Giá nhập tăng đột biến',
    jsonb_build_object(
      'item_id', p_item_id,
      'unit_cost', p_unit_cost,
      'avg_7d', v_avg,
      'pct', v_pct,
      'business_date', p_business_date
    ),
    p_doc_type,
    p_doc_id
  );
end;
$$;

revoke all on function public._check_price_spike(uuid, uuid, uuid, numeric, date, text, uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Dinh nghia lai day_unlock (120000): them alert UNLOCK.
-- ---------------------------------------------------------------------------
create or replace function public.day_unlock(
  p_lock_id uuid,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_lock public.day_locks%rowtype;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'ERR_FORBIDDEN';
  end if;

  if p_reason is null or btrim(p_reason) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;

  select * into v_lock
  from public.day_locks
  where id = p_lock_id;

  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_LOCK_NOT_FOUND';
  end if;

  perform public.require_perm(v_lock.property_id, 'day.unlock', v_lock.warehouse_id);

  delete from public.day_locks where id = p_lock_id;

  -- C8: mo khoa ngay -> alert UNLOCK (05 §10, 08 §3: red, Zalo/email,
  -- khan). Chi bao, khong chan.
  perform public._create_alert(
    v_lock.property_id,
    'UNLOCK',
    'red',
    'Mở khóa ngày ' || to_char(v_lock.business_date, 'DD/MM/YYYY'),
    jsonb_build_object(
      'warehouse_id', v_lock.warehouse_id,
      'business_date', v_lock.business_date,
      'unlocked_by', auth.uid(),
      'reason', p_reason
    ),
    'day_lock',
    p_lock_id
  );

  return jsonb_build_object('ok', true, 'id', p_lock_id);
end;
$$;

revoke all on function public.day_unlock(uuid, text) from public, anon;
grant execute on function public.day_unlock(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Dinh nghia lai _decide_approval (210000): them alert OVER_CEILING_APPROVED.
-- ---------------------------------------------------------------------------
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

  if p_doc_type = 'pr' then
    update public.purchase_requests
    set status = v_new_status where id = p_doc_id;
  else
    update public.purchase_orders
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

-- ---------------------------------------------------------------------------
-- 8. Dinh nghia lai receiving_post (230000): them kiem tra PRICE_SPIKE.
-- ---------------------------------------------------------------------------
create or replace function public.receiving_post(
  p_gr_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_gr record;
  v_po record;
  v_line record;
  v_pol record;
  v_item record;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_tol numeric;
  v_remaining numeric;
  v_cap numeric;
  v_accepted numeric;
  v_unit_cost numeric;
  v_lot_id uuid;
  v_lot_expiry date;
  v_target_wh uuid;
  v_final_wh uuid;
  v_move_id bigint;
  v_out_cost numeric;
  v_total numeric := 0;
  v_posted_lines int := 0;
  v_att_count int;
begin
  select gr.* into v_gr
  from public.goods_receipts gr
  where gr.id = p_gr_id;

  if v_gr.id is null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform public.require_perm(v_gr.property_id, 'receiving.post');

  if v_gr.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Chi nguoi nhan da mo phieu moi duoc post phieu do.
  if v_gr.receiver_id <> auth.uid() then
    raise exception using errcode = 'P0001',
      message = 'ERR_FORBIDDEN:receiving.post';
  end if;

  -- PIN kiem truoc khi cham den ton kho.
  perform public._verify_pin(p_pin);

  -- SoD: nguoi tao/duyet PO khong duoc nhan; nguoi giu tam ung cho khong
  -- duoc nhan PO cho do. _sod_check chi raise khi khong co ngoai le hop le.
  select po.* into v_po
  from public.purchase_orders po
  where po.id = v_gr.po_id;

  if v_po.created_by = auth.uid() then
    perform public._sod_check(v_gr.property_id, 'SOD_PO_RECEIVER');
  end if;

  if exists (
    select 1 from public.approvals a
    where a.doc_type = 'po' and a.doc_id = v_gr.po_id
      and a.decision = 'approved' and a.decided_by = auth.uid()
  ) then
    perform public._sod_check(v_gr.property_id, 'SOD_PO_RECEIVER');
  end if;

  if v_po.advance_id is not null and exists (
    select 1 from public.advances ad
    where ad.id = v_po.advance_id and ad.employee_id = auth.uid()
  ) then
    perform public._sod_check(v_gr.property_id, 'SOD_MARKET_BUYER_RECEIVER');
  end if;

  -- Chan post khi con dong chua can lai xong (can 1 lech, chua can lan 2).
  if exists (
    select 1 from public.goods_receipt_lines grl
    where grl.gr_id = p_gr_id
      and grl.needs_reweigh
      and grl.weigh_count = 1
  ) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Moi phieu phai co it nhat 1 anh (05 §3: "Anh chup phieu (bat buoc)").
  select count(*) into v_att_count
  from public.attachments a
  where a.doc_type = 'receiving' and a.doc_id = p_gr_id;

  if v_att_count = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_PHOTO_REQUIRED';
  end if;

  v_tol := public._receiving_tolerance_pct(v_gr.org_id, v_gr.property_id);

  perform set_config('app.receiving_guard_bypass', 'on', true);

  for v_line in
    select * from public.goods_receipt_lines
    where gr_id = p_gr_id
    order by created_at
  loop
    -- Dong QC fail: khong vao kho (phieu tra 'recorded' da sinh luc ghi).
    if v_line.qc_status = 'fail' then
      continue;
    end if;

    select pol.* into v_pol
    from public.purchase_order_lines pol
    where pol.id = v_line.po_line_id
    for update;

    if v_pol.id is null then
      continue;
    end if;

    v_remaining := v_pol.qty_stock - v_pol.received_qty_stock;
    v_cap := v_remaining * (1 + v_tol / 100);

    -- Cap ve so con mo tai luc post; dong co override thi khong cap.
    if v_line.override_by is not null then
      v_accepted := v_line.accepted_qty_stock;
    else
      v_accepted := least(v_line.accepted_qty_stock, greatest(v_cap, 0));
    end if;

    if v_accepted <= 0 then
      continue;
    end if;

    select i.* into v_item
    from public.items i
    where i.id = v_line.item_id and i.org_id = v_gr.org_id;

    -- Don gia theo UOM cua dong PO (xem chu thich o receiving_record_line).
    v_unit_cost := public._receiving_unit_cost_stock(
      v_gr.org_id, v_line.item_id, v_pol.uom, v_pol.unit_price);

    -- C8: gia nhap vuot TB 7 ngay + nguong -> alert PRICE_SPIKE
    -- (05 §2/§10, 08 §3: warn, App; nguong mac dinh 10% qua setting
    -- price_spike_pct). Chi bao, khong chan nhan hang. Kiem tra
    -- TRUOC khi post move cua dong nay de TB 7 ngay chi tinh gia
    -- nhan truoc do (loai move cua chinh phieu nay).
    perform public._check_price_spike(
      v_gr.property_id, v_gr.org_id, v_line.item_id, v_unit_cost,
      v_today, 'goods_receipt', p_gr_id
    );

    -- Lot: tim hoac tao (hang theo lot).
    v_lot_id := null;
    if v_item.track_lot then
      if v_line.lot_no is null or v_line.expiry_date is null then
        raise exception using errcode = 'P0001', message = 'ERR_LOT_REQUIRED';
      end if;

      insert into public.lots (org_id, property_id, item_id, lot_no, expiry_date)
      values (v_gr.org_id, v_gr.property_id, v_line.item_id,
        v_line.lot_no, v_line.expiry_date)
      on conflict (property_id, item_id, lot_no) do nothing
      returning id into v_lot_id;

      if v_lot_id is null then
        select l.id, l.expiry_date into v_lot_id, v_lot_expiry
        from public.lots l
        where l.property_id = v_gr.property_id
          and l.item_id = v_line.item_id
          and l.lot_no = v_line.lot_no;

        if v_lot_expiry is distinct from v_line.expiry_date then
          raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
        end if;
      end if;
    end if;

    -- Kho dich: QC conditional -> kho cach ly; binh thuong -> kho nhan.
    if v_line.qc_status = 'conditional' then
      v_target_wh := public._receiving_quarantine_wh(v_gr.property_id);
    else
      v_target_wh := v_gr.warehouse_id;
    end if;

    v_move_id := public._post_move(
      v_gr.legal_entity_id, v_gr.property_id, v_target_wh,
      v_line.item_id, v_lot_id, 'receipt', v_accepted, v_unit_cost,
      v_today, 'goods_receipt', p_gr_id, v_line.id);

    v_final_wh := v_target_wh;

    -- Nhan thang ra bep (chi dong pass): receipt + issue_out + issue_in.
    if v_gr.direct_issue_warehouse_id is not null
      and v_line.qc_status = 'pass' then
      v_move_id := public._post_move(
        v_gr.legal_entity_id, v_gr.property_id, v_target_wh,
        v_line.item_id, v_lot_id, 'issue_out', -v_accepted, null,
        v_today, 'goods_receipt', p_gr_id, v_line.id);

      select sm.unit_cost into v_out_cost
      from public.stock_moves sm
      where sm.id = v_move_id;

      perform public._post_move(
        v_gr.legal_entity_id, v_gr.property_id,
        v_gr.direct_issue_warehouse_id,
        v_line.item_id, v_lot_id, 'issue_in', v_accepted, v_out_cost,
        v_today, 'goods_receipt', p_gr_id, v_line.id);

      v_final_wh := v_gr.direct_issue_warehouse_id;
    end if;

    update public.goods_receipt_lines
    set accepted_qty_stock = v_accepted,
        unit_cost = v_unit_cost,
        lot_id = v_lot_id,
        posted_warehouse_id = v_final_wh,
        updated_at = now()
    where id = v_line.id;

    update public.purchase_order_lines
    set received_qty_stock = received_qty_stock + v_accepted,
        updated_at = now()
    where id = v_pol.id;

    v_total := v_total + round(v_accepted * v_unit_cost, 2);
    v_posted_lines := v_posted_lines + 1;
  end loop;

  if v_posted_lines = 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  update public.goods_receipts
  set status = 'posted',
      total_amount = round(v_total, 2),
      received_at = now(),
      updated_at = now()
  where id = p_gr_id;

  perform public._receiving_update_po_status(v_gr.po_id);

  return jsonb_build_object(
    'ok', true,
    'id', p_gr_id,
    'lines_posted', v_posted_lines
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. Dinh nghia lai 3 ham quan tri (400000): them alert PERMISSION_CRITICAL_CHANGED.
-- ---------------------------------------------------------------------------
create or replace function public.admin_role_set_permissions(
  p_role_id uuid,
  p_permission_codes text[]
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role public.roles;
  v_added text[];
  v_removed text[];
  v_conflicts jsonb;
  v_critical boolean;
  v_unknown text[];
begin
  perform public.require_perm(null, 'admin.roles.manage');

  select * into v_role from public.roles r where r.id = p_role_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select array_agg(code) into v_unknown
  from unnest(coalesce(p_permission_codes, '{}'::text[])) code
  where code not in (select p.code from public.permissions p);
  if v_unknown is not null then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  select array_agg(permission_code order by permission_code) into v_added
  from unnest(coalesce(p_permission_codes, '{}'::text[])) code(permission_code)
  where code not in (select rp.permission_code from public.role_permissions rp where rp.role_id = p_role_id);
  select array_agg(rp.permission_code order by rp.permission_code) into v_removed
  from public.role_permissions rp
  where rp.role_id = p_role_id
    and rp.permission_code <> all(coalesce(p_permission_codes, '{}'::text[]));

  delete from public.role_permissions rp where rp.role_id = p_role_id;
  insert into public.role_permissions (role_id, permission_code)
  select p_role_id, code
  from unnest(coalesce(p_permission_codes, '{}'::text[])) code
  on conflict do nothing;

  v_conflicts := (select public.admin_sod_conflict_check(null, p_role_id) -> 'conflicts');
  v_critical := exists (
    select 1 from public.permissions p
    where p.code = any(coalesce(v_added, '{}'::text[]))
      and p.risk_level = 'critical'
  ) or exists (
    select 1 from public.permissions p
    where p.code = any(coalesce(v_removed, '{}'::text[]))
      and p.risk_level = 'critical'
  );

  -- C8: thay doi quyen muc 'critical' -> alert
  -- PERMISSION_CRITICAL_CHANGED (09 §9, 08 §3: red, Zalo/email,
  -- khan). Chi bao, khong chan luu (tinh than admin-relax: chi
  -- canh bao, khong chan). Thay doi o cap chuoi (khong co
  -- property) nen alert khong gan property cu the.
  if v_critical then
    perform public._create_alert(
      null,
      'PERMISSION_CRITICAL_CHANGED',
      'red',
      'Thay đổi quyền mức quan trọng',
      jsonb_build_object(
        'role_id', p_role_id,
        'role_code', v_role.code,
        'added', coalesce(v_added, '{}'::text[]),
        'removed', coalesce(v_removed, '{}'::text[]),
        'changed_by', auth.uid()
      )
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'role_id', p_role_id,
    'added', coalesce(v_added, '{}'::text[]),
    'removed', coalesce(v_removed, '{}'::text[]),
    'conflicts', coalesce(v_conflicts, '[]'::jsonb),
    'critical_changed', v_critical
  );
end;
$$;

revoke all on function public.admin_role_set_permissions(uuid, text[]) from public, anon;
grant execute on function public.admin_role_set_permissions(uuid, text[]) to authenticated;

create or replace function public.admin_user_assign_role(
  p_user_id uuid,
  p_role_id uuid,
  p_property_id uuid default null,
  p_outlet_ids uuid[] default null,
  p_warehouse_ids uuid[] default null,
  p_valid_from date default null,
  p_valid_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_role public.roles;
  v_assignment_id uuid;
  v_from date := coalesce(p_valid_from, (now() at time zone 'Asia/Ho_Chi_Minh')::date);
begin
  perform public.require_perm(p_property_id, 'admin.users.manage');


  select * into v_role from public.roles r where r.id = p_role_id;
  if not found or not v_role.active then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if p_valid_to is not null and p_valid_to < v_from then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  insert into public.user_property_roles (
    user_id, role_id, property_id, outlet_ids, warehouse_ids,
    valid_from, valid_to, granted_by
  )
  values (
    p_user_id, p_role_id, p_property_id, p_outlet_ids, p_warehouse_ids,
    v_from, p_valid_to, auth.uid()
  )
  returning id into v_assignment_id;

  -- C8: gan vai tro chua quyen muc 'critical' -> alert
  -- PERMISSION_CRITICAL_CHANGED (09 §9, 08 §3: red, Zalo/email,
  -- khan). Chi bao, khong chan gan (tinh than admin-relax).
  if exists (
    select 1
    from public.role_permissions rp
    join public.permissions p on p.code = rp.permission_code
    where rp.role_id = p_role_id
      and p.risk_level = 'critical'
  ) then
    perform public._create_alert(
      p_property_id,
      'PERMISSION_CRITICAL_CHANGED',
      'red',
      'Gán vai trò có quyền mức quan trọng',
      jsonb_build_object(
        'role_id', p_role_id,
        'role_code', v_role.code,
        'user_id', p_user_id,
        'assignment_id', v_assignment_id,
        'granted_by', auth.uid()
      )
    );
  end if;

  return jsonb_build_object('ok', true, 'id', v_assignment_id);
end;
$$;

revoke all on function public.admin_user_assign_role(uuid, uuid, uuid, uuid[], uuid[], date, date) from public, anon;
grant execute on function public.admin_user_assign_role(uuid, uuid, uuid, uuid[], uuid[], date, date) to authenticated;

create or replace function public.admin_permission_override_set(
  p_user_id uuid,
  p_property_id uuid,
  p_permission_code text,
  p_effect text,
  p_valid_to date,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_override_id uuid;
begin
  perform public.require_perm(p_property_id, 'admin.permissions.override');

  if p_effect not in ('allow', 'deny') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if btrim(coalesce(p_reason, '')) = '' then
    raise exception using errcode = 'P0001', message = 'ERR_REASON_REQUIRED';
  end if;
  if not exists (select 1 from public.permissions p where p.code = p_permission_code) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;
  if not exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
  end if;

  -- Chặn quyền quản trị cấp chuỗi của một trong hai quản trị cuối thì chặn.
  if p_effect = 'deny'
    and p_property_id is null
    and p_permission_code in ('admin.users.manage', 'admin.roles.manage') then
    perform public.admin_require_not_last_admin(p_user_id);
  end if;

  insert into public.user_permission_overrides (
    user_id, property_id, permission_code, effect, valid_to, reason, granted_by
  )
  values (
    p_user_id, p_property_id, p_permission_code, p_effect, p_valid_to, p_reason, auth.uid()
  )
  returning id into v_override_id;

  -- C8: cap/chan rieng quyen muc 'critical' -> alert
  -- PERMISSION_CRITICAL_CHANGED (09 §9, 08 §3: red, Zalo/email,
  -- khan). Chi bao, khong chan luu (tinh than admin-relax).
  if exists (
    select 1 from public.permissions p
    where p.code = p_permission_code and p.risk_level = 'critical'
  ) then
    perform public._create_alert(
      p_property_id,
      'PERMISSION_CRITICAL_CHANGED',
      'red',
      'Ghi đè quyền mức quan trọng',
      jsonb_build_object(
        'user_id', p_user_id,
        'permission_code', p_permission_code,
        'effect', p_effect,
        'override_id', v_override_id,
        'granted_by', auth.uid()
      )
    );
  end if;

  return jsonb_build_object('ok', true, 'id', v_override_id);
end;
$$;

revoke all on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) from public, anon;
grant execute on function public.admin_permission_override_set(uuid, uuid, text, text, date, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Audit trail cho chinh migration nay (pattern 210000/260000/310000).
-- ---------------------------------------------------------------------------
insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
values (
  'schema_migrations',
  '20261109527000_missing_rpcs_alerts',
  'INSERT',
  '{"event": "c8_missing_rpcs_alerts_completed", "task": "completion-2/C8", "rpcs": ["count_adjust_reject", "trolley_shift_cancel", "service_accept_reverse"], "alerts": ["UNLOCK", "OVER_CEILING_APPROVED", "PRICE_SPIKE", "PERMISSION_CRITICAL_CHANGED"]}'::jsonb,
  auth.uid(),
  jsonb_build_object('source', 'migration', 'task', 'completion-2/C8')
);
