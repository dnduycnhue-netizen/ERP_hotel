-- docs/go-live/uat-accounts-template.sql
-- Tao tai khoan UAT (test theo tung vai tro) tren khach san TEST47.
-- Duy yeu cau 12/11/2026. Mat khau KHONG nam trong repo: thay __PASSWORD__ va
-- __PIN__ truoc khi chay, khong commit ban da thay.
--
-- An toan (cac gioi han do Claude Code dat, doi duoc neu Duy muon):
--  * CHI gan vai tro o khach san TEST47, khong o SONHOIAN (khach san that).
--  * KHONG tao vai tro sys_admin (mat khau yeu + quan tri he thong = chiem quyen).
--  * Vai tro het han sau 14 ngay (valid_to) de tai khoan test tu mat quyen.
--  * Luu y: danh muc vat tu / NCC la dung chung cap chuoi (org). Vai tro co
--    item.manage / supplier.manage o TEST47 van sua duoc danh muc dung chung.
-- Chay lai an toan: bo qua tai khoan da ton tai (theo email).
do $$
declare
  v_admin uuid := '20143f45-6e4a-4882-902c-78ce3677ad5c';
  v_prop  uuid := 'b0000000-0000-4000-8000-000000000002';
  v_pw    text := '__PASSWORD__';
  v_pin   text := '__PIN__';
  v_today date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  r record;
  v_uid uuid;
  v_email text;
  v_code text;
  v_created integer := 0;
begin
  perform set_config('request.jwt.claim.sub', v_admin::text, true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_admin::text, 'role', 'authenticated')::text, true);

  for r in
    select ro.id as role_id, ro.code, ro.name_vi
    from public.roles ro
    where ro.org_id = (select org_id from public.properties where id = v_prop)
      and ro.code <> 'sys_admin'
      and ro.active
    order by ro.code
  loop
    v_email := 'uat.' || r.code || '@erp.internal';
    v_code := upper('UAT-' || r.code);
    if exists (select 1 from auth.users where email = v_email) then
      continue;
    end if;

    v_uid := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change_token_new, email_change,
      email_change_token_current, phone_change, phone_change_token,
      reauthentication_token
    ) values (
      '00000000-0000-0000-0000-000000000000', v_uid, 'authenticated', 'authenticated',
      v_email, extensions.crypt(v_pw, extensions.gen_salt('bf')), now(),
      '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object('full_name', 'UAT ' || r.name_vi, 'employee_code', v_code,
        'email_verified', true),
      now(), now(), '', '', '', '', '', '', '', ''
    );

    insert into auth.identities (
      id, user_id, provider_id, provider, identity_data,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_uid, v_uid::text, 'email',
      jsonb_build_object('sub', v_uid::text, 'email', v_email,
        'email_verified', false, 'phone_verified', false),
      now(), now(), now()
    );

    -- Ho so do trigger on_auth_user_created_profile tao; bat hoat dong + dat PIN.
    update public.profiles
    set active = true,
        pin_hash = extensions.crypt(v_pin, extensions.gen_salt('bf'))
    where id = v_uid;

    perform public.admin_user_assign_role(
      v_uid, r.role_id, v_prop, null, null, v_today, v_today + 14);
    v_created := v_created + 1;
  end loop;

  raise notice 'UAT accounts created: %', v_created;
end $$;
