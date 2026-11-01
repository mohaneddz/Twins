-- Twin slot checks (migration 0014): claiming, duplicates, the shared space
-- and password resets. Like pairing_rls_test.sql it runs in one transaction
-- that always rolls back, so it is safe against a live project - but it
-- expects a project with no twins yet, since it claims both slots.
--
--   psql "$SUPABASE_POOLER_CONNECTION_STRING" -v ON_ERROR_STOP=1 -f supabase/tests/twin_slots_test.sql

\set QUIET on
begin;

do $$ begin
  if exists (select 1 from public.profiles where slot is not null) then
    raise exception 'SKIP: this project already has twins; run against an empty one';
  end if;
end $$;

set local role anon;

do $$ begin
  if public.claim_twin_slot(1::smallint, ' Mohaned ', '12345678') <> 'twin1@twins.local' then
    raise exception 'FAIL: unexpected login email for slot 1';
  end if;
  raise notice 'ok: an empty slot is claimable before login';
end $$;

do $$ begin
  perform public.claim_twin_slot(1::smallint, 'Someone', '12345678');
  raise exception 'FAIL: a taken slot was claimed twice';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise notice 'ok: a taken slot cannot be claimed again';
end $$;

do $$ begin
  perform public.claim_twin_slot(2::smallint, 'Rania', '123');
  raise exception 'FAIL: a short password was accepted';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise notice 'ok: passwords under 6 characters are rejected';
end $$;

do $$ begin
  perform public.claim_twin_slot(3::smallint, 'Third', '12345678');
  raise exception 'FAIL: a third slot was claimed';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise notice 'ok: there is no third slot';
end $$;

select public.claim_twin_slot(2::smallint, 'Rania', '12345678') \gset

do $$ begin
  if (select count(*) from public.twin_slots()) <> 2
     or (select display_name from public.twin_slots() where slot = 1) <> 'Mohaned' then
    raise exception 'FAIL: twin_slots() should list both trimmed names';
  end if;
  raise notice 'ok: twin_slots() lists both twins';
end $$;

do $$ begin
  perform public.reset_twin_password(2::smallint, 'newpass1');
  raise exception 'FAIL: anon reset a password';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise notice 'ok: resetting a password needs a signed-in twin';
end $$;

reset role;

do $$ begin
  if (select count(distinct m.space_id) from public.space_members m join public.profiles p on p.id = m.user_id where p.slot is not null) <> 1
     or (select role from public.space_members m join public.profiles p on p.id = m.user_id where p.slot = 1) <> 'owner' then
    raise exception 'FAIL: both twins should share one space, twin 1 owning it';
  end if;
  raise notice 'ok: twin 1 creates the space and twin 2 joins it';
end $$;

select set_config('request.jwt.claims', json_build_object('sub', (select id from public.profiles where slot = 1), 'role', 'authenticated')::text, true) is not null as claims_set \gset
set local role authenticated;
select public.reset_twin_password(2::smallint, 'newpass1') is null as reset_done \gset
reset role;

do $$ begin
  if not (select encrypted_password = extensions.crypt('newpass1', encrypted_password) from auth.users where email = 'twin2@twins.local') then
    raise exception 'FAIL: twin 1 could not reset twin 2''s password';
  end if;
  raise notice 'ok: a twin can reset the other''s password';
end $$;

rollback;
\echo 'All twin slot checks passed (rolled back, nothing persisted).'
