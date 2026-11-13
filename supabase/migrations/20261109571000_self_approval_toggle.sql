-- ============================================================================
-- Q258 — 20261109571000_self_approval_toggle
--   Quyet dinh Duy 13/11/2026: quan ly co cong tat cho/khong cho vai tro de xuat
--   TU DUYET chung tu do chinh minh tao. Dung co rule.* co san (Q214/Q240):
--     rule.SELF_PR.enabled     de xuat mua (PR)
--     rule.SELF_REQ.enabled    phieu linh kho
--     rule.SELF_WASTE.enabled  phieu huy hang
--   Gia tri 1 = BAT rang buoc = CHAN tu duyet (MAC DINH, nhu cu); 0 = cho phep.
--   Dat o /admin/settings (muc "Bat/tat rang buoc"), theo khach san hoac toan
--   chuoi. Moi lan doi: audit_log + canh bao RULE_TOGGLED; moi lan tu duyet khi
--   cong tat: canh bao SOD_EXCEPTION_USED. PO KHONG co cong tat — luon chan
--   (SOD_PO_CREATOR_APPROVER). Nguoi tu duyet van phai la nguoi duoc giao buoc
--   duyet (vai tro + quyen).
--   Doi di kem: sm_manager them admin.settings.manage de tu bat/tat cong.
--   Sinh lai tu ban dang chay tren production: _rule_enabled,
--   _admin_setting_default, admin_settings_list, admin_setting_save (sua cach
--   lay ten ma trong tieu de canh bao de nhan ca ma SELF_*), _decide_approval,
--   seed_compact_roles.
-- ============================================================================

alter table public.settings drop constraint if exists settings_key_check;
alter table public.settings add constraint settings_key_check check (key = any (array[
  'price_spike_pct', 'receiving_tolerance_pct', 'market_advance_deadline_hours',
  'waste_approval_threshold_vnd', 'count_random_items', 'count_variance_threshold_pct',
  'count_recount_threshold_pct', 'count_without_cc_factor', 'invoice_price_tolerance_pct',
  'rule.R25.enabled', 'rule.R18.enabled', 'rule.R32.enabled',
  'rule.SELF_PR.enabled', 'rule.SELF_REQ.enabled', 'rule.SELF_WASTE.enabled'
]));

CREATE OR REPLACE FUNCTION public._rule_enabled(p_property_id uuid, p_rule_code text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$

declare
  v_org_id uuid;
  v_value jsonb;
begin
  -- Chi cac ma co da biet; ma la -> mac dinh BAT (fail closed).
  if p_rule_code is null or p_rule_code not in ('R25', 'R18', 'R32', 'SELF_PR', 'SELF_REQ', 'SELF_WASTE') then
    return true;
  end if;
  if p_property_id is null then
    return true;
  end if;

  select p.org_id into v_org_id
  from public.properties p
  where p.id = p_property_id;
  if v_org_id is null then
    return true;
  end if;

  -- Tra theo property truoc, neu khong co thi tra ban org (property_id
  -- IS NULL), neu khong co nua thi mac dinh BAT.
  select s.value into v_value
  from public.settings s
  where s.org_id = v_org_id and s.property_id = p_property_id
    and s.key = 'rule.' || p_rule_code || '.enabled';
  if v_value is null then
    select s.value into v_value
    from public.settings s
    where s.org_id = v_org_id and s.property_id is null
      and s.key = 'rule.' || p_rule_code || '.enabled';
  end if;
  if v_value is null then
    return true;
  end if;

  -- Gia tri luu dang jsonb number (0 = tat, khac 0 = bat) theo CHECK cua
  -- bang settings; cac nhanh string/boolean chi de phong khi co nguoi
  -- chen truc tiep (hien CHECK chan kieu khac number).
  if jsonb_typeof(v_value) = 'number' then
    return (v_value #>> '{}')::numeric <> 0;
  elsif jsonb_typeof(v_value) = 'boolean' then
    return (v_value #>> '{}')::boolean;
  elsif jsonb_typeof(v_value) = 'string' then
    return lower(btrim(v_value #>> '{}')) not in ('false', '0', 'off', 'no', '');
  else
    return true;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public._admin_setting_default(p_key text)
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$

  select case p_key
    when 'price_spike_pct' then '10'::jsonb
    when 'receiving_tolerance_pct' then '5'::jsonb
    when 'market_advance_deadline_hours' then '24'::jsonb
    when 'waste_approval_threshold_vnd' then '1000000'::jsonb
    when 'count_random_items' then '3'::jsonb
    when 'count_variance_threshold_pct' then '3'::jsonb
    when 'count_recount_threshold_pct' then '5'::jsonb
    when 'rule.R25.enabled' then '1'::jsonb
    when 'rule.R18.enabled' then '1'::jsonb
    when 'rule.R32.enabled' then '1'::jsonb
    when 'rule.SELF_PR.enabled' then '1'::jsonb
    when 'rule.SELF_REQ.enabled' then '1'::jsonb
    when 'rule.SELF_WASTE.enabled' then '1'::jsonb
    when 'count_without_cc_factor' then '0.7'::jsonb
    when 'invoice_price_tolerance_pct' then '1'::jsonb
    else null
  end
$function$;

CREATE OR REPLACE FUNCTION public.admin_settings_list(p_org_id uuid, p_property_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$

declare
  v_settings jsonb;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.settings.manage'
  );

  select jsonb_agg(
    jsonb_build_object(
      'key', k.key,
      'value', public._setting_get(p_org_id, p_property_id, k.key) #>> '{}',
      'source', case
        when ps.id is not null then 'property'
        when os.id is not null then 'organization'
        else 'default'
      end
    )
    order by k.sort_order
  )
  into v_settings
  from (values
    ('price_spike_pct', 10),
    ('receiving_tolerance_pct', 20),
    ('market_advance_deadline_hours', 30),
    ('waste_approval_threshold_vnd', 40),
    ('count_random_items', 50),
    ('count_variance_threshold_pct', 60),
    ('count_recount_threshold_pct', 65),
    ('count_without_cc_factor', 70),
    ('invoice_price_tolerance_pct', 80),
    ('rule.R25.enabled', 90),
    ('rule.R18.enabled', 100),
    ('rule.R32.enabled', 110),
    ('rule.SELF_PR.enabled', 120),
    ('rule.SELF_REQ.enabled', 130),
    ('rule.SELF_WASTE.enabled', 140)
  ) as k(key, sort_order)
  left join public.settings ps
    on ps.org_id = p_org_id and ps.property_id = p_property_id and ps.key = k.key
  left join public.settings os
    on os.org_id = p_org_id and os.property_id is null and os.key = k.key;

  return coalesce(v_settings, '[]'::jsonb);
end;
$function$;

CREATE OR REPLACE FUNCTION public.admin_setting_save(p_org_id uuid, p_property_id uuid, p_key text, p_value text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$

declare
  v_value numeric;
  v_min numeric;
  v_max numeric;
  v_old numeric;
  v_prop uuid;
begin
  perform public._admin_config_require_perm(
    p_org_id, p_property_id, 'admin.settings.manage'
  );

  if public._admin_setting_default(p_key) is null then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  v_value := p_value::numeric;
  case p_key
    when 'price_spike_pct' then v_min := 0; v_max := 1000;
    when 'receiving_tolerance_pct' then v_min := 0; v_max := 100;
    when 'market_advance_deadline_hours' then v_min := 1; v_max := 720;
    when 'waste_approval_threshold_vnd' then v_min := 0; v_max := 9999999999999999;
    when 'count_random_items' then v_min := 2; v_max := 3;
    when 'count_variance_threshold_pct' then v_min := 0; v_max := 100;
    when 'count_recount_threshold_pct' then v_min := 0; v_max := 100;
    when 'rule.R25.enabled' then v_min := 0; v_max := 1;
    when 'rule.R18.enabled' then v_min := 0; v_max := 1;
    when 'rule.R32.enabled' then v_min := 0; v_max := 1;
    when 'rule.SELF_PR.enabled' then v_min := 0; v_max := 1;
    when 'rule.SELF_REQ.enabled' then v_min := 0; v_max := 1;
    when 'rule.SELF_WASTE.enabled' then v_min := 0; v_max := 1;
    when 'count_without_cc_factor' then v_min := 0; v_max := 1;
    when 'invoice_price_tolerance_pct' then v_min := 0; v_max := 100;
    else raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end case;

  if v_value < v_min or v_value > v_max
    or (p_key in ('market_advance_deadline_hours', 'count_random_items',
      'rule.R25.enabled', 'rule.R18.enabled', 'rule.R32.enabled',
      'rule.SELF_PR.enabled', 'rule.SELF_REQ.enabled', 'rule.SELF_WASTE.enabled')
      and v_value <> trunc(v_value))
    or (p_key = 'waste_approval_threshold_vnd' and v_value <> trunc(v_value))
    or (p_key not in (
      'market_advance_deadline_hours',
      'waste_approval_threshold_vnd',
      'count_random_items',
      'count_without_cc_factor'
    ) and v_value <> round(v_value, 2))
    or (p_key = 'count_without_cc_factor' and v_value <> round(v_value, 4)) then
    raise exception using errcode = 'P0001', message = 'ERR_CONFIG_INVALID';
  end if;

  -- C: gia tri truoc khi doi (cung pham vi; chua luu thi lay mac dinh) de
  -- biet co rule.* co that su doi khong.
  if p_key like 'rule.%' then
    select (s.value #>> '{}')::numeric into v_old
    from public.settings s
    where s.org_id = p_org_id
      and s.property_id is not distinct from p_property_id
      and s.key = p_key;
    if v_old is null then
      v_old := (public._admin_setting_default(p_key) #>> '{}')::numeric;
    end if;
  end if;

  insert into public.settings (org_id, property_id, key, value, updated_by)
  values (p_org_id, p_property_id, p_key, to_jsonb(v_value), auth.uid())
  on conflict (org_id, property_id, key) do update
    set value = excluded.value, updated_by = excluded.updated_by;

  if p_key like 'rule.%' and v_old is distinct from v_value then
    for v_prop in
      select p.id
      from public.properties p
      where p.org_id = p_org_id
        and (p_property_id is null or p.id = p_property_id)
    loop
      perform public._create_alert(
        v_prop,
        'RULE_TOGGLED',
        case when v_value = 0 then 'red' else 'warn' end,
        case when v_value = 0 then 'Tắt ràng buộc ' else 'Bật lại ràng buộc ' end
          || upper(substring(p_key from 'rule\.([A-Za-z0-9_]+)\.enabled')),
        jsonb_build_object(
          'key', p_key,
          'old_value', v_old,
          'new_value', v_value,
          'scope', case when p_property_id is null then 'org' else 'property' end,
          'changed_by', auth.uid()
        ),
        'setting',
        null
      );
    end loop;
  end if;

  return jsonb_build_object('ok', true, 'key', p_key, 'value', v_value::text);
end;
$function$;

CREATE OR REPLACE FUNCTION public._decide_approval(p_property_id uuid, p_doc_type text, p_doc_id uuid, p_decision text, p_comment text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$

declare
  v_doc record;
  v_step public.approvals%rowtype;
  v_sod_code text;
  v_pending integer;
  v_new_status text;
  v_self_rule text;
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
    -- Q258: PR / phieu linh / phieu huy — quan ly co the TAT rang buoc "nguoi
    -- tao khong duoc tu duyet" (co rule.SELF_*.enabled = 0). Mac dinh BAT
    -- (chan nhu cu). PO KHONG co co nay: luon chan. Khi tu duyet duoc phep,
    -- ghi canh bao SOD_EXCEPTION_USED de truy vet.
    v_self_rule := case p_doc_type
      when 'pr' then 'SELF_PR'
      when 'requisition' then 'SELF_REQ'
      when 'waste' then 'SELF_WASTE'
      else null
    end;
    if v_self_rule is not null
       and not public._rule_enabled(p_property_id, v_self_rule) then
      perform public._create_alert(
        p_property_id,
        'SOD_EXCEPTION_USED',
        'warn',
        'Tự duyệt chứng từ do chính mình tạo',
        jsonb_build_object(
          'rule_code', v_sod_code, 'doc_type', p_doc_type, 'doc_id', p_doc_id,
          'via', 'self_approval_flag')
      );
    else
      perform public._sod_check(p_property_id, v_sod_code);
    end if;
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
$function$;

create or replace function public.seed_compact_roles(p_org_id uuid)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_n integer;
begin
  insert into public.roles (org_id, code, name_vi, description, is_system)
  select p_org_id, r.code, r.name_vi, r.description, true
  from (
    values
    ('sm_owner', 'Chủ đầu tư', 'Giám sát toàn chuỗi, duyệt việc lớn, bật/tắt module; không làm nghiệp vụ hằng ngày.'),
    ('sm_manager', 'Quản lý', 'Điều hành khách sạn, duyệt đơn mua/hóa đơn/thanh toán/hủy, cấu hình bậc duyệt.'),
    ('sm_accountant', 'Kế toán', 'Hóa đơn, công nợ, tạm ứng, đề nghị thanh toán, đóng kỳ, xuất file kế toán.'),
    ('sm_purchasing_store', 'Thu mua & Thủ kho', 'Yêu cầu/đơn mua, giá, nhà cung cấp, xuất/chuyển/kiểm kê kho. Không nhận hàng (dùng vai trò Nhận hàng).'),
    ('sm_kitchen', 'Bếp / Nhà hàng', 'Món, công thức, buffet, tiệc, bán hàng, phiếu lĩnh, duyệt phiếu bộ phận.'),
    ('sm_housekeeping', 'Buồng phòng', 'Xe đẩy, chuẩn setup phòng, minibar, phiếu lĩnh.'),
    ('sm_frontdesk', 'Lễ tân', 'Số liệu PMS, minibar, bán hàng.')
  ) as r(code, name_vi, description)
  on conflict (org_id, code) do nothing;

  insert into public.role_permissions (role_id, permission_code)
  select ro.id, rp.permission_code
  from public.roles ro
  join (
    values
    ('sm_owner', 'admin.alert_rules.manage'),
    ('sm_owner', 'admin.approval_rules.manage'),
    ('sm_owner', 'admin.health.view'),
    ('sm_owner', 'admin.modules.manage'),
    ('sm_owner', 'admin.settings.manage'),
    ('sm_owner', 'advance.approve'),
    ('sm_owner', 'alert.receive.advance_overdue'),
    ('sm_owner', 'alert.receive.avt_daily'),
    ('sm_owner', 'alert.receive.bank_account_change'),
    ('sm_owner', 'alert.receive.count_variance'),
    ('sm_owner', 'alert.receive.minibar_check_requested'),
    ('sm_owner', 'alert.receive.minibar_loss'),
    ('sm_owner', 'alert.receive.minibar_mismatch'),
    ('sm_owner', 'alert.receive.over_ceiling_approved'),
    ('sm_owner', 'alert.receive.period_close_warning'),
    ('sm_owner', 'alert.receive.permission_critical_changed'),
    ('sm_owner', 'alert.receive.photo_reused'),
    ('sm_owner', 'alert.receive.price_spike'),
    ('sm_owner', 'alert.receive.rule_toggled'),
    ('sm_owner', 'alert.receive.service_contract_renewal'),
    ('sm_owner', 'alert.receive.service_unaccepted_payment'),
    ('sm_owner', 'alert.receive.sod_exception_used'),
    ('sm_owner', 'alert.receive.temp_item_stale'),
    ('sm_owner', 'alert.receive.unlock'),
    ('sm_owner', 'alert.receive.waste_large'),
    ('sm_owner', 'alert.receive.water_night_spike'),
    ('sm_owner', 'ap.view'),
    ('sm_owner', 'attachment.view'),
    ('sm_owner', 'audit.view_all'),
    ('sm_owner', 'count.view_variance'),
    ('sm_owner', 'day.unlock'),
    ('sm_owner', 'export.accounting'),
    ('sm_owner', 'item.view'),
    ('sm_owner', 'payment.approve'),
    ('sm_owner', 'period.close'),
    ('sm_owner', 'period.reopen'),
    ('sm_owner', 'po.approve'),
    ('sm_owner', 'po.approve.over_ceiling'),
    ('sm_owner', 'po.view'),
    ('sm_owner', 'po.view_price'),
    ('sm_owner', 'price.view'),
    ('sm_owner', 'report.daily_brief.receive'),
    ('sm_owner', 'report.receive.daily_brief'),
    ('sm_owner', 'report.view.rpt_advances'),
    ('sm_owner', 'report.view.rpt_amenity_cpor'),
    ('sm_owner', 'report.view.rpt_ap_aging'),
    ('sm_owner', 'report.view.rpt_daily_brief'),
    ('sm_owner', 'report.view.rpt_fnb_revenue'),
    ('sm_owner', 'report.view.rpt_minibar'),
    ('sm_owner', 'report.view.rpt_open_po_invoice'),
    ('sm_owner', 'report.view.rpt_opex'),
    ('sm_owner', 'report.view.rpt_receiving_quality'),
    ('sm_owner', 'report.view.rpt_stock_card'),
    ('sm_owner', 'report.view.rpt_waste'),
    ('sm_owner', 'stock.view_value'),
    ('sm_owner', 'supplier.view'),
    ('sm_owner', 'waste.approve.large'),
    ('sm_manager', 'admin.approval_rules.manage'),
    ('sm_manager', 'admin.settings.manage'),
    ('sm_manager', 'advance.approve'),
    ('sm_manager', 'alert.receive.advance_overdue'),
    ('sm_manager', 'alert.receive.avt_daily'),
    ('sm_manager', 'alert.receive.bank_account_change'),
    ('sm_manager', 'alert.receive.count_variance'),
    ('sm_manager', 'alert.receive.minibar_check_requested'),
    ('sm_manager', 'alert.receive.minibar_loss'),
    ('sm_manager', 'alert.receive.minibar_mismatch'),
    ('sm_manager', 'alert.receive.over_ceiling_approved'),
    ('sm_manager', 'alert.receive.period_close_warning'),
    ('sm_manager', 'alert.receive.permission_critical_changed'),
    ('sm_manager', 'alert.receive.photo_reused'),
    ('sm_manager', 'alert.receive.price_spike'),
    ('sm_manager', 'alert.receive.rule_toggled'),
    ('sm_manager', 'alert.receive.service_contract_renewal'),
    ('sm_manager', 'alert.receive.service_unaccepted_payment'),
    ('sm_manager', 'alert.receive.sod_exception_used'),
    ('sm_manager', 'alert.receive.temp_item_stale'),
    ('sm_manager', 'alert.receive.unlock'),
    ('sm_manager', 'alert.receive.waste_large'),
    ('sm_manager', 'alert.receive.water_night_spike'),
    ('sm_manager', 'attachment.view'),
    ('sm_manager', 'count.adjust.approve'),
    ('sm_manager', 'day.unlock'),
    ('sm_manager', 'invoice.approve'),
    ('sm_manager', 'item.import'),
    ('sm_manager', 'item.view'),
    ('sm_manager', 'minibar.price.manage'),
    ('sm_manager', 'minibar.reconcile'),
    ('sm_manager', 'minibar.waive.approve'),
    ('sm_manager', 'payment.approve'),
    ('sm_manager', 'pms.input'),
    ('sm_manager', 'po.approve'),
    ('sm_manager', 'po.approve.over_ceiling'),
    ('sm_manager', 'pos.import'),
    ('sm_manager', 'pr.approve'),
    ('sm_manager', 'price.view'),
    ('sm_manager', 'purpose_issue.post'),
    ('sm_manager', 'purpose_issue.reverse'),
    ('sm_manager', 'receiving.override_over_po'),
    ('sm_manager', 'receiving.reverse'),
    ('sm_manager', 'report.daily_brief.receive'),
    ('sm_manager', 'report.receive.daily_brief'),
    ('sm_manager', 'report.view.rpt_advances'),
    ('sm_manager', 'report.view.rpt_amenity_cpor'),
    ('sm_manager', 'report.view.rpt_ap_aging'),
    ('sm_manager', 'report.view.rpt_daily_brief'),
    ('sm_manager', 'report.view.rpt_fnb_revenue'),
    ('sm_manager', 'report.view.rpt_minibar'),
    ('sm_manager', 'report.view.rpt_open_po_invoice'),
    ('sm_manager', 'report.view.rpt_opex'),
    ('sm_manager', 'report.view.rpt_receiving_quality'),
    ('sm_manager', 'report.view.rpt_stock_card'),
    ('sm_manager', 'report.view.rpt_waste'),
    ('sm_manager', 'requisition.approve'),
    ('sm_manager', 'restaurant.banquet.manage'),
    ('sm_manager', 'restaurant.buffet.manage'),
    ('sm_manager', 'restaurant.dish.manage'),
    ('sm_manager', 'restaurant.sale.record'),
    ('sm_manager', 'restaurant.view'),
    ('sm_manager', 'room.manage'),
    ('sm_manager', 'service.contract.manage'),
    ('sm_manager', 'stock.view_qty'),
    ('sm_manager', 'supplier.approve'),
    ('sm_manager', 'supplier.view'),
    ('sm_manager', 'waste.approve'),
    ('sm_manager', 'waste.approve.large'),
    ('sm_accountant', 'advance.disburse'),
    ('sm_accountant', 'advance.settle'),
    ('sm_accountant', 'alert.receive.advance_overdue'),
    ('sm_accountant', 'alert.receive.avt_daily'),
    ('sm_accountant', 'alert.receive.bank_account_change'),
    ('sm_accountant', 'alert.receive.over_ceiling_approved'),
    ('sm_accountant', 'alert.receive.period_close_warning'),
    ('sm_accountant', 'alert.receive.permission_critical_changed'),
    ('sm_accountant', 'alert.receive.photo_reused'),
    ('sm_accountant', 'alert.receive.price_spike'),
    ('sm_accountant', 'alert.receive.service_contract_renewal'),
    ('sm_accountant', 'alert.receive.service_unaccepted_payment'),
    ('sm_accountant', 'alert.receive.sod_exception_used'),
    ('sm_accountant', 'alert.receive.temp_item_stale'),
    ('sm_accountant', 'alert.receive.unlock'),
    ('sm_accountant', 'alert.receive.waste_large'),
    ('sm_accountant', 'ap.view'),
    ('sm_accountant', 'attachment.upload'),
    ('sm_accountant', 'attachment.view'),
    ('sm_accountant', 'count.lock'),
    ('sm_accountant', 'day.lock'),
    ('sm_accountant', 'export.accounting'),
    ('sm_accountant', 'invoice.manage'),
    ('sm_accountant', 'item.import'),
    ('sm_accountant', 'item.manage'),
    ('sm_accountant', 'item.view'),
    ('sm_accountant', 'payment.mark_paid'),
    ('sm_accountant', 'payment.request'),
    ('sm_accountant', 'period.close'),
    ('sm_accountant', 'period.reopen'),
    ('sm_accountant', 'pms.input'),
    ('sm_accountant', 'pos.import'),
    ('sm_accountant', 'price.ceiling.manage'),
    ('sm_accountant', 'price.view'),
    ('sm_accountant', 'receiving.view'),
    ('sm_accountant', 'report.view.rpt_ap_aging'),
    ('sm_accountant', 'report.view.rpt_opex'),
    ('sm_accountant', 'supplier.approve'),
    ('sm_accountant', 'supplier.bank.approve'),
    ('sm_accountant', 'supplier.view'),
    ('sm_purchasing_store', 'advance.request'),
    ('sm_purchasing_store', 'attachment.upload'),
    ('sm_purchasing_store', 'attachment.view'),
    ('sm_purchasing_store', 'count.open'),
    ('sm_purchasing_store', 'count.perform'),
    ('sm_purchasing_store', 'item.manage'),
    ('sm_purchasing_store', 'item.temp.create'),
    ('sm_purchasing_store', 'item.view'),
    ('sm_purchasing_store', 'market.order.create'),
    ('sm_purchasing_store', 'po.close'),
    ('sm_purchasing_store', 'po.create'),
    ('sm_purchasing_store', 'po.view'),
    ('sm_purchasing_store', 'po.view_price'),
    ('sm_purchasing_store', 'po.view_qty'),
    ('sm_purchasing_store', 'pr.create'),
    ('sm_purchasing_store', 'price.agreement.manage'),
    ('sm_purchasing_store', 'price.view'),
    ('sm_purchasing_store', 'purpose_issue.post'),
    ('sm_purchasing_store', 'receiving.view'),
    ('sm_purchasing_store', 'requisition.issue'),
    ('sm_purchasing_store', 'stock.view_qty'),
    ('sm_purchasing_store', 'supplier.bank.request'),
    ('sm_purchasing_store', 'supplier.manage'),
    ('sm_purchasing_store', 'supplier.view'),
    ('sm_purchasing_store', 'supplier_return.post'),
    ('sm_purchasing_store', 'transfer.receive'),
    ('sm_purchasing_store', 'transfer.send'),
    ('sm_purchasing_store', 'warehouse.manage'),
    ('sm_kitchen', 'attachment.upload'),
    ('sm_kitchen', 'attachment.view'),
    ('sm_kitchen', 'count.perform'),
    ('sm_kitchen', 'item.view'),
    ('sm_kitchen', 'pr.approve'),
    ('sm_kitchen', 'pr.create'),
    ('sm_kitchen', 'purpose_issue.post'),
    ('sm_kitchen', 'receiving.view'),
    ('sm_kitchen', 'requisition.approve'),
    ('sm_kitchen', 'requisition.create'),
    ('sm_kitchen', 'requisition.receive'),
    ('sm_kitchen', 'restaurant.banquet.manage'),
    ('sm_kitchen', 'restaurant.buffet.manage'),
    ('sm_kitchen', 'restaurant.dish.manage'),
    ('sm_kitchen', 'restaurant.sale.record'),
    ('sm_kitchen', 'restaurant.view'),
    ('sm_kitchen', 'stock.view_qty'),
    ('sm_kitchen', 'waste.propose'),
    ('sm_housekeeping', 'alert.receive.minibar_check_requested'),
    ('sm_housekeeping', 'attachment.upload'),
    ('sm_housekeeping', 'attachment.view'),
    ('sm_housekeeping', 'hk.standard.manage'),
    ('sm_housekeeping', 'hk.trolley.operate'),
    ('sm_housekeeping', 'item.view'),
    ('sm_housekeeping', 'minibar.check'),
    ('sm_housekeeping', 'minibar.price.manage'),
    ('sm_housekeeping', 'minibar.refill'),
    ('sm_housekeeping', 'requisition.approve'),
    ('sm_housekeeping', 'requisition.create'),
    ('sm_housekeeping', 'requisition.issue'),
    ('sm_housekeeping', 'requisition.receive'),
    ('sm_housekeeping', 'room.manage'),
    ('sm_housekeeping', 'waste.propose'),
    ('sm_frontdesk', 'attachment.upload'),
    ('sm_frontdesk', 'attachment.view'),
    ('sm_frontdesk', 'item.view'),
    ('sm_frontdesk', 'minibar.charge.confirm'),
    ('sm_frontdesk', 'minibar.request_check'),
    ('sm_frontdesk', 'minibar.waive.request'),
    ('sm_frontdesk', 'pms.input'),
    ('sm_frontdesk', 'restaurant.banquet.manage'),
    ('sm_frontdesk', 'restaurant.sale.record'),
    ('sm_frontdesk', 'restaurant.view'),
    ('sm_frontdesk', 'stock.view_qty')
  ) as rp(role_code, permission_code) on rp.role_code = ro.code
  where ro.org_id = p_org_id
  on conflict (role_id, permission_code) do nothing;

  select count(*) into v_n from public.roles
  where org_id = p_org_id and code like 'sm\_%';
  return v_n;
end;
$$;


do $$
declare
  r record;
begin
  for r in select id from public.organizations loop
    perform public.seed_compact_roles(r.id);
  end loop;
end $$;
