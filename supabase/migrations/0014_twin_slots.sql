-- One Supabase project = one pair of twins. Instead of emails and invite
-- codes, each project has exactly two account "slots": the app's "Who's
-- this?" screen lists them before anyone is logged in, and an empty slot can
-- be claimed with just a name and a password. The first claim creates the
-- space; the second joins it.
--
-- Accounts get a synthetic login email (twin1@twins.local / twin2@twins.local)
-- created directly in auth.users, so no confirmation email or SMTP setup is
-- ever involved.

alter table public.profiles add column slot smallint unique check (slot in (1, 2));

-- Projects that predate slots: when there's a single space, its owner becomes
-- twin 1 and the other member twin 2.
do $$
begin
  if (select count(*) from public.spaces) = 1 then
    update public.profiles p
    set slot = case m.role when 'owner' then 1 else 2 end
    from public.space_members m
    where m.user_id = p.id;
  end if;
end $$;

-- Bumped by every migration the app depends on; the setup screen compares it
-- with the version it ships with to decide whether the database needs work.
create function public.twins_schema_version()
returns int
language sql
immutable
as $$ select 14 $$;

grant execute on function public.twins_schema_version() to anon, authenticated;

-- Readable before login: who's in which slot, and how to sign them in.
create function public.twin_slots()
returns table (slot smallint, display_name text, avatar_path text, login_email text)
language sql
security definer
stable
set search_path = public
as $$
  select p.slot, p.display_name, p.avatar_path, u.email::text
  from public.profiles p
  join auth.users u on u.id = p.id
  where p.slot is not null
  order by p.slot;
$$;

revoke all on function public.twin_slots() from public;
grant execute on function public.twin_slots() to anon, authenticated;

create function public.set_auth_password(p_user_id uuid, p_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'Use at least 6 characters for the password.';
  end if;
  update auth.users
  set encrypted_password = extensions.crypt(p_password, extensions.gen_salt('bf')),
      updated_at = now()
  where id = p_user_id;
end;
$$;

revoke all on function public.set_auth_password(uuid, text) from public, anon, authenticated;

create function public.claim_twin_slot(p_slot smallint, p_display_name text, p_password text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid := gen_random_uuid();
  v_email text := format('twin%s@twins.local', p_slot);
  v_name text := trim(coalesce(p_display_name, ''));
  v_space_id uuid;
  v_tag_names text[] := array['funny', 'aesthetic', 'food', 'recipes', 'travel', 'music', 'workout', 'cozy', 'outfits', 'memes', 'art', 'study'];
  v_palette text[] := array['0xFF7EE7E1', '0xFFF6A5C0', '0xFFFFCC80', '0xFF90CAF9', '0xFFB39DDB', '0xFF80CBC4'];
  i int;
begin
  if p_slot not in (1, 2) then
    raise exception 'There are only two twins.';
  end if;
  if v_name = '' then
    raise exception 'Pick a name.';
  end if;
  if length(coalesce(p_password, '')) < 6 then
    raise exception 'Use at least 6 characters for the password.';
  end if;

  -- Both phones may hit "Create" at the same moment.
  perform pg_advisory_xact_lock(hashtext('twins_claim_slot'));

  if exists (select 1 from public.profiles where slot = p_slot) then
    raise exception 'That twin already has an account.';
  end if;
  if exists (select 1 from auth.users where email = v_email) then
    raise exception 'An account for twin % exists without a profile; remove it in Supabase → Authentication first.', p_slot;
  end if;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) values (
    '00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
    '{"provider": "email", "providers": ["email"]}', jsonb_build_object('display_name', v_name),
    now(), now(), '', '', '', ''
  );

  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (
    v_id::text, v_id,
    jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true),
    'email', now(), now(), now()
  );

  -- The profile row itself comes from the on_auth_user_created trigger.
  update public.profiles
  set display_name = v_name,
      username = lower(regexp_replace(v_name, '\s+', '', 'g')),
      slot = p_slot
  where id = v_id;

  select id into v_space_id from public.spaces order by created_at limit 1;

  if v_space_id is null then
    insert into public.spaces (name, created_by) values ('We''re Twins!', v_id) returning id into v_space_id;
    insert into public.space_members (space_id, user_id, role) values (v_space_id, v_id, 'owner');
    for i in 1..array_length(v_tag_names, 1) loop
      insert into public.tags (space_id, name, color)
      values (v_space_id, v_tag_names[i], v_palette[((i - 1) % array_length(v_palette, 1)) + 1]);
    end loop;
  else
    insert into public.space_members (space_id, user_id, role) values (v_space_id, v_id, 'member');
  end if;

  return v_email;
end;
$$;

revoke all on function public.claim_twin_slot(smallint, text, text) from public;
grant execute on function public.claim_twin_slot(smallint, text, text) to anon, authenticated;

-- There's no recovery email, so either twin can set a new password for the
-- other (or for themselves) from inside the app.
create function public.reset_twin_password(p_slot smallint, p_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target uuid;
begin
  select id into v_target from public.profiles where slot = p_slot;
  if v_target is null then
    raise exception 'That twin has no account yet.';
  end if;
  if not exists (
    select 1 from public.space_members me
    join public.space_members them on them.space_id = me.space_id
    where me.user_id = auth.uid() and them.user_id = v_target
  ) then
    raise exception 'You can only reset a password inside your own space.';
  end if;
  perform public.set_auth_password(v_target, p_password);
end;
$$;

revoke all on function public.reset_twin_password(smallint, text) from public, anon;
grant execute on function public.reset_twin_password(smallint, text) to authenticated;
