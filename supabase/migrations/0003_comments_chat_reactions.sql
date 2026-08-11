-- ¡Twins! schema: per-item comment threads (with optional media timestamp),
-- the shared Twins chat, reactions, and per-user settings.

create table public.item_comments (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  item_id uuid not null references public.items (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  parent_id uuid references public.item_comments (id) on delete cascade,
  body text not null,
  media_timestamp_ms int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger item_comments_set_updated_at
  before update on public.item_comments
  for each row execute function extensions.moddatetime(updated_at);

create index item_comments_item_idx on public.item_comments (item_id);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  body text not null default '',
  reply_to_id uuid references public.messages (id) on delete set null,
  attached_item_id uuid references public.items (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger messages_set_updated_at
  before update on public.messages
  for each row execute function extensions.moddatetime(updated_at);

create index messages_space_idx on public.messages (space_id, created_at);

create table public.reactions (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  user_id uuid not null references public.profiles (id),
  target_type text not null check (target_type in ('item', 'comment', 'message')),
  target_id uuid not null,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (user_id, target_type, target_id, emoji)
);

create index reactions_target_idx on public.reactions (target_type, target_id);

create table public.user_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  theme text not null default 'system' check (theme in ('light', 'dark', 'system')),
  default_folder_id uuid references public.folders (id) on delete set null,
  default_sort text not null default 'newest',
  media_quality text not null default 'auto',
  notifications_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger user_settings_set_updated_at
  before update on public.user_settings
  for each row execute function extensions.moddatetime(updated_at);
