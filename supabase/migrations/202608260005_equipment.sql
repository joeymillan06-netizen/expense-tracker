create type public.equipment_status as enum ('available','unavailable','maintenance','retired');
create type public.equipment_pricing_type as enum ('hourly','daily','fixed','included');
create table public.equipment_categories (
  id uuid primary key default gen_random_uuid(), name text not null unique, slug text not null unique,
  description text, sort_order integer not null default 0, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.equipment (
  id uuid primary key default gen_random_uuid(), category_id uuid references public.equipment_categories(id) on delete set null,
  name text not null, slug text not null unique, description text, image_url text,
  total_quantity integer not null default 1 check(total_quantity>=0),
  price_minor bigint not null default 0 check(price_minor>=0), pricing_type public.equipment_pricing_type not null default 'fixed',
  status public.equipment_status not null default 'available', featured boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.equipment_maintenance (
  id uuid primary key default gen_random_uuid(), equipment_id uuid not null references public.equipment(id) on delete cascade,
  starts_at timestamptz not null, ends_at timestamptz, reason text not null, notes text,
  created_by uuid references auth.users(id), created_at timestamptz not null default now(),
  check(ends_at is null or ends_at>starts_at)
);
alter table public.equipment_categories enable row level security;
alter table public.equipment enable row level security;
alter table public.equipment_maintenance enable row level security;
create policy "active equipment categories public" on public.equipment_categories for select to anon,authenticated using(active or public.is_content_admin());
create policy "bookable equipment public" on public.equipment for select to anon,authenticated using(status='available' or public.is_content_admin());
create policy "admins manage equipment categories" on public.equipment_categories for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage equipment" on public.equipment for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage maintenance" on public.equipment_maintenance for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
grant select on public.equipment_categories,public.equipment to anon;
grant select,insert,update,delete on public.equipment_categories,public.equipment,public.equipment_maintenance to authenticated;
create trigger equipment_categories_updated_at before update on public.equipment_categories for each row execute procedure public.set_updated_at();
create trigger equipment_updated_at before update on public.equipment for each row execute procedure public.set_updated_at();
create trigger equipment_categories_audit after insert or update or delete on public.equipment_categories for each row execute procedure public.audit_cms_entity();
create trigger equipment_audit after insert or update or delete on public.equipment for each row execute procedure public.audit_cms_entity();
create trigger equipment_maintenance_audit after insert or update or delete on public.equipment_maintenance for each row execute procedure public.audit_cms_entity();
create or replace view public.equipment_inventory with (security_invoker=true) as
select e.*, 0::bigint as reserved_quantity, e.total_quantity::bigint as available_quantity
from public.equipment e;
grant select on public.equipment_inventory to anon,authenticated;
