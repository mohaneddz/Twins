-- ¡Twins! schema: profiles, spaces, membership (max 2), invites.
-- Enable UUID generation.
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- profiles: one row per auth user, 1:1 with auth.users
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Twin',
  username text not null default 'twin',
  avatar_path text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function extensions.moddatetime(updated_at);

-- Auto-create a profile row whenever a new auth user signs up.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, username)
  values (
    new.id,
    coalesce(split_part(new.email, '@', 1), 'Twin'),
    coalesce(split_part(new.email, '@', 1), 'twin')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- spaces: exactly one pair of two people
-- ---------------------------------------------------------------------------
create table public.spaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Our Space',
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create table public.space_members (
  space_id uuid not null references public.spaces (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (space_id, user_id),
  unique (user_id) -- a profile belongs to at most one space at a time
);

-- Hard cap of two members per space, enforced server-side (never trust the client).
create function public.enforce_space_member_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select count(*) from public.space_members where space_id = new.space_id) >= 2 then
    raise exception 'This Twins space already has two members.';
  end if;
  return new;
end;
$$;

create trigger space_members_cap
  before insert on public.space_members
  for each row execute function public.enforce_space_member_cap();

-- ---------------------------------------------------------------------------
-- space_invites: single-use, expiring 6-character codes
-- ---------------------------------------------------------------------------
create table public.space_invites (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  code text not null unique,
  created_by uuid not null references public.profiles (id),
  expires_at timestamptz not null default (now() + interval '7 days'),
  used_at timestamptz,
  used_by uuid references public.profiles (id)
);

create function public.generate_invite_code()
returns text
language plpgsql
as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  end loop;
  return result;
end;
$$;

create function public.set_invite_code()
returns trigger
language plpgsql
as $$
begin
  if new.code is null then
    new.code := public.generate_invite_code();
  end if;
  return new;
end;
$$;

create trigger space_invites_set_code
  before insert on public.space_invites
  for each row execute function public.set_invite_code();

create index space_invites_code_idx on public.space_invites (code);
