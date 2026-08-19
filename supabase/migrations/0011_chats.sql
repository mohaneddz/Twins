-- ¡Twins! chat threads: a space can now hold multiple named conversations
-- instead of one flat message stream. Messages belong to a chat; chats
-- belong to a space. Existing messages get backfilled into one default
-- chat per space so no history is orphaned.

create table public.chats (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger chats_set_updated_at
  before update on public.chats
  for each row execute function extensions.moddatetime(updated_at);

create index chats_space_idx on public.chats (space_id, updated_at desc);

alter table public.messages add column chat_id uuid references public.chats (id) on delete cascade;

do $$
declare
  s record;
  new_chat_id uuid;
begin
  for s in select distinct space_id from public.messages where chat_id is null loop
    insert into public.chats (space_id, created_by)
      select s.space_id, created_by from public.spaces where id = s.space_id
      returning id into new_chat_id;
    update public.messages set chat_id = new_chat_id where space_id = s.space_id and chat_id is null;
  end loop;
end $$;

alter table public.messages alter column chat_id set not null;

create index messages_chat_idx on public.messages (chat_id, created_at);

alter table public.chats enable row level security;
create policy chats_all_member on public.chats
  for all using (public.is_space_member(space_id)) with check (public.is_space_member(space_id));

-- Stream chats over Realtime the same way messages/folders/items already are.
alter table public.chats replica identity full;
alter publication supabase_realtime add table public.chats;
