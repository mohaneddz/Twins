-- Each twin picks a colour for the whole app (Settings → Our colours). It
-- lives on the profile so the other phone can draw that twin's messages,
-- plans and saves in it. The value is a key the app knows ('miku', 'sakura',
-- ...); anything it doesn't recognise falls back to the default.

alter table public.profiles add column theme_color text not null default 'miku'
  check (char_length(theme_color) between 1 and 20);

create or replace function public.twins_schema_version()
returns int
language sql
immutable
as $$ select 20 $$;
