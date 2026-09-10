-- Workaround for a Postgres/PostgREST bug observed on this project: plain
-- client-side INSERTs get rejected by RLS ("new row violates row-level
-- security policy") even when the WITH CHECK expression is provably true in
-- the same authenticated request (verified: an UPDATE using the identical
-- `created_by = auth.uid()` check succeeds every time; a fresh scratch table
-- with the identical policy reproduces the same INSERT failure). Until that's
-- resolved upstream, space creation runs as SECURITY DEFINER instead - same
-- pattern already used by join_space_with_code (0005) - enforcing the same
-- invariant (created_by can only ever be the caller's own id) in the
-- function body rather than relying on the broken INSERT policy path.

create function public.create_space(p_name text)
returns public.spaces
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space public.spaces;
  v_tag_names text[] := array['funny', 'aesthetic', 'food', 'recipes', 'travel', 'music', 'workout', 'cozy', 'outfits', 'memes', 'art', 'study'];
  v_palette text[] := array['0xFF7EE7E1', '0xFFF6A5C0', '0xFFFFCC80', '0xFF90CAF9', '0xFFB39DDB', '0xFF80CBC4'];
  i int;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.spaces (name, created_by)
  values (p_name, auth.uid())
  returning * into v_space;

  insert into public.space_members (space_id, user_id, role)
  values (v_space.id, auth.uid(), 'owner');

  -- Starter tag catalog (best-effort to match the previous client behavior;
  -- a failure here shouldn't roll back the space itself in practice this
  -- never fails, but keep it simple and let it propagate like everything
  -- else in this function - one atomic transaction, or none of it).
  for i in 1..array_length(v_tag_names, 1) loop
    insert into public.tags (space_id, name, color)
    values (v_space.id, v_tag_names[i], v_palette[((i - 1) % array_length(v_palette, 1)) + 1]);
  end loop;

  return v_space;
end;
$$;

revoke all on function public.create_space(text) from public;
grant execute on function public.create_space(text) to authenticated;

-- Same workaround for invite creation (also a plain client INSERT today).
create function public.create_invite(p_space_id uuid)
returns public.space_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.space_invites;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1 from public.space_members
    where space_id = p_space_id and user_id = auth.uid()
  ) then
    raise exception 'You are not a member of this space.';
  end if;

  insert into public.space_invites (space_id, created_by)
  values (p_space_id, auth.uid())
  returning * into v_invite;

  return v_invite;
end;
$$;

revoke all on function public.create_invite(uuid) from public;
grant execute on function public.create_invite(uuid) to authenticated;
