-- ¡Twins! schema: folders (nestable) and mixed-type items.

create table public.folders (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  parent_id uuid references public.folders (id) on delete cascade,
  name text not null,
  color text not null default '0xFF8DEBD9',
  icon text not null default '📁',
  position int not null default 0,
  is_pinned boolean not null default false,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger folders_set_updated_at
  before update on public.folders
  for each row execute function extensions.moddatetime(updated_at);

create index folders_space_idx on public.folders (space_id);
create index folders_parent_idx on public.folders (parent_id);

create table public.items (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  folder_id uuid references public.folders (id) on delete set null,
  created_by uuid not null references public.profiles (id),
  type text not null check (
    type in ('reel', 'tiktok', 'youtube', 'short', 'video', 'image', 'gif', 'note', 'document', 'audio', 'link', 'other')
  ),
  platform text not null default 'device' check (platform in ('instagram', 'tiktok', 'youtube', 'web', 'device')),
  source_url text,
  storage_path text,
  thumbnail_url text,
  title text not null default 'Untitled',
  description text,
  content text,
  metadata jsonb not null default '{}'::jsonb,
  duration_ms int,
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger items_set_updated_at
  before update on public.items
  for each row execute function extensions.moddatetime(updated_at);

create index items_space_idx on public.items (space_id);
create index items_folder_idx on public.items (folder_id);
create index items_type_idx on public.items (type);
create index items_created_at_idx on public.items (created_at desc);
-- Full text search across title/description/content for the search screen.
create index items_search_idx on public.items
  using gin (to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, '') || ' ' || coalesce(content, '')));

create table public.tags (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null,
  color text not null default '0xFF7EE7E1',
  unique (space_id, name)
);

create table public.item_tags (
  item_id uuid not null references public.items (id) on delete cascade,
  tag_id uuid not null references public.tags (id) on delete cascade,
  primary key (item_id, tag_id)
);
