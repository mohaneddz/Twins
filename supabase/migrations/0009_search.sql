-- ¡Twins! search.
--
-- 0002 created an expression index over to_tsvector(title||description||content),
-- but nothing ever queried it: the client used `ilike %q%` across four columns,
-- which cannot use that index, ignores stemming, and ranks nothing. This
-- replaces it with a stored, weighted tsvector plus a trigram index so that
-- both whole-word and partial/misspelled queries are fast and ranked.

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Weighted search vector
-- ---------------------------------------------------------------------------
-- Weights: title (A) beats description (B) beats note body (C) beats the
-- source URL (D), so an item literally called "ramen" outranks one that only
-- mentions ramen in a paragraph.
alter table public.items
  add column search_vector tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(content, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(source_url, '')), 'D')
  ) stored;

drop index if exists public.items_search_idx;
create index items_search_vector_idx on public.items using gin (search_vector);

-- Trigram index for partial words and typos ("aesthet", "asthetic"), which
-- full-text search alone will not match.
create index items_title_trgm_idx on public.items using gin (title extensions.gin_trgm_ops);

-- ---------------------------------------------------------------------------
-- search_items()
-- ---------------------------------------------------------------------------
-- Returns whole item rows (same shape the client already parses) ordered by
-- relevance. Matches against the item's own text, its tag names, and its
-- folder name, so "reels" finds things filed under a folder called Reels.
--
-- SECURITY INVOKER: the caller's RLS on public.items still applies, so this
-- cannot leak another space's content even though it takes a space id.
create function public.search_items(
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
      -- websearch_to_tsquery understands quotes and OR; it also tolerates the
      -- punctuation people paste in, where plainto_tsquery would error.
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
  left join public.folders f on f.id = i.folder_id
  where i.space_id = p_space_id
    and (p_type is null or i.type = p_type)
    and (
      i.search_vector @@ q.tsq
      or i.title ilike '%' || q.raw || '%'
      or extensions.similarity(lower(i.title), q.raw) > 0.3
      or lower(coalesce(tg.names, '')) like '%' || q.raw || '%'
      or lower(coalesce(f.name, '')) like '%' || q.raw || '%'
    )
  order by
    ts_rank(i.search_vector, q.tsq) desc,
    extensions.similarity(lower(i.title), q.raw) desc,
    i.created_at desc
  limit greatest(p_limit, 1);
$$;

-- ---------------------------------------------------------------------------
-- Recent searches
-- ---------------------------------------------------------------------------
-- Per user, per space. The unique constraint plus an upsert keeps one row per
-- distinct query and lets repeat searches float to the top by searched_at
-- rather than filling the list with duplicates.
create table public.search_history (
  id uuid primary key default gen_random_uuid(),
  space_id uuid not null references public.spaces (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  query text not null check (btrim(query) <> ''),
  searched_at timestamptz not null default now(),
  unique (space_id, user_id, query)
);

create index search_history_recent_idx
  on public.search_history (space_id, user_id, searched_at desc);

alter table public.search_history enable row level security;

-- Your own history only - a twin should not see what the other one looked up.
create policy search_history_own on public.search_history
  for all using (user_id = auth.uid() and public.is_space_member(space_id))
  with check (user_id = auth.uid() and public.is_space_member(space_id));

-- Records a search and trims the list to the 20 most recent for that user.
create function public.record_search(p_space_id uuid, p_query text)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  if btrim(p_query) = '' then
    return;
  end if;

  insert into public.search_history (space_id, user_id, query)
  values (p_space_id, auth.uid(), btrim(p_query))
  on conflict (space_id, user_id, query)
    do update set searched_at = now();

  delete from public.search_history
  where space_id = p_space_id
    and user_id = auth.uid()
    and id not in (
      select id from public.search_history
      where space_id = p_space_id and user_id = auth.uid()
      order by searched_at desc
      limit 20
    );
end;
$$;
