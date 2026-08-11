-- Denormalized reaction/comment counts on items, kept in sync by triggers so
-- item cards (dashboard, folder grid, search) can display counts without an
-- extra join/count query per row.

alter table public.items add column reaction_count int not null default 0;
alter table public.items add column comment_count int not null default 0;

create function public.bump_item_reaction_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    if new.target_type = 'item' then
      update public.items set reaction_count = reaction_count + 1 where id = new.target_id;
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    if old.target_type = 'item' then
      update public.items set reaction_count = greatest(reaction_count - 1, 0) where id = old.target_id;
    end if;
    return old;
  end if;
  return null;
end;
$$;

create trigger reactions_bump_item_count
  after insert or delete on public.reactions
  for each row execute function public.bump_item_reaction_count();

create function public.bump_item_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.items set comment_count = comment_count + 1 where id = new.item_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.items set comment_count = greatest(comment_count - 1, 0) where id = old.item_id;
    return old;
  end if;
  return null;
end;
$$;

create trigger item_comments_bump_count
  after insert or delete on public.item_comments
  for each row execute function public.bump_item_comment_count();
