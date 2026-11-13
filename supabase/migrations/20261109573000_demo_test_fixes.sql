-- ============================================================================
-- Q267 — 20261109573000_demo_test_fixes
--   Sua cac loi do Muse tim ra khi test chu trinh demo (docs/go-live/muse-report-demo-test.md):
--   (1) po_save_draft: PO cho (channel market) co dong chi co mo ta (khong co ma hang)
--       bi ERR_INVALID_VALUE ngay ca khi luu nguyen ven -> khong sua/gui duyet duoc.
--       Chi con chan dong khong co hang khi PO kind=stock VA khong phai kenh cho.
--   (2) Ke toan khong mo duoc form nhap hoa don vi thieu quyen xem don mua (po_list/po_get
--       can po.view...): them po.view, po.view_price, po.view_qty cho accountant,
--       chief_accountant, sm_accountant (accountant cu them supplier.view de thay danh sach NCC); Quan ly (sm_manager, nguoi duyet moi PO) them
--       po.view, po.view_price, po.view_qty; Chu dau tu them po.view_qty. Cac vai tro nay
--       khong co quyen nhan hang nen khong pha nhan hang mu.
--   (Muse #6 "mo lai PO tao them phieu nhap": KHONG sua — moi nguoi nhan co phieu nhap rieng, receiving_test
--   dua vao hanh vi nay; phieu nhap rong vo hai.)
--   Sinh lai nguyen van tu ban dang chay tren production, chi doi dung cac cho tren.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.po_save_draft(p_property_id uuid, p_po jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'auth', 'pg_temp'
AS $function$
declare
  v_org_id uuid;
  v_po public.purchase_orders%rowtype;
  v_po_id uuid;
  v_line jsonb;
  v_line_id uuid;
  v_old public.purchase_order_lines%rowtype;
  v_item_id uuid;
  v_qty numeric(18,4);
  v_uom text;
  v_unit_price numeric(18,4);
  v_price_source text;
  v_ceiling_price numeric(18,4);
  v_over_ceiling boolean;
  v_qty_stock numeric(18,4);
  v_total numeric(18,2);
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  perform public.require_perm(p_property_id, 'po.create');

  v_po_id := nullif(p_po ->> 'id', '')::uuid;
  if v_po_id is null then
    raise exception 'ERR_INVALID_STATUS';
  end if;

  select * into v_po
  from public.purchase_orders po where po.id = v_po_id;
  if not found or v_po.property_id <> p_property_id then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if v_po.status not in ('draft', 'rejected') then
    raise exception 'ERR_INVALID_STATUS';
  end if;
  if jsonb_typeof(coalesce(p_po -> 'lines', '[]'::jsonb)) <> 'array' then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_org_id := v_po.org_id;

  perform set_config('app.pr_po_guard_bypass', 'on', true);

  update public.purchase_orders po
  set expected_date = case
      when p_po ? 'expected_date'
      then nullif(p_po ->> 'expected_date', '')::date
      else po.expected_date end,
    over_ceiling_reason = case
      when p_po ? 'over_ceiling_reason'
      then nullif(p_po ->> 'over_ceiling_reason', '')
      else po.over_ceiling_reason end,
    status = 'draft'
  where po.id = v_po_id;

  if v_po.status = 'rejected' then
    delete from public.approvals
    where doc_type = 'po' and doc_id = v_po_id;
  end if;

  -- Dong bi xoa khoi payload: tra lai so luong da chuyen cho dong PR.
  for v_old in
    select * from public.purchase_order_lines pol
    where pol.po_id = v_po_id
      and not exists (
        select 1
        from jsonb_array_elements(coalesce(p_po -> 'lines', '[]'::jsonb)) l
        where nullif(l ->> 'id', '')::uuid = pol.id
      )
  loop
    if v_old.pr_line_id is not null then
      update public.purchase_request_lines
      set converted_qty = converted_qty - v_old.qty
      where id = v_old.pr_line_id;
      update public.purchase_requests pr
      set status = 'approved'
      where pr.id = (
        select prl.pr_id from public.purchase_request_lines prl
        where prl.id = v_old.pr_line_id
      )
      and pr.status = 'converted';
    end if;
    delete from public.purchase_order_lines where id = v_old.id;
  end loop;

  for v_line in
    select * from jsonb_array_elements(coalesce(p_po -> 'lines', '[]'::jsonb))
  loop
    v_line_id := nullif(v_line ->> 'id', '')::uuid;
    v_item_id := nullif(v_line ->> 'item_id', '')::uuid;
    v_qty := (v_line ->> 'qty')::numeric(18,4);
    v_uom := v_line ->> 'uom';

    if v_qty is null or v_qty <= 0 then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if v_uom is null or not exists (
      select 1 from public.uoms u where u.code = v_uom
    ) then
      raise exception 'ERR_UOM_UNKNOWN';
    end if;
    if v_item_id is not null and not exists (
      select 1 from public.items i
      where i.id = v_item_id and i.org_id = v_org_id and i.status = 'active'
    ) then
      raise exception 'ERR_INVALID_STATUS';
    end if;
    if v_item_id is null
      and (v_line ->> 'description' is null or btrim(v_line ->> 'description') = '')
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    -- Q267: PO cho (channel market) duoc phep dong chi co mo ta (chua biet mat hang).
    if v_po.kind = 'stock' and v_po.channel <> 'market' and v_item_id is null then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if nullif(v_line ->> 'expense_category_id', '')::uuid is not null
      and not exists (
        select 1 from public.expense_categories ec
        where ec.id = nullif(v_line ->> 'expense_category_id', '')::uuid
          and ec.org_id = v_org_id
      )
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;
    if nullif(v_line ->> 'cost_center_id', '')::uuid is not null
      and not exists (
        select 1 from public.cost_centers cc
        where cc.id = nullif(v_line ->> 'cost_center_id', '')::uuid
          and cc.org_id = v_org_id
      )
    then
      raise exception 'ERR_INVALID_VALUE';
    end if;

    if v_line_id is not null then
      select * into v_old
      from public.purchase_order_lines pol where pol.id = v_line_id;
      if not found or v_old.po_id <> v_po_id then
        raise exception 'ERR_INVALID_STATUS';
      end if;
      if v_old.pr_line_id is not null then
        -- Dong gan PR: chi cho luu lai nguyen ven (khong sua); muon doi
        -- thi xoa dong khoi payload roi tao lai bang po_create_from_pr.
        -- Ngoai le (Q224): dong gia tay (price_source = 'manual') duoc
        -- sua unit_price — neu khong thi dong manual khong bao gio co
        -- gia (resolver tra 0 khi khong co hop dong/tran) va po_submit
        -- luon nem ERR_PRICE_NOT_SET: luong gia tay chet hoan toan.
        -- Gia hop dong/tran van cam sua (giua nguyen §21).
        if v_old.item_id is distinct from v_item_id
          or v_old.uom <> v_uom
          or v_old.qty <> v_qty
          or (v_line ? 'unit_price'
            and (v_line ->> 'unit_price')::numeric(18,4) <> v_old.unit_price
            and v_old.price_source <> 'manual')
          or (v_line ? 'expense_category_id'
            and nullif(v_line ->> 'expense_category_id', '')::uuid
              is distinct from v_old.expense_category_id)
          or (v_line ? 'cost_center_id'
            and nullif(v_line ->> 'cost_center_id', '')::uuid
              is distinct from v_old.cost_center_id)
        then
          raise exception 'ERR_INVALID_STATUS';
        end if;
        if v_old.price_source = 'manual' and (v_line ? 'unit_price') then
          update public.purchase_order_lines pol
          set unit_price = (v_line ->> 'unit_price')::numeric(18,4),
              over_ceiling = (pol.ceiling_price is not null
                and (v_line ->> 'unit_price')::numeric(18,4) > pol.ceiling_price)
          where pol.id = v_line_id;
        end if;
        continue;
      end if;
      if v_old.item_id is distinct from v_item_id
        or v_old.uom <> v_uom
      then
        -- Doi item/uom: xoa dong cu khoi payload, them dong moi.
        raise exception 'ERR_INVALID_STATUS';
      end if;

      v_qty_stock := public._po_line_qty_stock(v_org_id, v_item_id, v_uom, v_qty);

      update public.purchase_order_lines pol
      set qty = v_qty,
          qty_stock = v_qty_stock,
          unit_price = case
            when pol.price_source = 'manual'
              and v_line ? 'unit_price'
            then (v_line ->> 'unit_price')::numeric(18,4)
            else pol.unit_price end,
          over_ceiling = case
            when pol.price_source = 'manual'
              and v_line ? 'unit_price'
            then (pol.ceiling_price is not null
              and (v_line ->> 'unit_price')::numeric(18,4) > pol.ceiling_price)
            else pol.over_ceiling end,
          expense_category_id = case
            when v_line ? 'expense_category_id'
            then nullif(v_line ->> 'expense_category_id', '')::uuid
            else pol.expense_category_id end,
          cost_center_id = case
            when v_line ? 'cost_center_id'
            then nullif(v_line ->> 'cost_center_id', '')::uuid
            else pol.cost_center_id end
      where pol.id = v_line_id
        and (
          pol.price_source = 'manual'
          or not (v_line ? 'unit_price')
          or (v_line ->> 'unit_price')::numeric(18,4) = pol.unit_price
        );
      if not found then
        raise exception 'ERR_INVALID_STATUS';
      end if;
    else
      if v_po.channel = 'market' and v_item_id is not null and not (
        select 'market' = any(i.allowed_channels)
        from public.items i where i.id = v_item_id
      ) then
        raise exception 'ERR_CHANNEL_NOT_ALLOWED';
      end if;

      select unit_price, price_source, ceiling_price, over_ceiling
        into v_unit_price, v_price_source, v_ceiling_price, v_over_ceiling
      from public._po_resolve_line_price(
        v_org_id, p_property_id, v_po.supplier_id,
        v_item_id, v_uom, v_today
      );
      -- Dong moi co gia tay gui kem thi dung gia do (chi khi manual).
      if v_price_source = 'manual' and (v_line ? 'unit_price') then
        v_unit_price := (v_line ->> 'unit_price')::numeric(18,4);
        v_over_ceiling := v_ceiling_price is not null
          and v_unit_price > v_ceiling_price;
      end if;

      v_qty_stock := public._po_line_qty_stock(v_org_id, v_item_id, v_uom, v_qty);

      insert into public.purchase_order_lines (
        po_id, org_id, pr_line_id, item_id, description, qty, uom,
        qty_stock, unit_price, price_source, ceiling_price, over_ceiling,
        expense_category_id, cost_center_id, created_by
      )
      values (
        v_po_id, v_org_id, null, v_item_id,
        nullif(v_line ->> 'description', ''),
        v_qty, v_uom, v_qty_stock,
        v_unit_price, v_price_source, v_ceiling_price,
        v_over_ceiling,
        nullif(v_line ->> 'expense_category_id', '')::uuid,
        nullif(v_line ->> 'cost_center_id', '')::uuid,
        auth.uid()
      );
    end if;
  end loop;

  select total_amount into v_total
  from public.purchase_orders where id = v_po_id;

  return jsonb_build_object(
    'ok', true,
    'id', v_po_id,
    'doc_no', v_po.doc_no,
    'status', 'draft',
    'total_amount', v_total
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
    ('sm_owner', 'po.view_qty'),
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
    ('sm_manager', 'po.view'),
    ('sm_manager', 'po.view_price'),
    ('sm_manager', 'po.view_qty'),
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
    ('sm_accountant', 'po.view'),
    ('sm_accountant', 'po.view_price'),
    ('sm_accountant', 'po.view_qty'),
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

insert into public.role_permissions (role_id, permission_code)
select r.id, p.code
from public.roles r
join (values
  ('accountant', 'po.view'), ('accountant', 'po.view_price'), ('accountant', 'po.view_qty'),
  ('accountant', 'supplier.view'),
  ('chief_accountant', 'po.view'), ('chief_accountant', 'po.view_price'), ('chief_accountant', 'po.view_qty'),
  ('sm_accountant', 'po.view'), ('sm_accountant', 'po.view_price'), ('sm_accountant', 'po.view_qty'),
  ('sm_manager', 'po.view'), ('sm_manager', 'po.view_price'), ('sm_manager', 'po.view_qty'),
  ('sm_owner', 'po.view_qty')
) as p(role_code, code) on p.role_code = r.code
on conflict (role_id, permission_code) do nothing;
