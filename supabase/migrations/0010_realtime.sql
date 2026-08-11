-- Enable Supabase Realtime for the tables the client subscribes to via
-- `.stream()`. Without membership in the supabase_realtime publication, the
-- Dart client's stream() yields nothing, so folders/items/chat/etc. render
-- empty against the real backend even though the rows exist and RLS allows
-- reading them.
--
-- REPLICA IDENTITY FULL: the client's stream(...).eq('space_id', ...) filter
-- must be applied to DELETE events too. Postgres only ships the primary key on
-- delete by default, so without FULL the space_id isn't present and deletes
-- wouldn't match the filter (stale rows lingering in the UI). FULL makes the
-- old row available on update/delete.

do $$
declare
  t text;
  streamed text[] := array[
    'folders', 'items', 'tags', 'item_tags',
    'item_comments', 'messages', 'reactions'
  ];
begin
  foreach t in array streamed loop
    execute format('alter table public.%I replica identity full', t);
    -- add to the publication if not already a member
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
