-- Chats get re-named as the conversation moves on: the first name after N
-- messages, then a fresh one every Y messages (both chosen in the app). A
-- name typed by hand is 'manual' and never touched again.

alter table public.chats add column name_source text check (name_source in ('auto', 'manual'));
alter table public.chats add column named_at_count int;

-- Existing names came from the one-shot auto-namer (manual renames were
-- rare); let them refresh from their current length.
update public.chats c
set name_source = 'auto',
    named_at_count = (select count(*) from public.messages m where m.chat_id = c.id)
where c.name is not null;

create or replace function public.twins_schema_version()
returns int
language sql
immutable
as $$ select 16 $$;
