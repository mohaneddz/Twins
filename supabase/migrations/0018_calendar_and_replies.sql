-- The shared calendar, plus replies and plan cards in chat.
--
-- A plan belongs to the space, so both twins see and edit every one. It can
-- point at a saved item ("watch this together") and at the chat it was made
-- in. Cancelling keeps the row (cancelled_at) so the twin's phone can still be
-- told what was called off and drop its reminder.
--
-- Reminders fire from each phone's own alarm (scheduled locally from this
-- table), so nothing here runs on a timer.

create table public.events (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  created_by uuid not null references public.profiles (id),
  updated_by uuid references public.profiles (id),
  title text not null check (char_length(title) between 1 and 200),
  notes text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  all_day boolean not null default false,
  -- Minutes before the start to remind both twins; null means no reminder.
  -- All-day plans count from 09:00 on the day.
  remind_minutes int check (remind_minutes is null or remind_minutes between 0 and 43200),
  item_id uuid references public.items (id) on delete set null,
  chat_id uuid references public.chats (id) on delete set null,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at is null or ends_at >= starts_at)
);

create index events_space_start_idx on public.events (space_id, starts_at);

alter table public.events enable row level security;

create policy events_select on public.events
  for select using (public.is_space_member(space_id));
create policy events_update on public.events
  for update using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));
create policy events_delete on public.events
  for delete using (public.is_space_member(space_id));

-- Same INSERT workaround as 0013.
create function public.create_event(
  p_space_id uuid,
  p_title text,
  p_starts_at timestamptz,
  p_ends_at timestamptz default null,
  p_all_day boolean default false,
  p_remind_minutes int default null,
  p_notes text default null,
  p_item_id uuid default null,
  p_chat_id uuid default null
)
returns public.events
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.events;
begin
  if not public.is_space_member(p_space_id) then
    raise exception 'Not a member of this space';
  end if;
  insert into public.events (space_id, created_by, title, notes, starts_at, ends_at, all_day, remind_minutes, item_id, chat_id)
  values (p_space_id, auth.uid(), p_title, nullif(p_notes, ''), p_starts_at, p_ends_at, p_all_day, p_remind_minutes, p_item_id, p_chat_id)
  returning * into v_row;
  return v_row;
end;
$$;
revoke all on function public.create_event(uuid, text, timestamptz, timestamptz, boolean, int, text, uuid, uuid) from public, anon;
grant execute on function public.create_event(uuid, text, timestamptz, timestamptz, boolean, int, text, uuid, uuid) to authenticated;

create function public.touch_event()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  return new;
end;
$$;

create trigger events_touch before update on public.events
  for each row execute function public.touch_event();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'events'
  ) then
    alter publication supabase_realtime add table public.events;
  end if;
end;
$$;

-- ---- Chat: plan cards and replies ----
alter table public.messages add column attached_event_id uuid references public.events (id) on delete set null;

drop function public.send_message(uuid, uuid, text, uuid);

create function public.send_message(
  p_space_id uuid,
  p_chat_id uuid,
  p_body text,
  p_attached_item_id uuid default null,
  p_reply_to_id uuid default null,
  p_attached_event_id uuid default null
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
  if p_reply_to_id is not null and not exists (
    select 1 from public.messages where id = p_reply_to_id and chat_id = p_chat_id
  ) then
    raise exception 'Can only reply to a message in the same chat';
  end if;
  insert into public.messages (space_id, chat_id, author_id, body, attached_item_id, reply_to_id, attached_event_id)
  values (p_space_id, p_chat_id, auth.uid(), p_body, p_attached_item_id, p_reply_to_id, p_attached_event_id)
  returning * into v_row;
  update public.chats set updated_at = now() where id = p_chat_id;
  return v_row;
end;
$$;
revoke all on function public.send_message(uuid, uuid, text, uuid, uuid, uuid) from public, anon;
grant execute on function public.send_message(uuid, uuid, text, uuid, uuid, uuid) to authenticated;

create or replace function public.twins_schema_version()
returns int
language sql
immutable
as $$ select 18 $$;
