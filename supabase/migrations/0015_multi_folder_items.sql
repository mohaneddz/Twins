-- Items can live in several folders at once ("Add to folder" instead of
-- "Move to folder"), and profile edits reach the other twin live.
--
-- Folder membership is an array on the item rather than a link table: the
-- client already streams items over Realtime, so membership changes arrive
-- with them, and adding/removing a folder is a plain UPDATE (the RLS-on-INSERT
-- problem from 0012/0013 doesn't touch updates).

-- ---- Live profiles ----
alter table public.profiles replica identity full;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end $$;

-- ---- folder_ids ----
alter table public.items add column folder_ids uuid[] not null default '{}';
update public.items set folder_ids = array[folder_id] where folder_id is not null;
create index items_folder_ids_idx on public.items using gin (folder_ids);

drop trigger items_bump_folder_count on public.items;

create or replace function public.bump_folder_item_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Only folders of the item's own space are ever counted, so a stray id in
  -- folder_ids can't touch another pair's folders.
  if tg_op = 'INSERT' then
    update public.folders set item_count = item_count + 1
    where id = any(new.folder_ids) and space_id = new.space_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.folders set item_count = greatest(item_count - 1, 0)
    where id = any(old.folder_ids) and space_id = old.space_id;
    return old;
  elsif tg_op = 'UPDATE' then
    update public.folders set item_count = item_count + 1
    where id = any(new.folder_ids) and not (id = any(old.folder_ids)) and space_id = new.space_id;
    update public.folders set item_count = greatest(item_count - 1, 0)
    where id = any(old.folder_ids) and not (id = any(new.folder_ids)) and space_id = new.space_id;
    return new;
  end if;
  return null;
end;
$$;

create trigger items_bump_folder_count
  after insert or delete or update of folder_ids on public.items
  for each row execute function public.bump_folder_item_count();

update public.folders f
set item_count = (select count(*) from public.items i where f.id = any(i.folder_ids));

-- folder_id had "on delete set null"; the array needs the same by hand.
create function public.forget_deleted_folder()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.items set folder_ids = array_remove(folder_ids, old.id) where old.id = any(folder_ids);
  return null;
end;
$$;

-- AFTER, so the item update's count trigger finds the folder already gone
-- instead of modifying the row being deleted.
create trigger folders_forget_on_delete
  after delete on public.folders
  for each row execute function public.forget_deleted_folder();

-- ---- Item creation takes the folders up front ----
drop function public.create_item(uuid, uuid, text, text, text, text, text, text, text, text, jsonb, int);

create function public.create_item(
  p_space_id uuid,
  p_folder_ids uuid[],
  p_type text,
  p_platform text,
  p_source_url text,
  p_storage_path text,
  p_thumbnail_url text,
  p_title text,
  p_description text,
  p_content text,
  p_metadata jsonb,
  p_duration_ms int
)
returns public.items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.items;
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  insert into public.items (
    space_id, folder_ids, type, platform, source_url, storage_path,
    thumbnail_url, title, description, content, metadata, duration_ms, created_by
  )
  values (
    p_space_id,
    -- keep only folders that really belong to this space
    coalesce(array(select f.id from public.folders f where f.id = any(p_folder_ids) and f.space_id = p_space_id), '{}'),
    p_type, coalesce(p_platform, 'device'), p_source_url, p_storage_path,
    p_thumbnail_url, coalesce(p_title, 'Untitled'), p_description, p_content,
    coalesce(p_metadata, '{}'::jsonb), p_duration_ms, auth.uid()
  )
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.create_item(uuid, uuid[], text, text, text, text, text, text, text, text, jsonb, int) from public, anon;
grant execute on function public.create_item(uuid, uuid[], text, text, text, text, text, text, text, text, jsonb, int) to authenticated;

alter table public.items drop column folder_id;

-- ---- Search matches any of the item's folder names ----
create or replace function public.search_items(
  p_space_id uuid,
  p_query text,
  p_type text default null,
  p_limit int default 60
)
returns setof public.items
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select
      websearch_to_tsquery('english', p_query) as tsq,
      lower(btrim(p_query)) as raw
  )
  select i.*
  from public.items i
  cross join q
  left join lateral (
    select string_agg(t.name, ' ') as names
    from public.item_tags it
    join public.tags t on t.id = it.tag_id
    where it.item_id = i.id
  ) tg on true
  left join lateral (
    select string_agg(f.name, ' ') as names
    from public.folders f
    where f.id = any(i.folder_ids)
  ) fo on true
  where i.space_id = p_space_id
    and (p_type is null or i.type = p_type)
    and (
      i.search_vector @@ q.tsq
      or i.title ilike '%' || q.raw || '%'
      or extensions.similarity(lower(i.title), q.raw) > 0.3
      or lower(coalesce(tg.names, '')) like '%' || q.raw || '%'
      or lower(coalesce(fo.names, '')) like '%' || q.raw || '%'
    )
  order by
    ts_rank(i.search_vector, q.tsq) desc,
    extensions.similarity(lower(i.title), q.raw) desc,
    i.created_at desc
  limit greatest(p_limit, 1);
$$;


create or replace function public.twins_schema_version()
returns int
language sql
immutable
as $$ select 15 $$;
