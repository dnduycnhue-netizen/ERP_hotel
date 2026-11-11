-- C5: Tạo tổ chức / pháp nhân / khách sạn qua giao diện quản trị
-- (audit 10/11/2026 §2.2: trước đây 0 route, mở chuỗi thứ 2 phải chạy SQL tay).
--
-- 1. Mã quyền mới `admin.org.manage` (module 'Quản trị', mức critical) +
--    gán cho vai trò sys_admin / owner hệ thống của các tổ chức đã có.
-- 2. RPC `admin_org_create(p_org jsonb)`: trong 1 giao dịch tạo
--    organization -> legal_entity -> property, rồi seed vai trò mẫu hệ
--    thống của tổ chức mới (sys_admin, owner + 15 vai trò mẫu của migration
--    go-live 20261109140000, kèm đúng ma trận quyền mặc định của migration
--    đó) và gán người tạo làm sys_admin + owner toàn chuỗi của tổ chức mới
--    (theo đúng mẫu bootstrap_initial_org / manual-admin-setup.sql — nếu
--    không gán, người tạo không thấy được property mới qua RLS vì vai trò
--    quản trị cũ thuộc tổ chức cũ).
--    KHÔNG seed kho / outlet / cost center / nhóm hàng: đó là các bước tiếp
--    theo hiển thị trên giao diện sau khi tạo xong.
-- 3. RLS: không bảng mới nên không cần policy mới. Audit: trigger audit có
--    sẵn trên organizations / legal_entities / properties / roles /
--    role_permissions / user_property_roles ghi actor = auth.uid(); RPC ghi
--    thêm 1 dòng sự kiện admin_org_create vào audit_log.
-- Chỉ chạy bằng db push; KHÔNG chạy lên production trong task này.

insert into public.permissions (code, module, name_vi, description_vi, risk_level, sort_order)
values (
  'admin.org.manage', 'Quản trị', 'Quản lý tổ chức',
  'Tạo tổ chức, pháp nhân và khách sạn mới.', 'critical', 70
)
on conflict (code) do nothing;

insert into public.role_permissions (role_id, permission_code)
select r.id, 'admin.org.manage'
from public.roles r
where r.is_system
  and r.code in ('sys_admin', 'owner')
on conflict (role_id, permission_code) do nothing;

create or replace function public.admin_org_create(p_org jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_name text := btrim(coalesce(p_org ->> 'org_name', ''));
  v_legal_code text := upper(btrim(coalesce(p_org ->> 'legal_code', '')));
  v_legal_name text := btrim(coalesce(p_org ->> 'legal_name', ''));
  v_tax_code text := nullif(btrim(coalesce(p_org ->> 'tax_code', '')), '');
  v_accounting_regime text := coalesce(nullif(btrim(p_org ->> 'accounting_regime'), ''), 'TT99');
  v_costing_method text := coalesce(nullif(btrim(p_org ->> 'costing_method'), ''), 'moving_avg');
  v_property_code text := upper(btrim(coalesce(p_org ->> 'property_code', '')));
  v_property_name text := btrim(coalesce(p_org ->> 'property_name', ''));
  v_address text := nullif(btrim(coalesce(p_org ->> 'address', '')), '');
  v_sod_profile text := coalesce(nullif(btrim(p_org ->> 'sod_profile'), ''), 'with_cc');
  v_rooms_raw text := coalesce(nullif(btrim(p_org ->> 'rooms_count'), ''), '0');
  v_rooms_count integer := 0;
  v_org_id uuid;
  v_legal_id uuid;
  v_property_id uuid;
  v_sys_admin_role_id uuid;
  v_owner_role_id uuid;
begin
  -- Chỉ quản trị chuỗi (người giữ admin.org.manage toàn chuỗi, tức
  -- sys_admin / owner) mới được mở tổ chức mới.
  perform public.require_perm(null, 'admin.org.manage');

  if v_org_name = ''
    or v_legal_code = ''
    or v_legal_name = ''
    or v_property_code = ''
    or v_property_name = '' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if v_legal_code !~ '^[A-Z0-9_-]{2,20}$'
    or v_property_code !~ '^[A-Z0-9_-]{2,20}$' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if v_accounting_regime not in ('TT99', 'TT133') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if v_costing_method not in ('moving_avg', 'fifo') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if v_sod_profile not in ('with_cc', 'without_cc') then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if v_rooms_raw !~ '^[0-9]+$' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  v_rooms_count := v_rooms_raw::integer;
  if v_rooms_count < 0 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform pg_advisory_xact_lock(hashtext('admin_org_create'));

  insert into public.organizations (name, created_by)
  values (v_org_name, auth.uid())
  returning id into v_org_id;

  insert into public.legal_entities (
    org_id, code, name, tax_code, accounting_regime, costing_method, created_by
  )
  values (
    v_org_id, v_legal_code, v_legal_name, v_tax_code,
    v_accounting_regime, v_costing_method, auth.uid()
  )
  returning id into v_legal_id;

  insert into public.properties (
    org_id, legal_entity_id, code, name, address, sod_profile, rooms_count, created_by
  )
  values (
    v_org_id, v_legal_id, v_property_code, v_property_name, v_address,
    v_sod_profile, v_rooms_count, auth.uid()
  )
  returning id into v_property_id;

  -- Vai trò mẫu hệ thống của tổ chức mới: sys_admin + owner (mẫu
  -- bootstrap) + 15 vai trò mẫu của migration go-live 20261109140000.
  insert into public.roles (org_id, code, name_vi, description, is_system, created_by)
  select v_org_id, r.code, r.name_vi, r.description, true, auth.uid()
  from (
    values
      ('sys_admin', 'Quản trị hệ thống',
       'Quản trị người dùng và quyền; không có quyền nghiệp vụ tiền hoặc kho.'),
      ('owner', 'Chủ đầu tư',
       'Full quyền: mọi permission trên toàn chuỗi (tài khoản chủ sở hữu).'),
      ('gm', 'Tổng quản lý', 'Điều hành và duyệt toàn diện tại khách sạn.'),
      ('chief_accountant', 'Kế toán trưởng chuỗi', 'Kiểm soát kế toán, kỳ và giá trần.'),
      ('accountant', 'Kế toán khách sạn', 'Hóa đơn, công nợ, tạm ứng, khóa sổ ngày.'),
      ('cost_controller', 'Cost Controller', 'Kiểm soát giá vốn, hậu kiểm nhận hàng và tồn kho.'),
      ('purchaser', 'Thu mua', 'Tạo và quản lý đơn đặt hàng, tìm nguồn cung ứng.'),
      ('storekeeper', 'Thủ kho', 'Nhận hàng, xuất kho, kiểm kê và quản lý kho.'),
      ('receiver', 'Nhận hàng ca sáng', 'Nhận hàng mù không xem số lượng PO và giá.'),
      ('outlet_head', 'Trưởng bộ phận', 'Lập phiếu yêu cầu và xác nhận lĩnh hàng.'),
      ('chef', 'Bếp trưởng / Bếp', 'Quản lý bếp, định mức và kiểm kê thực phẩm.'),
      ('bartender', 'Bartender', 'Quản lý quầy bar và kiểm kê đồ uống.'),
      ('hk_supervisor', 'Giám sát buồng', 'Quản lý buồng phòng, xe đẩy và đồ vải.'),
      ('hk_attendant', 'Nhân viên buồng', 'Kiểm minibar và vận hành xe đẩy phòng.'),
      ('front_desk', 'Lễ tân', 'Thu tiền minibar và tiếp nhận thông tin khách.'),
      ('engineer', 'Kỹ thuật', 'Lĩnh vật tư bảo trì và nghiệm thu dịch vụ.'),
      ('internal_audit', 'Kiểm soát nội bộ', 'Xem báo cáo và nhật ký kiểm toán toàn chuỗi.')
  ) as r(code, name_vi, description);

  select id into v_sys_admin_role_id
  from public.roles r
  where r.org_id = v_org_id and r.code = 'sys_admin';

  select id into v_owner_role_id
  from public.roles r
  where r.org_id = v_org_id and r.code = 'owner';

  -- sys_admin: mọi quyền module 'Quản trị' (gồm admin.org.manage mới).
  insert into public.role_permissions (role_id, permission_code)
  select v_sys_admin_role_id, p.code
  from public.permissions p
  where p.module = 'Quản trị'
  on conflict (role_id, permission_code) do nothing;

  -- owner: mọi quyền.
  insert into public.role_permissions (role_id, permission_code)
  select v_owner_role_id, p.code
  from public.permissions p
  on conflict (role_id, permission_code) do nothing;

  -- 15 vai trò mẫu: ma trận quyền mặc định của migration go-live
  -- 20261109140000 (sao chép nguyên văn; dòng owner trùng với seed ở
  -- trên nên on conflict bỏ qua).
  insert into public.role_permissions (role_id, permission_code)
  select r.id, rp.permission_code
  from public.roles r
  join (
    values
      ('owner', 'report.view.rpt_stock_card'),
      ('owner', 'report.view.rpt_receiving_quality'),
      ('owner', 'report.view.rpt_open_po_invoice'),
      ('owner', 'report.view.rpt_ap_aging'),
      ('owner', 'report.view.rpt_advances'),
      ('owner', 'report.view.rpt_waste'),
      ('owner', 'report.view.rpt_opex'),
      ('owner', 'report.view.rpt_minibar'),
      ('owner', 'report.view.rpt_amenity_cpor'),
      ('owner', 'report.view.rpt_daily_brief'),
      ('owner', 'report.daily_brief.receive'),
      ('owner', 'po.approve'),
      ('owner', 'audit.view_all'),
      ('gm', 'report.view.rpt_stock_card'),
      ('gm', 'report.view.rpt_receiving_quality'),
      ('gm', 'report.view.rpt_open_po_invoice'),
      ('gm', 'report.view.rpt_ap_aging'),
      ('gm', 'report.view.rpt_advances'),
      ('gm', 'report.view.rpt_waste'),
      ('gm', 'report.view.rpt_opex'),
      ('gm', 'report.view.rpt_minibar'),
      ('gm', 'report.view.rpt_amenity_cpor'),
      ('gm', 'report.view.rpt_daily_brief'),
      ('gm', 'report.daily_brief.receive'),
      ('gm', 'po.approve'),
      ('gm', 'po.approve.over_ceiling'),
      ('gm', 'waste.approve.large'),
      ('gm', 'count.adjust.approve'),
      ('gm', 'day.unlock'),
      ('gm', 'minibar.waive.approve'),
      ('gm', 'advance.approve'),
      ('chief_accountant', 'invoice.approve'),
      ('chief_accountant', 'payment.approve'),
      ('chief_accountant', 'period.close'),
      ('chief_accountant', 'period.reopen'),
      ('chief_accountant', 'price.ceiling.manage'),
      ('chief_accountant', 'item.view'),
      ('chief_accountant', 'supplier.bank.approve'),
      ('chief_accountant', 'export.accounting'),
      ('chief_accountant', 'report.view.rpt_ap_aging'),
      ('chief_accountant', 'report.view.rpt_opex'),
      ('accountant', 'invoice.manage'),
      ('accountant', 'item.view'),
      ('accountant', 'ap.view'),
      ('accountant', 'advance.disburse'),
      ('accountant', 'advance.settle'),
      ('accountant', 'payment.request'),
      ('accountant', 'payment.mark_paid'),
      ('accountant', 'day.lock'),
      ('accountant', 'count.lock'),
      ('accountant', 'pms.input'),
      ('cost_controller', 'price.ceiling.manage'),
      ('cost_controller', 'item.view'),
      ('cost_controller', 'receiving.review_photos'),
      ('cost_controller', 'count.view_variance'),
      ('cost_controller', 'waste.approve'),
      ('cost_controller', 'item.temp.normalize'),
      ('cost_controller', 'po.approve'),
      ('purchaser', 'pr.create'),
      ('purchaser', 'item.view'),
      ('purchaser', 'po.create'),
      ('purchaser', 'po.view'),
      ('purchaser', 'po.view_qty'),
      ('purchaser', 'po.view_price'),
      ('purchaser', 'market.order.create'),
      ('purchaser', 'supplier.view'),
      ('purchaser', 'supplier.manage'),
      ('purchaser', 'supplier.bank.request'),
      ('purchaser', 'advance.request'),
      ('purchaser', 'item.temp.create'),
      ('storekeeper', 'receiving.perform'),
      ('storekeeper', 'receiving.post'),
      ('storekeeper', 'receiving.view'),
      ('storekeeper', 'requisition.issue'),
      ('storekeeper', 'transfer.send'),
      ('storekeeper', 'transfer.receive'),
      ('storekeeper', 'stock.view_qty'),
      ('storekeeper', 'count.open'),
      ('storekeeper', 'count.perform'),
      ('storekeeper', 'supplier_return.post'),
      ('storekeeper', 'item.temp.create'),
      ('storekeeper', 'item.view'),
      ('receiver', 'receiving.perform'),
      ('receiver', 'receiving.post'),
      ('receiver', 'item.view'),
      ('outlet_head', 'pr.create'),
      ('outlet_head', 'pr.approve'),
      ('outlet_head', 'requisition.create'),
      ('outlet_head', 'requisition.approve'),
      ('outlet_head', 'requisition.receive'),
      ('outlet_head', 'waste.propose'),
      ('outlet_head', 'item.view'),
      ('chef', 'pr.create'),
      ('chef', 'pr.approve'),
      ('chef', 'requisition.create'),
      ('chef', 'requisition.approve'),
      ('chef', 'requisition.receive'),
      ('chef', 'waste.propose'),
      ('chef', 'count.perform'),
      ('chef', 'item.view'),
      ('bartender', 'count.perform'),
      ('bartender', 'item.view'),
      ('hk_supervisor', 'hk.standard.manage'),
      ('hk_supervisor', 'hk.trolley.operate'),
      ('hk_supervisor', 'minibar.refill'),
      ('hk_supervisor', 'requisition.create'),
      ('hk_supervisor', 'requisition.approve'),
      ('hk_supervisor', 'requisition.issue'),
      ('hk_supervisor', 'requisition.receive'),
      ('hk_supervisor', 'waste.propose'),
      ('hk_supervisor', 'item.view'),
      ('hk_attendant', 'hk.trolley.operate'),
      ('hk_attendant', 'minibar.check'),
      ('hk_attendant', 'item.view'),
      ('front_desk', 'minibar.request_check'),
      ('front_desk', 'minibar.charge.confirm'),
      ('front_desk', 'minibar.waive.request'),
      ('front_desk', 'pms.input'),
      ('engineer', 'requisition.create'),
      ('engineer', 'service.accept'),
      ('internal_audit', 'audit.view_all'),
      ('internal_audit', 'report.view.rpt_stock_card'),
      ('internal_audit', 'report.view.rpt_receiving_quality'),
      ('internal_audit', 'report.view.rpt_open_po_invoice'),
      ('internal_audit', 'report.view.rpt_ap_aging'),
      ('internal_audit', 'report.view.rpt_advances'),
      ('internal_audit', 'report.view.rpt_waste'),
      ('internal_audit', 'report.view.rpt_opex'),
      ('internal_audit', 'report.view.rpt_minibar'),
      ('internal_audit', 'report.view.rpt_amenity_cpor'),
      ('internal_audit', 'report.view.rpt_daily_brief')
  ) as rp(role_code, permission_code)
    on r.code = rp.role_code
  where r.org_id = v_org_id
    and r.is_system = true
  on conflict (role_id, permission_code) do nothing;

  -- Người tạo thành quản trị chuỗi của tổ chức mới (cả sys_admin lẫn
  -- owner, phạm vi toàn chuỗi) để thấy và quản trị được khách sạn mới.
  insert into public.user_property_roles (user_id, role_id, property_id, granted_by)
  values
    (auth.uid(), v_sys_admin_role_id, null, auth.uid()),
    (auth.uid(), v_owner_role_id, null, auth.uid());

  insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
  values (
    'organizations',
    v_org_id::text,
    'INSERT',
    jsonb_build_object(
      'event', 'admin_org_create',
      'legal_entity_id', v_legal_id,
      'property_id', v_property_id
    ),
    auth.uid(),
    jsonb_build_object('source', 'admin_org_create')
  );

  return jsonb_build_object(
    'ok', true,
    'org_id', v_org_id,
    'legal_entity_id', v_legal_id,
    'property_id', v_property_id
  );
exception
  when unique_violation then
    raise exception using errcode = 'P0001', message = 'ERR_DUPLICATE_CODE';
end;
$$;

revoke all on function public.admin_org_create(jsonb) from public, anon;
grant execute on function public.admin_org_create(jsonb) to authenticated;
