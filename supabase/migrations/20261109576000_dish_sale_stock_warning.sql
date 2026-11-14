-- Q270 (14/11/2026): dish_sale_record canh bao khi NVL vuot ton (khong chan ban). B-31.
create or replace function public.dish_sale_record(
  p_property_id uuid, p_business_date date,
  p_recipe_id uuid, p_qty numeric, p_unit_price numeric
)
returns jsonb
language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_org_id uuid;
  v_legal_entity_id uuid;
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_sale_id uuid;
  v_amount numeric;
  v_auto jsonb;
  v_recipe_name text;
  v_short integer := 0;
  v_note text;
begin
  perform public.require_perm(p_property_id, 'restaurant.sale.record');

  select org_id, legal_entity_id into v_org_id, v_legal_entity_id
  from public.properties where id = p_property_id;
  if v_org_id is null then raise exception 'ERR_INVALID_VALUE'; end if;

  if p_business_date is null or p_business_date > v_today then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if p_qty is null or p_qty <= 0
    or p_unit_price is null or p_unit_price < 0 then
    raise exception 'ERR_INVALID_VALUE';
  end if;
  if not exists (select 1 from public.recipes
    where id = p_recipe_id and org_id = v_org_id and is_active) then
    raise exception 'ERR_INVALID_VALUE';
  end if;

  v_amount := round(p_qty * p_unit_price, 2);

  perform set_config('app.restaurant_guard_bypass', 'on', true);

  insert into public.dish_sales
    (org_id, legal_entity_id, property_id, business_date,
     recipe_id, source, ref_id, qty, unit_price, amount)
  values
    (v_org_id, v_legal_entity_id, p_property_id, p_business_date,
     p_recipe_id, 'manual', null, p_qty, p_unit_price, v_amount)
  returning id into v_sale_id;

  -- C11 (Q169): tu sinh phieu linh NHAP cho NVL cua mon vua ban
  -- (best-effort, nhu banquet_confirm).
  select name into v_recipe_name from public.recipes where id = p_recipe_id;
  begin
    v_auto := public._restaurant_auto_requisition(
      p_property_id, p_business_date,
      'Tự động từ bán món ' || coalesce(v_recipe_name, p_recipe_id::text),
      jsonb_build_array(jsonb_build_object(
        'recipe_id', p_recipe_id, 'servings', p_qty)));
  exception when others then
    v_auto := jsonb_build_object(
      'requisition_id', null,
      'note', 'Không tạo được phiếu lĩnh tự động: ' || sqlerrm);
  end;

  -- Q270 (B-31): ban hang KHONG bi chan khi thieu ton (khach da duoc phuc vu),
  -- nhung canh bao neu NVL cua phieu linh tu sinh vuot ton (kho bep + kho chinh).
  v_note := v_auto ->> 'note';
  if (v_auto ->> 'requisition_id') is not null then
    select count(*) into v_short
    from public.requisition_lines rl
    join public.requisitions rq on rq.id = rl.requisition_id
    where rl.requisition_id = (v_auto ->> 'requisition_id')::uuid
      and rl.qty_stock > coalesce((
        select sum(sb.qty) from public.stock_balances sb
        where sb.item_id = rl.item_id
          and sb.warehouse_id in (rq.from_warehouse_id, rq.to_warehouse_id)
      ), 0);
    if v_short > 0 then
      v_note := coalesce(v_note, '') || ' CẢNH BÁO: ' || v_short
        || ' nguyên liệu của món này chưa đủ tồn trong kho bếp + kho chính.';
    end if;
  end if;

  return jsonb_build_object(
    'ok', true, 'id', v_sale_id, 'amount', v_amount,
    'requisition_id', v_auto ->> 'requisition_id',
    'requisition_note', v_note, 'stock_short_lines', v_short
  );
end;
$$;
