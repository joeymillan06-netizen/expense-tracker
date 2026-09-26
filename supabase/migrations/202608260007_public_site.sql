create table public.services (
 id uuid primary key default gen_random_uuid(),name text not null,slug text not null unique,description text,image_url text,
 price_minor bigint not null default 0 check(price_minor>=0),pricing_type text not null check(pricing_type in('hourly','daily','fixed','percentage','custom')),
 duration_minutes integer,active boolean not null default true,featured boolean not null default false,sort_order integer not null default 0,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
alter table public.services enable row level security;
create policy "active services public" on public.services for select to anon,authenticated using(active or public.is_content_admin());
create policy "admins manage services" on public.services for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
grant select on public.services to anon;
grant select,insert,update,delete on public.services to authenticated;
create trigger services_updated_at before update on public.services for each row execute procedure public.set_updated_at();
create trigger services_audit after insert or update or delete on public.services for each row execute procedure public.audit_cms_entity();
insert into public.cms_pages(slug,title,subtitle,description,content,status,published_at) values
('studio','A studio designed around the work.','The space','A flexible production environment for photography, film, podcasts, interviews, and commercial work.','{"body":"Configure the studio description, facilities, and production capabilities from the website editor."}','published',now()),
('services','Production support, shaped to your project.','Services','Build the right combination of production services for your brief.','{"body":"Published services and their current pricing appear automatically below."}','published',now()),
('pricing','Clear pricing. Flexible production.','Pricing','Studio, equipment, team, and service pricing are configured by Studio Two.','{"body":"Final pricing is calculated from the date, duration, equipment, team, services, and eligible promotions selected during booking."}','published',now()),
('contact','Let’s plan the production.','Contact','Tell Studio Two what you are making and what support you need.','{"body":"Contact details and opening information are managed from the website footer settings."}','published',now())
on conflict(slug) do nothing;
insert into public.navigation_items(label,url,sort_order,is_visible,status) values
('Studio','/studio',10,true,'published'),('Equipment','/equipment',20,true,'published'),('Services','/services',30,true,'published'),('Team','/team',40,true,'published'),('Gallery','/gallery',50,true,'published'),('Pricing','/pricing',60,true,'published'),('FAQ','/faq',70,true,'published'),('Contact','/contact',80,true,'published')
on conflict do nothing;
update public.cms_pages set content=content||'{"home_sections":{"intro_eyebrow":"One space. Full production.","intro_heading":"From first frame to final delivery.","intro_description":"Build your session around the studio, equipment, and production specialists your project actually needs.","services_eyebrow":"Production services","services_heading":"Support at every stage.","equipment_eyebrow":"Production equipment","equipment_heading":"Tools chosen for the work.","team_eyebrow":"The production team","team_heading":"Specialists, when you need them.","gallery_eyebrow":"Selected work","gallery_heading":"Made at Studio Two.","testimonial_eyebrow":"Client stories","faq_eyebrow":"Before you book","faq_heading":"Good questions deserve clear answers.","cta_heading":"Bring the idea. We’ll help build the production.","cta_label":"Book Studio Two","cta_url":"/book"}}'::jsonb where slug='home';
