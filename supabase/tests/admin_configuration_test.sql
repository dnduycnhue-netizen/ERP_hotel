-- T-006 pgTAP: settings, approval rules and alert rules.
-- Run via `supabase test db` locally. Remote validation must include the
-- prerequisite migrations in one explicitly authorized transaction; this
-- test's final ROLLBACK must undo both schema changes and fixtures.
begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(25);

insert into public.organizations (id, name)
values ('d0060000-0600-4000-8000-000000000001', 'T-006 pgTAP organization')
on conflict (id) do nothing;

insert into public.legal_entities (
  id, org_id, code, name, accounting_regime, costing_method
)
values (
  'd0060000-0600-4000-8000-000000000101',
  'd0060000-0600-4000-8000-000000000001',
  'T006', 'T-006 pgTAP entity', 'TT99', 'moving_avg'
), (
  'd0060000-0600-4000-8000-000000000102',
  'd0060000-0600-4000-8000-000000000001',
  'T006B', 'T-006 pgTAP entity B', 'TT99', 'moving_avg'
)
on conflict (id) do nothing;

insert into public.properties (
  id, org_id, legal_entity_id, code, name, sod_profile
)
values (
  'd0060000-0600-4000-8000-000000000201',
  'd0060000-0600-4000-8000-000000000001',
  'd0060000-0600-4000-8000-000000000101',
  'T006', 'T-006 pgTAP property', 'with_cc'
), (
  'd0060000-0600-4000-8000-000000000202',
  'd0060000-0600-4000-8000-000000000001',
  'd0060000-0600-4000-8000-000000000102',
  'T006B', 'T-006 pgTAP property B', 'with_cc'
)
on conflict (id) do nothing;

insert into public.roles (id, org_id, code, name_vi, is_system)
values
  ('d0060000-0600-4000-8000-000000000501', 'd0060000-0600-4000-8000-000000000001', 't006_admin', 'T-006 admin', false),
  ('d0060000-0600-4000-8000-000000000502', 'd0060000-0600-4000-8000-000000000001', 't006_approver', 'T-006 approver', false),
  ('d0060000-0600-4000-8000-000000000503', 'd0060000-0600-4000-8000-000000000001', 't006_property_admin', 'T-006 property admin', false)
on conflict (id) do nothing;

insert into public.role_permissions (role_id, permission_code)
values
  ('d0060000-0600-4000-8000-000000000501', 'admin.settings.manage'),
  ('d0060000-0600-4000-8000-000000000501', 'admin.approval_rules.manage'),
  ('d0060000-0600-4000-8000-000000000501', 'admin.alert_rules.manage'),
  ('d0060000-0600-4000-8000-000000000501', 'po.approve'),
  ('d0060000-0600-4000-8000-000000000502', 'po.approve'),
  ('d0060000-0600-4000-8000-000000000503', 'admin.approval_rules.manage'),
  ('d0060000-0600-4000-8000-000000000503', 'admin.alert_rules.manage')
on conflict do nothing;

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data
)
values
  (
    'd0060000-0600-4000-8000-000000000a11',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 't006-admin@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"T-006 administrator"}'::jsonb
  ),
  (
    'd0060000-0600-4000-8000-000000000a12',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 't006-approver@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"T-006 approver"}'::jsonb
  ),
  (
    'd0060000-0600-4000-8000-000000000a13',
    '00000000-0000-0000-0000-000000000000',
    'authenticated', 'authenticated', 't006-property-admin@example.test', '',
    now(), now(), now(), '{}'::jsonb, '{"full_name":"T-006 property administrator"}'::jsonb
  );

insert into public.user_property_roles (user_id, role_id, property_id)
values
  ('d0060000-0600-4000-8000-000000000a11', 'd0060000-0600-4000-8000-000000000501', null),
  ('d0060000-0600-4000-8000-000000000a12', 'd0060000-0600-4000-8000-000000000502', null),
  ('d0060000-0600-4000-8000-000000000a13', 'd0060000-0600-4000-8000-000000000503', 'd0060000-0600-4000-8000-000000000201');

select set_config(
  'request.jwt.claim.sub',
  'd0060000-0600-4000-8000-000000000a11',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"d0060000-0600-4000-8000-000000000a11","role":"authenticated"}',
  true
);
set local role authenticated;

select has_table('public', 'settings', 'settings table exists');
select has_table('public', 'approval_rules', 'approval_rules table exists');
select has_table('public', 'alert_rules', 'alert_rules table exists');
select ok(
  (select c.relrowsecurity from pg_class c where c.oid = 'public.settings'::regclass),
  'settings has row level security enabled'
);
select ok(
  (select c.relrowsecurity from pg_class c where c.oid = 'public.approval_rules'::regclass),
  'approval_rules has row level security enabled'
);
select ok(
  (select c.relrowsecurity from pg_class c where c.oid = 'public.alert_rules'::regclass),
  'alert_rules has row level security enabled'
);
select ok(
  not has_table_privilege('authenticated', 'public.settings', 'SELECT'),
  'settings is read only through permission-checked RPCs'
);
select ok(
  public.admin_settings_list(
    'd0060000-0600-4000-8000-000000000001', null
  ) @> '[{"key":"price_spike_pct","value":"10","source":"default"}]'::jsonb,
  'settings list returns documented defaults'
);
select ok(
  (
    public.admin_setting_save(
      'd0060000-0600-4000-8000-000000000001',
      null,
      'receiving_tolerance_pct',
      '7.5'
    ) ->> 'ok'
  ) = 'true',
  'authorized admin can save a setting'
);
select ok(
  public.admin_settings_list(
    'd0060000-0600-4000-8000-000000000001', null
  ) @> '[{"key":"receiving_tolerance_pct","value":"7.5","source":"organization"}]'::jsonb,
  'saved setting takes effect immediately'
);
select ok(
  (
    public.admin_setting_save(
      'd0060000-0600-4000-8000-000000000001',
      'd0060000-0600-4000-8000-000000000201',
      'receiving_tolerance_pct',
      '4.5'
    ) ->> 'ok'
  ) = 'true',
  'authorized admin can save a property-level override'
);
select ok(
  public.admin_settings_list(
    'd0060000-0600-4000-8000-000000000001',
    'd0060000-0600-4000-8000-000000000201'
  ) @> '[{"key":"receiving_tolerance_pct","value":"4.5","source":"property"}]'::jsonb,
  'property setting overrides the organization value'
);
select throws_ok(
  $$select public.admin_setting_save(
    'd0060000-0600-4000-8000-000000000001', null, 'receiving_tolerance_pct', '101'
  )$$,
  'P0001',
  'ERR_CONFIG_INVALID',
  'out-of-range settings are rejected'
);
select ok(
  public.admin_approval_approvers_list(
    'd0060000-0600-4000-8000-000000000001', null
  ) @> '{"users":[{"id":"d0060000-0600-4000-8000-000000000a12"}]}'::jsonb,
  'approval manager can select organization users as approvers'
);
select ok(
  (
    public.admin_approval_rule_save(
      jsonb_build_object(
        'org_id', 'd0060000-0600-4000-8000-000000000001',
        'property_id', null,
        'doc_type', 'purchase_order',
        'min_amount', '5000000',
        'max_amount', '20000000',
        'condition', '{}'::jsonb,
        'step', 1,
        'approver_role_id', 'd0060000-0600-4000-8000-000000000502',
        'approver_user_id', null,
        'required_perm', 'po.approve'
      )
    ) ->> 'ok'
  ) = 'true',
  'authorized admin can save a valid approval rule'
);
select ok(
  public.admin_approval_rules_list(
    'd0060000-0600-4000-8000-000000000001', null
  ) @> '[{"doc_type":"purchase_order","min_amount":"5000000.00","step":1}]'::jsonb,
  'saved approval rule is returned from the selected scope'
);
select throws_ok(
  $$select public.admin_approval_rule_save(
    jsonb_build_object(
      'org_id', 'd0060000-0600-4000-8000-000000000001',
      'property_id', null,
      'doc_type', 'purchase_order',
      'min_amount', '0',
      'condition', '{}'::jsonb,
      'step', 1,
      'approver_role_id', 'd0060000-0600-4000-8000-000000000502',
      'required_perm', 'receiving.post'
    )
  )$$,
  'P0001',
  'ERR_CONFIG_APPROVER',
  'approver role must contain the required permission'
);
select ok(
  (
    public.admin_approval_rule_delete(
      (
        public.admin_approval_rules_list(
          'd0060000-0600-4000-8000-000000000001', null
        )->0->>'id'
      )::uuid
    ) ->> 'ok'
  ) = 'true',
  'authorized admin can remove an approval rule'
);
select set_config(
  'test.t006_approval_rule_id',
  (public.admin_approval_rule_save(
    jsonb_build_object(
      'org_id', 'd0060000-0600-4000-8000-000000000001',
      'property_id', 'd0060000-0600-4000-8000-000000000202',
      'doc_type', 'purchase_order',
      'min_amount', '1000000',
      'condition', '{}'::jsonb,
      'step', 1,
      'approver_role_id', 'd0060000-0600-4000-8000-000000000502',
      'required_perm', 'po.approve'
    )
  )->>'id'),
  true
);
select ok(
  (
    public.admin_alert_rule_save(
      jsonb_build_object(
        'org_id', 'd0060000-0600-4000-8000-000000000001',
        'property_id', null,
        'code', 'PRICE_SPIKE',
        'threshold', '{"increase_pct":10}'::jsonb,
        'channels', '["app","email"]'::jsonb,
        'urgent', false,
        'active', true
      )
    ) ->> 'ok'
  ) = 'true',
  'authorized admin can save an alert rule'
);
select ok(
  public.admin_alert_rules_list(
    'd0060000-0600-4000-8000-000000000001', null
  ) @> '[{"code":"PRICE_SPIKE","threshold":{"increase_pct":10},"channels":["app","email"]}]'::jsonb,
  'saved alert rule is returned from the selected scope'
);
select throws_ok(
  $$select public.admin_alert_rule_save(
    jsonb_build_object(
      'org_id', 'd0060000-0600-4000-8000-000000000001',
      'property_id', null,
      'code', 'INVALID_CHANNEL',
      'threshold', '{}'::jsonb,
      'channels', '["sms"]'::jsonb,
      'urgent', false,
      'active', true
    )
  )$$,
  'P0001',
  'ERR_CONFIG_INVALID',
  'unsupported alert channels are rejected'
);
select ok(
  (
    public.admin_alert_rule_delete(
      (
        public.admin_alert_rules_list(
          'd0060000-0600-4000-8000-000000000001', null
        )->0->>'id'
      )::uuid
    ) ->> 'ok'
  ) = 'true',
  'authorized admin can remove an alert rule'
);
select set_config(
  'test.t006_alert_rule_id',
  (public.admin_alert_rule_save(
    jsonb_build_object(
      'org_id', 'd0060000-0600-4000-8000-000000000001',
      'property_id', 'd0060000-0600-4000-8000-000000000202',
      'code', 'PRICE_SPIKE',
      'threshold', '{"increase_pct":10}'::jsonb,
      'channels', '["app"]'::jsonb,
      'urgent', false,
      'active', true
    )
  )->>'id'),
  true
);

select set_config(
  'request.jwt.claim.sub',
  'd0060000-0600-4000-8000-000000000a13',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"d0060000-0600-4000-8000-000000000a13","role":"authenticated"}',
  true
);
select throws_ok(
  $$select public.admin_settings_list(
    'd0060000-0600-4000-8000-000000000001', null
  )$$,
  'P0001',
  'ERR_FORBIDDEN',
  'users without settings permission cannot read configuration'
);
select throws_ok(
  $$select public.admin_approval_rule_save(
    jsonb_build_object(
      'id', current_setting('test.t006_approval_rule_id'),
      'org_id', 'd0060000-0600-4000-8000-000000000001',
      'property_id', 'd0060000-0600-4000-8000-000000000201',
      'doc_type', 'purchase_order',
      'min_amount', '1000000',
      'condition', '{}'::jsonb,
      'step', 1,
      'approver_role_id', 'd0060000-0600-4000-8000-000000000502',
      'required_perm', 'po.approve'
    )
  )$$,
  'P0001',
  'ERR_FORBIDDEN',
  'property admins cannot move rules from another property'
);
select throws_ok(
  $$select public.admin_alert_rule_save(
    jsonb_build_object(
      'id', current_setting('test.t006_alert_rule_id'),
      'org_id', 'd0060000-0600-4000-8000-000000000001',
      'property_id', 'd0060000-0600-4000-8000-000000000201',
      'code', 'PRICE_SPIKE',
      'threshold', '{"increase_pct":10}'::jsonb,
      'channels', '["app"]'::jsonb,
      'urgent', false,
      'active', true
    )
  )$$,
  'P0001',
  'ERR_FORBIDDEN',
  'property admins cannot move alerts from another property'
);

select * from finish();
rollback;
