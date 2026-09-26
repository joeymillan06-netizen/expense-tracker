insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif','video/mp4','application/pdf'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
create policy "public reads marketing media" on storage.objects for select to anon, authenticated using (bucket_id = 'media');
create policy "content admins upload media" on storage.objects for insert to authenticated with check (bucket_id = 'media' and public.is_content_admin());
create policy "content admins update media" on storage.objects for update to authenticated using (bucket_id = 'media' and public.is_content_admin()) with check (bucket_id = 'media' and public.is_content_admin());
create policy "content admins delete media" on storage.objects for delete to authenticated using (bucket_id = 'media' and public.is_content_admin());
create policy "public reads media metadata" on public.media_assets for select to anon, authenticated using (true);
grant select on public.media_assets to anon;
create trigger faqs_updated_at before update on public.faqs for each row execute procedure public.set_updated_at();
create trigger testimonials_updated_at before update on public.testimonials for each row execute procedure public.set_updated_at();
create trigger gallery_items_updated_at before update on public.gallery_items for each row execute procedure public.set_updated_at();
create trigger navigation_items_updated_at before update on public.navigation_items for each row execute procedure public.set_updated_at();
create or replace function public.audit_cms_entity() returns trigger language plpgsql security definer set search_path = '' as $$
declare row_id text;
begin
  row_id := case when tg_op = 'DELETE' then old.id::text else new.id::text end;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, old_value, new_value)
  values (auth.uid(), lower(tg_op), tg_table_name, row_id, case when tg_op = 'INSERT' then null else to_jsonb(old) end, case when tg_op = 'DELETE' then null else to_jsonb(new) end);
  return coalesce(new, old);
end; $$;
create trigger faqs_audit after insert or update or delete on public.faqs for each row execute procedure public.audit_cms_entity();
create trigger testimonials_audit after insert or update or delete on public.testimonials for each row execute procedure public.audit_cms_entity();
create trigger gallery_items_audit after insert or update or delete on public.gallery_items for each row execute procedure public.audit_cms_entity();
create trigger navigation_items_audit after insert or update or delete on public.navigation_items for each row execute procedure public.audit_cms_entity();
create trigger media_assets_audit after insert or update or delete on public.media_assets for each row execute procedure public.audit_cms_entity();
insert into public.site_settings(key, value, status) values
('footer', '{"description":"","address":"","phone":"","email":"","opening_hours":"","copyright":""}', 'draft'),
('social_links', '{}', 'draft') on conflict (key) do nothing;
