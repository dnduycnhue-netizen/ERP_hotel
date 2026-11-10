-- Q81: `service_accept` nhan them ghi chu (`p_note`) va luu vao cot
-- `note` cua `service_acceptances` (cot da co tu T-042, migration
-- 350000, nhung RPC cu khong co tham so nay nen form nghiem thu khong
-- co o ghi chu). Tham so moi la tuy chon (default null) nen moi loi
-- goi cu (4 tham so vi tri / PostgREST khong gui p_note) van chay.
--
-- CREATE OR REPLACE khong doi duoc danh sach tham so (se tao them 1
-- overload cu) nen DROP ham 4 tham so truoc roi CREATE lai ham 5 tham
-- so. Khong doi hanh vi khac: quyen, SoD, trang thai, unique
-- 1 ky / 1 PO 1 nghiem thu giu nguyen.
drop function if exists public.service_accept(uuid, integer, jsonb, uuid);

-- Nghiem thu ky hop dong HOAC PO dich vu le (D3/D4). Chi 1 trong 2 id
-- duoc truyen. rating tuy chon 1..5, photos la jsonb array (ids anh),
-- note la ghi chu tuy chon luu vao service_acceptances.note.
create function public.service_accept(
  p_schedule_id uuid default null,
  p_rating integer default null,
  p_photos jsonb default '[]'::jsonb,
  p_po_id uuid default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_sched record;
  v_contract record;
  v_po record;
  v_property uuid;
  v_acc_id uuid;
begin
  if (p_schedule_id is null) = (p_po_id is null) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if p_rating is not null and (p_rating < 1 or p_rating > 5) then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if p_photos is null then
    p_photos := '[]'::jsonb;
  end if;
  if jsonb_typeof(p_photos) <> 'array' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  perform set_config('app.service_guard_bypass', 'on', true);

  if p_schedule_id is not null then
    select * into v_sched from public.service_schedules
    where id = p_schedule_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    select * into v_contract from public.service_contracts
    where id = v_sched.contract_id;
    v_property := v_sched.property_id;

    perform public.require_perm(v_property, 'service.accept');
    if v_sched.status not in ('scheduled', 'performed') then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    if exists (
      select 1 from public.service_acceptances
      where schedule_id = p_schedule_id
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    -- SoD: nguoi tao hop dong khong duoc tu nghiem thu (D4).
    if v_contract.created_by = auth.uid() then
      perform public._sod_check(v_property, 'SOD_SERVICE_ACCEPTOR');
    end if;

    insert into public.service_acceptances (
      org_id, legal_entity_id, property_id, schedule_id,
      accepted_by, rating, note, photo_ids, created_by
    ) values (
      v_sched.org_id, v_sched.legal_entity_id, v_sched.property_id,
      p_schedule_id, auth.uid(), p_rating, p_note, p_photos, auth.uid()
    ) returning id into v_acc_id;

    update public.service_schedules
    set status = 'accepted', updated_at = now()
    where id = p_schedule_id;

    return jsonb_build_object(
      'ok', true, 'id', v_acc_id, 'schedule_id', p_schedule_id,
      'status', 'accepted', 'rating', p_rating
    );
  else
    select * into v_po from public.purchase_orders where id = p_po_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    if v_po.kind <> 'service' then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
    end if;
    v_property := v_po.property_id;

    perform public.require_perm(v_property, 'service.accept');
    if exists (
      select 1 from public.service_acceptances where po_id = p_po_id
    ) then
      raise exception using errcode = 'P0001', message = 'ERR_INVALID_STATUS';
    end if;
    -- SoD: nguoi tao PO khong duoc tu nghiem thu (D4).
    if v_po.created_by = auth.uid() then
      perform public._sod_check(v_property, 'SOD_SERVICE_ACCEPTOR');
    end if;

    insert into public.service_acceptances (
      org_id, legal_entity_id, property_id, po_id,
      accepted_by, rating, note, photo_ids, created_by
    ) values (
      v_po.org_id, v_po.legal_entity_id, v_po.property_id,
      p_po_id, auth.uid(), p_rating, p_note, p_photos, auth.uid()
    ) returning id into v_acc_id;

    return jsonb_build_object(
      'ok', true, 'id', v_acc_id, 'po_id', p_po_id,
      'status', 'accepted', 'rating', p_rating
    );
  end if;
end;
$$;

revoke all on function public.service_accept(uuid, integer, jsonb, uuid, text)
  from public, anon, authenticated;
grant execute on function public.service_accept(uuid, integer, jsonb, uuid, text)
  to authenticated;
