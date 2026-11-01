-- Pairing + Row Level Security checks for ¡Twins!.
--
-- Runs entirely inside one transaction that always ends in ROLLBACK, so it is
-- safe against a live project: three throwaway auth users act out the
-- create -> invite -> join flow and every assertion runs as the
-- `authenticated` role with that user's JWT claims, exactly like PostgREST.
--
--   psql "$SUPABASE_POOLER_CONNECTION_STRING" -v ON_ERROR_STOP=1 -f supabase/tests/pairing_rls_test.sql
--
-- Any failed check raises, psql stops, and the transaction is discarded.

\set QUIET on
begin;

-- Fixed ids so the steps below can refer to each user.
\set alice '''00000000-0000-4000-a000-00000000000a'''
\set bob   '''00000000-0000-4000-a000-00000000000b'''
\set carol '''00000000-0000-4000-a000-00000000000c'''

insert into auth.users (id, email, aud, role)
values
  (:alice, 'alice@twins.test', 'authenticated', 'authenticated'),
  (:bob,   'bob@twins.test',   'authenticated', 'authenticated'),
  (:carol, 'carol@twins.test', 'authenticated', 'authenticated');

-- Results shared between steps, readable by every role for this transaction.
create temp table fixture (key text primary key, value text);
grant all on fixture to authenticated;

-- ---- Alice creates a space and an invite ----
set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :alice, 'role', 'authenticated')::text, true);

insert into fixture select 'space', (public.create_space('Test pair')).id::text;
insert into fixture select 'invite', (public.create_invite((select value::uuid from fixture where key = 'space'))).code;
insert into fixture select 'item', (public.create_item(
  p_space_id => (select value::uuid from fixture where key = 'space'),
  p_folder_id => null, p_type => 'note', p_platform => 'device', p_source_url => null,
  p_storage_path => null, p_thumbnail_url => null, p_title => 'Private note',
  p_description => null, p_content => 'only for the two of us', p_metadata => '{}'::jsonb,
  p_duration_ms => null)).id::text;

do $$ begin
  if (select role from public.space_members where user_id = auth.uid()) is distinct from 'owner' then
    raise exception 'FAIL: create_space should make the caller the owner';
  end if;
  raise notice 'ok: create_space makes the creator the owner';
end $$;

-- ---- Carol, not yet paired, sees nothing of Alice's space ----
select set_config('request.jwt.claims', json_build_object('sub', :carol, 'role', 'authenticated')::text, true);

do $$ begin
  if exists (select 1 from public.spaces) or exists (select 1 from public.items)
     or exists (select 1 from public.space_members) or exists (select 1 from public.space_invites) then
    raise exception 'FAIL: an outsider can read another space''s rows';
  end if;
  raise notice 'ok: outsider reads no spaces, items, members or invites';
end $$;

do $$ begin
  perform public.create_item(
    p_space_id => (select value::uuid from fixture where key = 'space'),
    p_folder_id => null, p_type => 'note', p_platform => 'device', p_source_url => null,
    p_storage_path => null, p_thumbnail_url => null, p_title => 'Intruder',
    p_description => null, p_content => null, p_metadata => '{}'::jsonb, p_duration_ms => null);
  raise exception 'FAIL: an outsider created an item in another space';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise notice 'ok: outsider cannot create items in another space';
end $$;

do $$ begin
  update public.items set title = 'tampered' where id = (select value::uuid from fixture where key = 'item');
  delete from public.items where id = (select value::uuid from fixture where key = 'item');
  raise notice 'ok: outsider update/delete statements touch nothing (verified below)';
end $$;

-- ---- Bob joins with the invite ----
select set_config('request.jwt.claims', json_build_object('sub', :bob, 'role', 'authenticated')::text, true);

do $$ begin
  if public.join_space_with_code(lower((select value from fixture where key = 'invite')))
     is distinct from (select value::uuid from fixture where key = 'space') then
    raise exception 'FAIL: join_space_with_code returned the wrong space';
  end if;
  raise notice 'ok: invite codes are case-insensitive and join the right space';
end $$;

do $$ begin
  if (select title from public.items where id = (select value::uuid from fixture where key = 'item'))
     is distinct from 'Private note' then
    raise exception 'FAIL: the paired twin cannot see the item, or the outsider changed it';
  end if;
  if (select count(*) from public.space_members) <> 2 then
    raise exception 'FAIL: the paired twin should see both memberships';
  end if;
  raise notice 'ok: paired twin sees the shared item, untouched by the outsider';
end $$;

do $$ begin
  perform public.join_space_with_code((select value from fixture where key = 'invite'));
  raise exception 'FAIL: a member joined a second space';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  if sqlerrm not like '%already belong%' then raise exception 'FAIL: unexpected error: %', sqlerrm; end if;
  raise notice 'ok: a paired user cannot join another space';
end $$;

-- ---- Carol tries every way into the full space ----
select set_config('request.jwt.claims', json_build_object('sub', :carol, 'role', 'authenticated')::text, true);

do $$ begin
  perform public.join_space_with_code((select value from fixture where key = 'invite'));
  raise exception 'FAIL: a used invite was accepted';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  if sqlerrm not like '%already been used%' then raise exception 'FAIL: unexpected error: %', sqlerrm; end if;
  raise notice 'ok: invites are single-use';
end $$;

do $$ begin
  insert into public.space_members (space_id, user_id) values ((select value::uuid from fixture where key = 'space'), auth.uid());
  raise exception 'FAIL: a third member was inserted directly';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise notice 'ok: direct insert of a third member is rejected (%)', sqlerrm;
end $$;

do $$ begin
  perform public.join_space_with_code('ZZZZZZ');
  raise exception 'FAIL: an unknown code was accepted';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  raise notice 'ok: unknown invite codes are rejected';
end $$;

-- ---- A fresh invite still can't add a third member ----
select set_config('request.jwt.claims', json_build_object('sub', :alice, 'role', 'authenticated')::text, true);
insert into fixture select 'invite2', (public.create_invite((select value::uuid from fixture where key = 'space'))).code;

select set_config('request.jwt.claims', json_build_object('sub', :carol, 'role', 'authenticated')::text, true);
do $$ begin
  perform public.join_space_with_code((select value from fixture where key = 'invite2'));
  raise exception 'FAIL: a third member joined with a fresh invite';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  if sqlerrm not like '%two members%' then raise exception 'FAIL: unexpected error: %', sqlerrm; end if;
  raise notice 'ok: the two-member cap holds for a fresh, valid invite';
end $$;

-- ---- Expired invites ----
reset role;
update public.space_invites set expires_at = now() - interval '1 minute'
where code = (select value from fixture where key = 'invite2');
delete from public.space_members where user_id = :bob;

set local role authenticated;
select set_config('request.jwt.claims', json_build_object('sub', :carol, 'role', 'authenticated')::text, true);
do $$ begin
  perform public.join_space_with_code((select value from fixture where key = 'invite2'));
  raise exception 'FAIL: an expired invite was accepted';
exception when others then
  if sqlerrm like 'FAIL:%' then raise; end if;
  if sqlerrm not like '%expired%' then raise exception 'FAIL: unexpected error: %', sqlerrm; end if;
  raise notice 'ok: expired invites are rejected';
end $$;

reset role;
rollback;
\echo 'All pairing/RLS checks passed (rolled back, nothing persisted).'
