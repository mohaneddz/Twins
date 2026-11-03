-- Settings → Clear data: wipe one kind of thing from the space in a single
-- call, for either twin. Accounts, the space itself and settings stay.
-- Uploaded files are removed by the app through the storage API (storage
-- rows can't be deleted from SQL), before it calls this.
--
--   items    every saved item, with its comments, tags and reactions
--   folders  empty every folder (items stay, just unfiled)
--   chats    every chat and its messages
--   all      all of the above plus the folders themselves, plans, the tag
--            catalog and search history

create function public.clear_space(p_space_id uuid, p_what text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  if p_what not in ('items', 'folders', 'chats', 'all') then
    raise exception 'Unknown thing to clear: %', p_what;
  end if;

  if p_what in ('items', 'all') then
    delete from public.reactions where space_id = p_space_id and target_type = 'item';
    delete from public.items where space_id = p_space_id;
  end if;

  if p_what = 'folders' then
    update public.items set folder_ids = '{}' where space_id = p_space_id and cardinality(folder_ids) > 0;
  end if;

  if p_what in ('chats', 'all') then
    delete from public.reactions where space_id = p_space_id and target_type <> 'item';
    delete from public.chats where space_id = p_space_id;
    delete from public.messages where space_id = p_space_id;
  end if;

  if p_what = 'all' then
    delete from public.events where space_id = p_space_id;
    delete from public.folders where space_id = p_space_id;
    delete from public.tags where space_id = p_space_id;
    delete from public.search_history where space_id = p_space_id;
  end if;
end;
$$;

revoke all on function public.clear_space(uuid, text) from public, anon;
grant execute on function public.clear_space(uuid, text) to authenticated;

create or replace function public.twins_schema_version()
returns int
language sql
immutable
as $$ select 19 $$;
