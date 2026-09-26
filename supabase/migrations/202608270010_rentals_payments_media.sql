alter table public.studios add column cover_image_url text;
alter table public.equipment add column specifications text;
create table public.studio_images (
 id uuid primary key default gen_random_uuid(), studio_id uuid not null references public.studios(id) on delete cascade,
 image_url text not null, alt_text text, sort_order integer not null default 0, created_at timestamptz not null default now()
);
create table public.booking_equipment (
 id uuid primary key default gen_random_uuid(), booking_id uuid not null references public.bookings(id) on delete cascade,
 equipment_id uuid not null references public.equipment(id) on delete restrict, quantity integer not null default 1 check(quantity>0),
 amount_minor bigint not null default 0 check(amount_minor>=0), unique(booking_id,equipment_id)
);
create type public.rental_status as enum ('awaiting_payment','paid','ready','collected','returned','cancelled');
create table public.equipment_rentals (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.profiles(id) on delete cascade,
 equipment_id uuid not null references public.equipment(id) on delete restrict, quantity integer not null check(quantity>0),
 starts_at timestamptz not null, ends_at timestamptz not null, total_minor bigint not null check(total_minor>=0),
 ghana_card_path text not null, status public.rental_status not null default 'awaiting_payment',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(ends_at>starts_at)
);
create type public.payment_status as enum ('pending','paid','failed','refunded');
create table public.payments (
 id uuid primary key default gen_random_uuid(), customer_id uuid not null references public.profiles(id) on delete cascade,
 entity_type text not null check(entity_type in ('booking','equipment_rental')), entity_id uuid not null,
 reference text not null unique, amount_minor bigint not null check(amount_minor>0), currency text not null default 'GHS',
 provider text not null default 'paystack', status public.payment_status not null default 'pending', paid_at timestamptz,
 provider_response jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('identity-documents','identity-documents',false,8388608,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
alter table public.studio_images enable row level security;
alter table public.booking_equipment enable row level security;
alter table public.equipment_rentals enable row level security;
alter table public.payments enable row level security;
create policy "studio images public" on public.studio_images for select to anon,authenticated using(true);
create policy "admins manage studio images" on public.studio_images for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "booking equipment participants read" on public.booking_equipment for select to authenticated using(exists(select 1 from public.bookings b where b.id=booking_id and (b.customer_id=auth.uid() or public.is_content_admin())));
create policy "customers add booking equipment" on public.booking_equipment for insert to authenticated with check(exists(select 1 from public.bookings b where b.id=booking_id and b.customer_id=auth.uid()));
create policy "rentals participants read" on public.equipment_rentals for select to authenticated using(customer_id=auth.uid() or public.is_content_admin());
create policy "customers create rentals" on public.equipment_rentals for insert to authenticated with check(customer_id=auth.uid());
create policy "admins update rentals" on public.equipment_rentals for update to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "payments participants read" on public.payments for select to authenticated using(customer_id=auth.uid() or public.is_content_admin());
grant select on public.studio_images to anon;
grant select,insert,update,delete on public.studio_images,public.booking_equipment,public.equipment_rentals,public.payments to authenticated;
create trigger equipment_rentals_updated_at before update on public.equipment_rentals for each row execute procedure public.set_updated_at();
create trigger payments_updated_at before update on public.payments for each row execute procedure public.set_updated_at();
