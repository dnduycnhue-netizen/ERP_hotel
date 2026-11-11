-- Q209 (11/11/2026): doi ten phap nhan tu trang chi tiet to chuc.
-- Duy quyet dinh 11/11: ten phap nhan that se dien trong setting sau, nhung
-- trang /admin/organizations/[id] hien chi xem (khong co form sua) va chua
-- co RPC update nao, nen hanh dong do hien khong the lam duoc.
-- RPC nay chi doi legal_entities.name (khong doi code/org_id/tax_code/
-- accounting_regime/costing_method), theo dung mau admin_org_create
-- (migration 20261109524000): require_perm chain admin.org.manage,
-- validate ERR_INVALID_VALUE, ghi audit_log.
create or replace function public.admin_legal_entity_update(
  p_legal_entity_id uuid,
  p_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_old_name text;
begin
  -- Chi quan tri chuoi (nguoi giu admin.org.manage toan chuoi, tuc
  -- sys_admin / owner) moi duoc doi ten phap nhan.
  perform public.require_perm(null, 'admin.org.manage');

  if v_name = '' then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;
  if char_length(v_name) > 200 then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  select name into v_old_name
  from public.legal_entities
  where id = p_legal_entity_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'ERR_INVALID_VALUE';
  end if;

  update public.legal_entities
  set name = v_name
  where id = p_legal_entity_id;

  insert into public.audit_log (table_name, row_id, action, new_data, actor, client_info)
  values (
    'legal_entities',
    p_legal_entity_id::text,
    'UPDATE',
    jsonb_build_object(
      'event', 'admin_legal_entity_update',
      'old_name', v_old_name,
      'new_name', v_name
    ),
    auth.uid(),
    jsonb_build_object('source', 'admin_legal_entity_update')
  );

  return jsonb_build_object('ok', true, 'id', p_legal_entity_id);
end;
$$;

revoke all on function public.admin_legal_entity_update(uuid, text) from public, anon;
grant execute on function public.admin_legal_entity_update(uuid, text) to authenticated;
