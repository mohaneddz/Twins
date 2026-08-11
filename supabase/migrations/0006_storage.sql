-- Storage buckets for avatars and per-space item media.
-- Layout: avatars/{userId}/..., spaces/{spaceId}/items/...

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('spaces', 'spaces', false)
on conflict (id) do nothing;

-- avatars: publicly readable (they're just profile pictures), but only the
-- owning user can upload/replace/delete their own.
create policy avatars_public_read on storage.objects
  for select using (bucket_id = 'avatars');

create policy avatars_owner_write on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_owner_update on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy avatars_owner_delete on storage.objects
  for delete using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- spaces: only members of the space encoded in the path (spaces/{spaceId}/...)
-- may read or write its files - matches the item/comment RLS boundary.
create policy spaces_bucket_member_read on storage.objects
  for select using (
    bucket_id = 'spaces' and public.is_space_member((storage.foldername(name))[1]::uuid)
  );

create policy spaces_bucket_member_write on storage.objects
  for insert with check (
    bucket_id = 'spaces' and public.is_space_member((storage.foldername(name))[1]::uuid)
  );

create policy spaces_bucket_member_delete on storage.objects
  for delete using (
    bucket_id = 'spaces' and public.is_space_member((storage.foldername(name))[1]::uuid)
  );
