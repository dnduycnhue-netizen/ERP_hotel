-- docs/go-live/p0-cleanup-2026-11-12.sql
-- Thao tac DU LIEU mot lan truoc cutover (Duy duyet 12/11/2026). Chay SAU khi
-- migration 20261109564000_count_adjust_reverse.sql da duoc db push.
-- Da dien tap trong transaction rollback tren production: ton SONHOIAN ve 0,
-- item_costs ve 0, 28 but toan dao, TEST01-05 khong con quyen toan chuoi
-- (6 vai tro chuyen sang TEST47). Chay bang:
--   supabase db query --remote -f docs/go-live/p0-cleanup-2026-11-12.sql
-- KHONG chay lai: dot kiem ke da dao het (ERR_ALREADY_REVERSED), vai tro TEST
-- da khong con pham vi toan chuoi (vong lap khong co dong nao).
-- Thao tac P0 tren production (chay SAU khi migration 564000 da co).
-- Dung danh tinh tai khoan quan tri 0001 (JWT claims) de qua kiem tra quyen,
-- ly do ghi ro nguoi thuc hien thuc te.
select set_config('request.jwt.claim.sub', '20143f45-6e4a-4882-902c-78ce3677ad5c', true);
select set_config('request.jwt.claims', '{"sub":"20143f45-6e4a-4882-902c-78ce3677ad5c","role":"authenticated"}', true);

-- 1. Dao 28 but toan adjust_count cua dot kiem ke thu.
select public.count_adjust_reverse(
  (select id from public.stock_counts where doc_no = 'CNT-SONHOIAN-2611-0001'),
  'Don du lieu kiem ke thu truoc go-live (don gia 0, tai khoan TEST03). Thuc hien boi Claude Code theo yeu cau cua Duy 12/11/2026.'
) as reverse_result;

-- 2. Thu hep TEST01-05 tu pham vi toan chuoi ve khach san TEST47.
do $$
declare
  r record;
begin
  for r in
    select u.id as assignment_id, u.user_id, u.role_id
    from public.user_property_roles u
    join public.profiles p on p.id = u.user_id
    where p.employee_code ~ '^TEST0[1-5]$' and u.property_id is null
    order by p.employee_code
  loop
    perform public.admin_user_assign_role(r.user_id, r.role_id, 'b0000000-0000-4000-8000-000000000002');
    perform public.admin_user_revoke_role(r.assignment_id,
      'Thu hep tai khoan test ve TEST47 truoc go-live (Duy duyet 12/11/2026). Thuc hien boi Claude Code.');
    -- RPC chi dat valid_to = hom nay (quyen con hieu luc het ngay hom nay theo
    -- has_perm: business_date between valid_from and valid_to). Dat ve hom qua
    -- de thu hoi co hieu luc NGAY.
    update public.user_property_roles
    set valid_to = greatest(valid_from, (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1)
    where id = r.assignment_id;
  end loop;
end $$;
