-- ¡Twins! Row Level Security. A logged-in user may only read/write content
-- belonging to a space they are a member of. This is the real security
-- boundary - the Flutter client never enforces authorization itself.

-- Helper: is the current user a member of the given space? SECURITY DEFINER
-- so it can read space_members without recursing through that table's own
-- RLS policy (which itself calls this function).
create function public.is_space_member(p_space_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.space_members
    where space_id = p_space_id and user_id = auth.uid()
  );
$$;

-- Helper: the current user's space id, if any.
create function public.my_space_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select space_id from public.space_members where user_id = auth.uid() limit 1;
$$;

alter table public.profiles enable row level security;
alter table public.spaces enable row level security;
alter table public.space_members enable row level security;
alter table public.space_invites enable row level security;
alter table public.folders enable row level security;
alter table public.items enable row level security;
alter table public.tags enable row level security;
alter table public.item_tags enable row level security;
alter table public.item_comments enable row level security;
alter table public.messages enable row level security;
alter table public.reactions enable row level security;
alter table public.user_settings enable row level security;

-- profiles: anyone signed in can read profiles of members of their own
-- space (needed to render author names/avatars); everyone can read/update
-- only their own profile row directly.
create policy profiles_select_self_or_spacemate on public.profiles
  for select using (
    id = auth.uid()
    or id in (select user_id from public.space_members where space_id = public.my_space_id())
  );
create policy profiles_update_self on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- spaces: members only.
create policy spaces_select_member on public.spaces
  for select using (public.is_space_member(id));
create policy spaces_insert_own on public.spaces
  for insert with check (created_by = auth.uid());

-- space_members: members can see their own membership row and their twin's.
create policy space_members_select_member on public.space_members
  for select using (public.is_space_member(space_id));
create policy space_members_insert_self on public.space_members
  for insert with check (user_id = auth.uid());
create policy space_members_delete_self on public.space_members
  for delete using (user_id = auth.uid());

-- space_invites: only the creating member (space owner) can see/manage
-- their own space's invites directly; joining happens exclusively through
-- the join_space_with_code() RPC below, which runs with elevated rights.
create policy space_invites_select_member on public.space_invites
  for select using (public.is_space_member(space_id));
create policy space_invites_insert_member on public.space_invites
  for insert with check (public.is_space_member(space_id) and created_by = auth.uid());

-- folders / items / tags / item_tags / comments / messages / reactions /
-- user_settings: standard "must be a member of the owning space" policy.
create policy folders_all_member on public.folders
  for all using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));

create policy items_all_member on public.items
  for all using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));

create policy tags_all_member on public.tags
  for all using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));

create policy item_tags_all_member on public.item_tags
  for all using (
    exists (select 1 from public.items where items.id = item_tags.item_id and public.is_space_member(items.space_id))
  ) with check (
    exists (select 1 from public.items where items.id = item_tags.item_id and public.is_space_member(items.space_id))
  );

create policy item_comments_all_member on public.item_comments
  for all using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));

create policy messages_all_member on public.messages
  for all using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));

create policy reactions_all_member on public.reactions
  for all using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));

create policy user_settings_self on public.user_settings
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
