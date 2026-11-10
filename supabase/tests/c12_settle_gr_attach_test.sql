-- C12 (Q74): migration 20261109531000 cap `attachment.upload` +
-- `receiving.view` cho vai tro `accountant` (nguoi duy nhat co
-- `advance.settle`) de form quyet toan tam ung gan duoc phieu nhan
-- da chot va anh bien lai vao tung dong chi.
-- Khong doi RPC nao (advance_settle da nhan gr_id + receipt_photo_id);
-- suite nay chi kiem chung grant + tinh idempotent.
--
-- Run via: supabase test db (needs Docker; cannot run on the agent VM).

begin;
select plan(4);

-- 1. accountant co attachment.upload (de tai anh bien lai)
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'accountant'
            and rp.permission_code = 'attachment.upload'),
  'accountant: has attachment.upload (C12)'
);

-- 2. accountant co receiving.view (de liet ke phieu nhan da chot)
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'accountant'
            and rp.permission_code = 'receiving.view'),
  'accountant: has receiving.view (C12)'
);

-- 3. Quyen quyet toan goc khong doi
select ok(
  exists (select 1 from public.role_permissions rp
          join public.roles r on r.id = rp.role_id
          where r.code = 'accountant'
            and rp.permission_code = 'advance.settle'),
  'accountant: still has advance.settle (140000)'
);

-- 4. Chay lai cau lenh cap quyen cua migration khong tao trung
insert into public.role_permissions (role_id, permission_code)
select r.id, rp.permission_code
from public.roles r
join (
  values
    ('accountant', 'attachment.upload'),
    ('accountant', 'receiving.view')
) as rp(role_code, permission_code)
  on r.code = rp.role_code
on conflict (role_id, permission_code) do nothing;

select is(
  (select count(*) from public.role_permissions rp
   join public.roles r on r.id = rp.role_id
   where r.code = 'accountant'
     and rp.permission_code in ('attachment.upload', 'receiving.view')),
  2::bigint,
  'accountant: exactly 2 new grants, no duplicates after re-run'
);

select * from finish();
rollback;
