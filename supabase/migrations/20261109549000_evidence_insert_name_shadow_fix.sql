-- Q226: evidence_insert policy referenced bare `name` inside EXISTS over
-- public.properties p. Postgres resolves unqualified columns innermost-first,
-- so `name` bound to p.name (the property's display name, e.g. 'Property T-016')
-- instead of the new storage.objects row's name (the object path). As a result
-- storage.foldername(...)[1] never matched a legal_entity_id, exists() was
-- always false, and EVERY insert into storage.objects failed RLS (42501) for
-- every user — evidence uploads via the Storage API never worked on production.
-- The sibling evidence_select policy already qualifies storage.objects.name
-- correctly, so this fix only qualifies the same column here. No other change.
drop policy if exists evidence_insert on storage.objects;
create policy evidence_insert on storage.objects
for insert to authenticated
with check (
  bucket_id in ('evidence', 'attachments')
  and exists (
    select 1
    from public.properties p
    where p.legal_entity_id::text = (storage.foldername(storage.objects.name))[1]
      and p.id in (select public.my_property_ids())
  )
);
