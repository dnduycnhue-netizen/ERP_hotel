-- ===========================================================================
-- C7 (completion wave 2) — RPC xoa tieu chuan setup phong.
--
-- LY DO CAN RPC MOI:
-- - `room_setup_standard_set` (upsert, 310000) da co, nhung KHONG co RPC
--   xoa; bang `room_setup_standards` chi co policy RLS SELECT-only (310000
--   §5, giong bang items — "ghi qua RPC") nen client khong DELETE truc
--   tiep duoc.
-- - RPC toi thieu nay chi xoa 1 dong theo id, kiem `hk.standard.manage`
--   tren property cua dong do (mau `admin_alert_rule_delete`).
-- - Khong sua bang cu, khong them ma quyen moi, khong doi seed.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. RPC xoa tieu chuan setup phong theo id.
-- ---------------------------------------------------------------------------
create or replace function public.room_setup_standard_delete(
  p_standard_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_std public.room_setup_standards%rowtype;
begin
  select * into v_std
  from public.room_setup_standards
  where id = p_standard_id
  for update;
  if not found then
    raise exception using errcode = 'P0001',
      message = 'ERR_INVALID_VALUE: tieu chuan setup khong ton tai';
  end if;

  perform public.require_perm(v_std.property_id, 'hk.standard.manage');

  delete from public.room_setup_standards where id = p_standard_id;
  return jsonb_build_object('ok', true, 'id', p_standard_id);
end;
$$;

revoke all on function public.room_setup_standard_delete(uuid)
  from public, anon, authenticated;
grant execute on function public.room_setup_standard_delete(uuid)
  to authenticated;
