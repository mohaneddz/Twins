-- Extends the workaround from migration 0012 to every other table that does
-- a plain client-side INSERT. Same root cause (see 0012's comment): this
-- project's PostgREST INSERT path rejects rows that satisfy their own RLS
-- WITH CHECK, while the identical check succeeds on UPDATE. Each function
-- below enforces the same invariant its table's policy already declares
-- (see migration 0004/0011), just from inside a security-definer function
-- instead of relying on the broken client-INSERT-under-RLS path.

-- ---- Folders ----
create function public.create_folder(
  p_space_id uuid,
  p_parent_id uuid,
  p_name text,
  p_color text,
  p_icon text
)
returns public.folders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.folders;
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  insert into public.folders (space_id, parent_id, name, color, icon, created_by)
  values (p_space_id, p_parent_id, p_name, p_color, p_icon, auth.uid())
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.create_folder(uuid, uuid, text, text, text) from public;
grant execute on function public.create_folder(uuid, uuid, text, text, text) to authenticated;

-- ---- Items ----
create function public.create_item(
  p_space_id uuid,
  p_folder_id uuid,
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
    space_id, folder_id, type, platform, source_url, storage_path,
    thumbnail_url, title, description, content, metadata, duration_ms, created_by
  )
  values (
    p_space_id, p_folder_id, p_type, coalesce(p_platform, 'device'), p_source_url, p_storage_path,
    p_thumbnail_url, coalesce(p_title, 'Untitled'), p_description, p_content,
    coalesce(p_metadata, '{}'::jsonb), p_duration_ms, auth.uid()
  )
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.create_item(uuid, uuid, text, text, text, text, text, text, text, text, jsonb, int) from public;
grant execute on function public.create_item(uuid, uuid, text, text, text, text, text, text, text, text, jsonb, int) to authenticated;

-- ---- Tags ----
create function public.create_tag(p_space_id uuid, p_name text, p_color text)
returns public.tags
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.tags;
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  insert into public.tags (space_id, name, color)
  values (p_space_id, p_name, p_color)
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.create_tag(uuid, text, text) from public;
grant execute on function public.create_tag(uuid, text, text) to authenticated;

create function public.create_tags_bulk(p_space_id uuid, p_names text[], p_colors text[])
returns setof public.tags
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  return query
    insert into public.tags (space_id, name, color)
    select p_space_id, n, c from unnest(p_names, p_colors) as t(n, c)
    returning *;
end;
$$;
revoke all on function public.create_tags_bulk(uuid, text[], text[]) from public;
grant execute on function public.create_tags_bulk(uuid, text[], text[]) to authenticated;

-- ---- Item <-> tag links ----
create function public.set_item_tags(p_item_id uuid, p_tag_ids uuid[])
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.items where items.id = p_item_id and public.is_space_member(items.space_id)
  ) then
    raise exception 'Not a member of this item''s space';
  end if;
  delete from public.item_tags where item_id = p_item_id;
  if array_length(p_tag_ids, 1) > 0 then
    insert into public.item_tags (item_id, tag_id)
    select p_item_id, t from unnest(p_tag_ids) as t;
  end if;
end;
$$;
revoke all on function public.set_item_tags(uuid, uuid[]) from public;
grant execute on function public.set_item_tags(uuid, uuid[]) to authenticated;

-- ---- Comments ----
create function public.add_comment(
  p_item_id uuid,
  p_body text,
  p_parent_id uuid,
  p_media_timestamp_ms int
)
returns public.item_comments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_space_id uuid;
  v_row public.item_comments;
begin
  select space_id into v_space_id from public.items where id = p_item_id;
  if v_space_id is null or not public.is_space_member(v_space_id) then
    raise exception 'Not a member of this item''s space';
  end if;
  insert into public.item_comments (space_id, item_id, author_id, parent_id, body, media_timestamp_ms)
  values (v_space_id, p_item_id, auth.uid(), p_parent_id, p_body, p_media_timestamp_ms)
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.add_comment(uuid, text, uuid, int) from public;
grant execute on function public.add_comment(uuid, text, uuid, int) to authenticated;

-- ---- Chats ----
create function public.create_chat(p_space_id uuid, p_name text)
returns public.chats
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.chats;
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  insert into public.chats (space_id, name, created_by)
  values (p_space_id, p_name, auth.uid())
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.create_chat(uuid, text) from public;
grant execute on function public.create_chat(uuid, text) to authenticated;

-- ---- Messages ----
create function public.send_message(
  p_space_id uuid,
  p_chat_id uuid,
  p_body text,
  p_attached_item_id uuid
)
returns public.messages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.messages;
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  insert into public.messages (space_id, chat_id, author_id, body, attached_item_id)
  values (p_space_id, p_chat_id, auth.uid(), p_body, p_attached_item_id)
  returning * into v_row;
  update public.chats set updated_at = now() where id = p_chat_id;
  return v_row;
end;
$$;
revoke all on function public.send_message(uuid, uuid, text, uuid) from public;
grant execute on function public.send_message(uuid, uuid, text, uuid) to authenticated;

-- ---- Reactions ----
-- Returns true if a reaction was added, false if an existing one was removed
-- (toggle semantics), matching the client's previous select-then-branch logic.
create function public.toggle_reaction(
  p_space_id uuid,
  p_target_type text,
  p_target_id uuid,
  p_emoji text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_existing_id uuid;
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  select id into v_existing_id from public.reactions
    where user_id = auth.uid() and target_type = p_target_type
      and target_id = p_target_id and emoji = p_emoji;
  if v_existing_id is not null then
    delete from public.reactions where id = v_existing_id;
    return false;
  end if;
  insert into public.reactions (space_id, user_id, target_type, target_id, emoji)
  values (p_space_id, auth.uid(), p_target_type, p_target_id, p_emoji);
  return true;
end;
$$;
revoke all on function public.toggle_reaction(uuid, text, uuid, text) from public;
grant execute on function public.toggle_reaction(uuid, text, uuid, text) to authenticated;

-- ---- User settings ----
create function public.upsert_user_settings(
  p_theme text,
  p_default_folder_id uuid,
  p_default_sort text,
  p_media_quality text,
  p_notifications_enabled boolean
)
returns public.user_settings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.user_settings;
begin
  insert into public.user_settings (user_id, theme, default_folder_id, default_sort, media_quality, notifications_enabled)
  values (auth.uid(), p_theme, p_default_folder_id, p_default_sort, p_media_quality, p_notifications_enabled)
  on conflict (user_id) do update set
    theme = excluded.theme,
    default_folder_id = excluded.default_folder_id,
    default_sort = excluded.default_sort,
    media_quality = excluded.media_quality,
    notifications_enabled = excluded.notifications_enabled
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.upsert_user_settings(text, uuid, text, text, boolean) from public;
grant execute on function public.upsert_user_settings(text, uuid, text, text, boolean) to authenticated;
