create extension if not exists btree_gist;
create type public.staff_status as enum ('active','unavailable','leave','archived');
create type public.staff_pricing_type as enum ('hourly','daily','fixed','per_booking');
create table public.staff_categories (
 id uuid primary key default gen_random_uuid(),name text not null unique,slug text not null unique,description text,
 sort_order integer not null default 0,active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.staff_members (
 id uuid primary key default gen_random_uuid(),category_id uuid references public.staff_categories(id) on delete set null,
 name text not null,slug text not null unique,profile_photo_url text,bio text,role_title text,email text,phone text,
 base_price_minor bigint not null default 0 check(base_price_minor>=0),pricing_type public.staff_pricing_type not null default 'per_booking',
 status public.staff_status not null default 'active',featured boolean not null default false,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.staff_unavailability (
 id uuid primary key default gen_random_uuid(),staff_id uuid not null references public.staff_members(id) on delete cascade,
 starts_at timestamptz not null,ends_at timestamptz not null,reason text not null,created_by uuid references auth.users(id),
 created_at timestamptz not null default now(),check(ends_at>starts_at)
);
create table public.staff_assignments (
 id uuid primary key default gen_random_uuid(),staff_id uuid not null references public.staff_members(id) on delete restrict,
 booking_reference uuid not null,starts_at timestamptz not null,ends_at timestamptz not null,
 status text not null check(status in('held','confirmed','released','cancelled')),expires_at timestamptz,created_at timestamptz not null default now(),check(ends_at>starts_at),
 exclude using gist(staff_id with =,tstzrange(starts_at,ends_at,'[)') with &&) where(status in('held','confirmed'))
);
create table public.booking_purposes (
 id uuid primary key default gen_random_uuid(),name text not null unique,slug text not null unique,description text,
 sort_order integer not null default 0,active boolean not null default true,created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
create table public.production_requirement_rules (
 id uuid primary key default gen_random_uuid(),purpose_id uuid not null references public.booking_purposes(id) on delete cascade,
 staff_category_id uuid not null references public.staff_categories(id) on delete cascade,recommended_quantity integer not null default 1 check(recommended_quantity>=0),
 minimum_quantity integer not null default 0 check(minimum_quantity>=0),maximum_quantity integer not null default 1 check(maximum_quantity>=minimum_quantity),
 required boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(purpose_id,staff_category_id)
);
alter table public.staff_categories enable row level security;
alter table public.staff_members enable row level security;
alter table public.staff_unavailability enable row level security;
alter table public.staff_assignments enable row level security;
alter table public.booking_purposes enable row level security;
alter table public.production_requirement_rules enable row level security;
create policy "active staff categories public" on public.staff_categories for select to anon,authenticated using(active or public.is_content_admin());
create policy "active staff public" on public.staff_members for select to anon,authenticated using(status='active' or public.is_content_admin());
create policy "active purposes public" on public.booking_purposes for select to anon,authenticated using(active or public.is_content_admin());
create policy "recommendations public" on public.production_requirement_rules for select to anon,authenticated using(true);
create policy "admins manage staff categories" on public.staff_categories for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage staff" on public.staff_members for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage staff unavailability" on public.staff_unavailability for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins read staff assignments" on public.staff_assignments for select to authenticated using(public.is_content_admin());
create policy "admins manage purposes" on public.booking_purposes for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage recommendations" on public.production_requirement_rules for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
grant select on public.staff_categories,public.staff_members,public.booking_purposes,public.production_requirement_rules to anon;
grant select,insert,update,delete on public.staff_categories,public.staff_members,public.staff_unavailability,public.booking_purposes,public.production_requirement_rules to authenticated;
grant select on public.staff_assignments to authenticated;
create trigger staff_categories_updated_at before update on public.staff_categories for each row execute procedure public.set_updated_at();
create trigger staff_members_updated_at before update on public.staff_members for each row execute procedure public.set_updated_at();
create trigger booking_purposes_updated_at before update on public.booking_purposes for each row execute procedure public.set_updated_at();
create trigger production_rules_updated_at before update on public.production_requirement_rules for each row execute procedure public.set_updated_at();
create trigger staff_categories_audit after insert or update or delete on public.staff_categories for each row execute procedure public.audit_cms_entity();
create trigger staff_members_audit after insert or update or delete on public.staff_members for each row execute procedure public.audit_cms_entity();
create trigger staff_unavailability_audit after insert or update or delete on public.staff_unavailability for each row execute procedure public.audit_cms_entity();
create trigger staff_assignments_audit after insert or update or delete on public.staff_assignments for each row execute procedure public.audit_cms_entity();
create trigger booking_purposes_audit after insert or update or delete on public.booking_purposes for each row execute procedure public.audit_cms_entity();
create trigger production_rules_audit after insert or update or delete on public.production_requirement_rules for each row execute procedure public.audit_cms_entity();
create or replace function public.staff_is_available(target_staff uuid,target_start timestamptz,target_end timestamptz) returns boolean language sql stable security definer set search_path='' as $$ select exists(select 1 from public.staff_members s where s.id=target_staff and s.status='active') and not exists(select 1 from public.staff_unavailability u where u.staff_id=target_staff and u.starts_at<target_end and u.ends_at>target_start) and not exists(select 1 from public.staff_assignments a where a.staff_id=target_staff and a.starts_at<target_end and a.ends_at>target_start and (a.status='confirmed' or(a.status='held' and a.expires_at>now()))) $$;
revoke all on function public.staff_is_available(uuid,timestamptz,timestamptz) from public;
grant execute on function public.staff_is_available(uuid,timestamptz,timestamptz) to authenticated;
