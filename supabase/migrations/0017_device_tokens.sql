-- Push notification tokens: one row per phone, owned by the signed-in twin.
-- The `notify` edge function reads the other twin's tokens to address a
-- push; tokens Firebase reports as dead are deleted there, and a phone drops
-- its own on log out, so the table only ever holds live devices.

create table public.device_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  updated_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

alter table public.device_tokens enable row level security;

create policy device_tokens_own on public.device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Security definer for the same reason as 0012/0013: plain client INSERTs
-- are rejected on this stack even when the policy holds. A token that moves
-- to another account (same phone, other twin signs in) follows the caller.
create function public.register_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  insert into public.device_tokens (token, user_id) values (p_token, auth.uid())
  on conflict (token) do update set user_id = auth.uid(), updated_at = now();
end;
$$;

create function public.unregister_device_token(p_token text)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.device_tokens where token = p_token and user_id = auth.uid();
$$;

revoke all on function public.register_device_token(text) from public, anon;
revoke all on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

create or replace function public.twins_schema_version()
returns int
language sql
immutable
as $$ select 17 $$;
