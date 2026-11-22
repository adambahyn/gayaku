-- The cutout bucket was public so the client could call getPublicUrl(); that
-- made every garment photo readable by anyone holding the URL, with the owner
-- uid and item id in the path. Private + signed URLs instead, and the bucket
-- now refuses anything that is not a bounded image.
update storage.buckets
set public = false,
    file_size_limit = 2097152,
    allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp']
where id = 'cutouts';

-- Reads still go through the owner-folder policy; signed URLs are minted
-- server-side and are not subject to it.
drop policy if exists "cutouts are readable by their owner" on storage.objects;

create policy "cutouts are readable by their owner"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'cutouts'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
