create type public.content_status as enum ('draft', 'published', 'archived');
create table public.cms_pages (
  id uuid primary key default gen_random_uuid(), slug text not null unique,
  title text not null, subtitle text, description text, content jsonb not null default '{}'::jsonb,
  status public.content_status not null default 'draft',
  seo_title text, seo_description text, canonical_url text, og_title text,
  og_description text, og_image_url text, robots text not null default 'index,follow',
  published_at timestamptz, created_by uuid references auth.users(id), updated_by uuid references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.faqs (
  id uuid primary key default gen_random_uuid(), question text not null, answer text not null,
  category text not null default 'General', sort_order integer not null default 0,
  status public.content_status not null default 'draft', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.testimonials (
  id uuid primary key default gen_random_uuid(), customer_name text not null, customer_role text, company text,
  review text not null, rating smallint not null check (rating between 1 and 5), profile_image_url text,
  sort_order integer not null default 0, status public.content_status not null default 'draft',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.gallery_items (
  id uuid primary key default gen_random_uuid(), title text not null, description text, media_url text not null,
  media_type text not null check (media_type in ('image','video')), category text not null,
  featured boolean not null default false, sort_order integer not null default 0,
  status public.content_status not null default 'draft', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.media_assets (
  id uuid primary key default gen_random_uuid(), file_name text not null, storage_path text not null unique,
  media_type text not null, mime_type text not null, file_size bigint not null check (file_size >= 0),
  alt_text text, title text, description text, uploaded_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create table public.navigation_items (
  id uuid primary key default gen_random_uuid(), label text not null, url text not null,
  parent_id uuid references public.navigation_items(id) on delete set null, sort_order integer not null default 0,
  is_visible boolean not null default true, opens_new_tab boolean not null default false,
  status public.content_status not null default 'draft', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.site_settings (
  key text primary key, value jsonb not null, status public.content_status not null default 'draft',
  updated_by uuid references auth.users(id), updated_at timestamptz not null default now()
);
create table public.content_versions (
  id bigint generated always as identity primary key, entity_type text not null, entity_id uuid not null,
  version_number integer not null, snapshot jsonb not null, changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now(), unique(entity_type, entity_id, version_number)
);
create or replace function public.is_content_admin() returns boolean language sql stable security definer set search_path = '' as $$ select coalesce(public.current_user_role() in ('admin','owner'), false) $$;
revoke all on function public.is_content_admin() from public;
grant execute on function public.is_content_admin() to anon, authenticated;
create or replace function public.version_cms_page() returns trigger language plpgsql security definer set search_path = '' as $$
declare next_version integer;
begin
  select coalesce(max(version_number), 0) + 1 into next_version from public.content_versions where entity_type = 'cms_page' and entity_id = new.id;
  insert into public.content_versions(entity_type, entity_id, version_number, snapshot, changed_by) values ('cms_page', new.id, next_version, to_jsonb(new), auth.uid());
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, old_value, new_value) values (auth.uid(), case when tg_op = 'INSERT' then 'created' else 'updated' end, 'cms_page', new.id::text, case when tg_op = 'INSERT' then null else to_jsonb(old) end, to_jsonb(new));
  return new;
end; $$;
create trigger cms_pages_updated_at before update on public.cms_pages for each row execute procedure public.set_updated_at();
create trigger cms_pages_version after insert or update on public.cms_pages for each row execute procedure public.version_cms_page();
create or replace function public.restore_cms_page_version(target_page uuid, target_version integer) returns public.cms_pages language plpgsql security definer set search_path = '' as $$
declare restored public.cms_pages; source jsonb;
begin
  if not public.is_content_admin() then raise exception 'insufficient_privilege'; end if;
  select snapshot into source from public.content_versions where entity_type = 'cms_page' and entity_id = target_page and version_number = target_version;
  if source is null then raise exception 'version_not_found'; end if;
  update public.cms_pages set title = source->>'title', subtitle = source->>'subtitle', description = source->>'description', content = source->'content', status = (source->>'status')::public.content_status, seo_title = source->>'seo_title', seo_description = source->>'seo_description', canonical_url = source->>'canonical_url', og_title = source->>'og_title', og_description = source->>'og_description', og_image_url = source->>'og_image_url', robots = source->>'robots', updated_by = auth.uid() where id = target_page returning * into restored;
  return restored;
end; $$;
revoke all on function public.restore_cms_page_version(uuid, integer) from public;
grant execute on function public.restore_cms_page_version(uuid, integer) to authenticated;
alter table public.cms_pages enable row level security;
alter table public.faqs enable row level security;
alter table public.testimonials enable row level security;
alter table public.gallery_items enable row level security;
alter table public.media_assets enable row level security;
alter table public.navigation_items enable row level security;
alter table public.site_settings enable row level security;
alter table public.content_versions enable row level security;
create policy "published pages are public" on public.cms_pages for select to anon, authenticated using (status = 'published' or public.is_content_admin());
create policy "content admins manage pages" on public.cms_pages for all to authenticated using (public.is_content_admin()) with check (public.is_content_admin());
create policy "published faqs are public" on public.faqs for select to anon, authenticated using (status = 'published' or public.is_content_admin());
create policy "content admins manage faqs" on public.faqs for all to authenticated using (public.is_content_admin()) with check (public.is_content_admin());
create policy "published testimonials are public" on public.testimonials for select to anon, authenticated using (status = 'published' or public.is_content_admin());
create policy "content admins manage testimonials" on public.testimonials for all to authenticated using (public.is_content_admin()) with check (public.is_content_admin());
create policy "published gallery is public" on public.gallery_items for select to anon, authenticated using (status = 'published' or public.is_content_admin());
create policy "content admins manage gallery" on public.gallery_items for all to authenticated using (public.is_content_admin()) with check (public.is_content_admin());
create policy "content admins manage media" on public.media_assets for all to authenticated using (public.is_content_admin()) with check (public.is_content_admin());
create policy "visible navigation is public" on public.navigation_items for select to anon, authenticated using ((status = 'published' and is_visible) or public.is_content_admin());
create policy "content admins manage navigation" on public.navigation_items for all to authenticated using (public.is_content_admin()) with check (public.is_content_admin());
create policy "published settings are public" on public.site_settings for select to anon, authenticated using (status = 'published' or public.is_content_admin());
create policy "content admins manage settings" on public.site_settings for all to authenticated using (public.is_content_admin()) with check (public.is_content_admin());
create policy "content admins read versions" on public.content_versions for select to authenticated using (public.is_content_admin());
grant select on public.cms_pages, public.faqs, public.testimonials, public.gallery_items, public.navigation_items, public.site_settings to anon;
grant select, insert, update, delete on public.cms_pages, public.faqs, public.testimonials, public.gallery_items, public.media_assets, public.navigation_items, public.site_settings to authenticated;
grant select on public.content_versions to authenticated;
insert into public.cms_pages(slug, title, subtitle, description, content, status, published_at) values
('home', 'Space to make something remarkable.', 'Creative production · Accra', 'A premium studio built for photography, film, podcasts, campaigns, and the teams behind them.', '{"primary_cta":{"label":"Start a booking","url":"/book"}}', 'published', now()),
('about', 'Built for ambitious ideas.', 'About Studio Two', 'Studio Two is a premium creative production studio.', '{"body":"Our full story, mission, vision, and values can be managed here."}', 'published', now());
-- Profile fields are self-editable, but roles are never accepted through generic updates.
revoke update on public.profiles from authenticated;
grant update (first_name, last_name, phone, company_name, profile_image, address, city, country, preferred_contact_method) on public.profiles to authenticated;
create or replace function public.set_profile_role(target_user uuid, new_role public.app_role) returns void language plpgsql security definer set search_path = '' as $$
declare previous_role public.app_role;
begin
  if public.current_user_role() <> 'owner' then raise exception 'insufficient_privilege'; end if;
  select role into previous_role from public.profiles where id = target_user for update;
  if previous_role is null then raise exception 'profile_not_found'; end if;
  update public.profiles set role = new_role where id = target_user;
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, old_value, new_value)
  values (auth.uid(), 'role_changed', 'profile', target_user::text, jsonb_build_object('role', previous_role), jsonb_build_object('role', new_role));
end; $$;
revoke all on function public.set_profile_role(uuid, public.app_role) from public;
grant execute on function public.set_profile_role(uuid, public.app_role) to authenticated;
