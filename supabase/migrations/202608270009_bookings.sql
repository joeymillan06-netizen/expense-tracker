create type public.booking_status as enum ('pending','confirmed','cancelled','completed');
create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  studio_id uuid not null references public.studios(id) on delete restrict,
  purpose_id uuid references public.booking_purposes(id) on delete set null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  notes text,
  status public.booking_status not null default 'pending',
  estimated_amount_minor integer not null default 0 check (estimated_amount_minor >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index bookings_customer_idx on public.bookings(customer_id,starts_at);
create index bookings_studio_time_idx on public.bookings(studio_id,starts_at,ends_at);
alter table public.bookings enable row level security;
create policy "customers read own bookings" on public.bookings for select to authenticated using(customer_id=auth.uid() or public.is_content_admin());
create policy "customers create own bookings" on public.bookings for insert to authenticated with check(customer_id=auth.uid());
create policy "admins manage bookings" on public.bookings for update to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
grant select,insert,update on public.bookings to authenticated;
create trigger bookings_updated_at before update on public.bookings for each row execute procedure public.set_updated_at();
create trigger bookings_audit after insert or update or delete on public.bookings for each row execute procedure public.audit_cms_entity();
