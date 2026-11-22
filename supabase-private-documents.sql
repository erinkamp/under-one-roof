-- Under One Roof: run in the Supabase SQL Editor for project xmticmudzljzjeoozege.
-- Creates a PRIVATE bucket and restricts each object to its authenticated owner
-- AND to a property owned by that same account.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('home-documents','home-documents',false,10485760,
 array['application/pdf','image/jpeg','image/png','image/webp','image/heic','image/heif'])
on conflict (id) do update set public=false,file_size_limit=10485760,
allowed_mime_types=excluded.allowed_mime_types;

drop policy if exists "uor_documents_read" on storage.objects;
drop policy if exists "uor_documents_insert" on storage.objects;
drop policy if exists "uor_documents_delete" on storage.objects;

create policy "uor_documents_read" on storage.objects for select to authenticated
using (
 bucket_id='home-documents'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists (select 1 from public.homeowner_properties p
   where p.id::text=(storage.foldername(name))[2] and p.user_id=(select auth.uid()))
);

create policy "uor_documents_insert" on storage.objects for insert to authenticated
with check (
 bucket_id='home-documents'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists (select 1 from public.homeowner_properties p
   where p.id::text=(storage.foldername(name))[2] and p.user_id=(select auth.uid()))
);

create policy "uor_documents_delete" on storage.objects for delete to authenticated
using (
 bucket_id='home-documents'
 and (storage.foldername(name))[1]=(select auth.uid())::text
 and exists (select 1 from public.homeowner_properties p
   where p.id::text=(storage.foldername(name))[2] and p.user_id=(select auth.uid()))
);
