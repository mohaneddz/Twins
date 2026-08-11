-- Denormalized item count per folder, kept in sync by triggers so folder
-- cards (dashboard, folder grid, "manage folders") can show "N items" without
-- an extra count query per folder. Mirrors the reaction/comment counters in
-- 0007. Counts only DIRECT children of a folder (items whose folder_id is it),
-- not nested subfolders' items.

alter table public.folders add column item_count int not null default 0;

-- Backfill existing rows.
update public.folders f
set item_count = (select count(*) from public.items i where i.folder_id = f.id);

create function public.bump_folder_item_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.folder_id is not null then
      update public.folders set item_count = item_count + 1 where id = new.folder_id;
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if old.folder_id is not null then
      update public.folders set item_count = greatest(item_count - 1, 0) where id = old.folder_id;
    end if;
    return old;
  elsif tg_op = 'UPDATE' then
    -- item moved between folders (or in/out of a folder)
    if old.folder_id is distinct from new.folder_id then
      if old.folder_id is not null then
        update public.folders set item_count = greatest(item_count - 1, 0) where id = old.folder_id;
      end if;
      if new.folder_id is not null then
        update public.folders set item_count = item_count + 1 where id = new.folder_id;
      end if;
    end if;
    return new;
  end if;
  return null;
end;
$$;

create trigger items_bump_folder_count
  after insert or delete or update of folder_id on public.items
  for each row execute function public.bump_folder_item_count();
