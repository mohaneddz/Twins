-- Secure invite-code redemption. Runs as SECURITY DEFINER so it can validate
-- the invite and insert the membership row atomically, without ever trusting
-- a space_id supplied directly by the client.
create function public.join_space_with_code(invite_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invite public.space_invites;
  v_member_count int;
  v_space_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  -- Reject if the caller already belongs to a space.
  if exists (select 1 from public.space_members where user_id = auth.uid()) then
    raise exception 'You already belong to a Twins space.';
  end if;

  select * into v_invite
  from public.space_invites
  where code = upper(invite_code)
  for update;

  if v_invite is null then
    raise exception 'That invite code is invalid.';
  end if;

  if v_invite.used_at is not null then
    raise exception 'That invite code has already been used.';
  end if;

  if v_invite.expires_at < now() then
    raise exception 'That invite code has expired.';
  end if;

  select count(*) into v_member_count
  from public.space_members
  where space_id = v_invite.space_id;

  if v_member_count >= 2 then
    raise exception 'This Twins space already has two members.';
  end if;

  v_space_id := v_invite.space_id;

  insert into public.space_members (space_id, user_id, role)
  values (v_space_id, auth.uid(), 'member');

  update public.space_invites
  set used_at = now(), used_by = auth.uid()
  where id = v_invite.id;

  return v_space_id;
end;
$$;

revoke all on function public.join_space_with_code(text) from public;
grant execute on function public.join_space_with_code(text) to authenticated;
