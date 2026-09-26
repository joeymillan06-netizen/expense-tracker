create type public.pricing_rule_type as enum ('hourly','fixed','tiered','percentage','flat_fee');
create table public.studios (
  id uuid primary key default gen_random_uuid(), name text not null, slug text not null unique,
  description text, address text, timezone text not null default 'Africa/Accra',
  currency text not null default 'GHS' check (char_length(currency)=3), active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.opening_hours (
  id uuid primary key default gen_random_uuid(), studio_id uuid not null references public.studios(id) on delete cascade,
  day_of_week smallint not null check(day_of_week between 0 and 6), is_closed boolean not null default false,
  opens_at time, closes_at time, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(studio_id,day_of_week), check(is_closed or (opens_at is not null and closes_at is not null and closes_at>opens_at))
);
create table public.blocked_periods (
  id uuid primary key default gen_random_uuid(), studio_id uuid not null references public.studios(id) on delete cascade,
  starts_at timestamptz not null, ends_at timestamptz not null, reason text not null, internal_notes text,
  created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(ends_at>starts_at)
);
create table public.pricing_rules (
  id uuid primary key default gen_random_uuid(), studio_id uuid not null references public.studios(id) on delete cascade,
  name text not null, rule_type public.pricing_rule_type not null, amount_minor bigint not null check(amount_minor>=0),
  config jsonb not null default '{}'::jsonb, priority integer not null default 0,
  valid_from timestamptz, valid_until timestamptz, active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check(valid_until is null or valid_from is null or valid_until>valid_from)
);
create table public.booking_rules (
  id uuid primary key default gen_random_uuid(), studio_id uuid not null unique references public.studios(id) on delete cascade,
  minimum_duration_minutes integer not null default 60 check(minimum_duration_minutes>0),
  maximum_duration_minutes integer not null default 720 check(maximum_duration_minutes>=minimum_duration_minutes),
  booking_increment_minutes integer not null default 30 check(booking_increment_minutes>0),
  minimum_notice_hours integer not null default 24 check(minimum_notice_hours>=0),
  maximum_advance_days integer not null default 365 check(maximum_advance_days>0),
  hold_duration_minutes integer not null default 15 check(hold_duration_minutes between 5 and 120),
  cancellation_policy text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.studios enable row level security;
alter table public.opening_hours enable row level security;
alter table public.blocked_periods enable row level security;
alter table public.pricing_rules enable row level security;
alter table public.booking_rules enable row level security;
create policy "active studios public" on public.studios for select to anon,authenticated using(active or public.is_content_admin());
create policy "hours public" on public.opening_hours for select to anon,authenticated using(true);
create policy "active pricing public" on public.pricing_rules for select to anon,authenticated using(active or public.is_content_admin());
create policy "booking rules public" on public.booking_rules for select to anon,authenticated using(true);
create policy "admins manage studios" on public.studios for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage hours" on public.opening_hours for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage blocks" on public.blocked_periods for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage pricing" on public.pricing_rules for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
create policy "admins manage booking rules" on public.booking_rules for all to authenticated using(public.is_content_admin()) with check(public.is_content_admin());
grant select on public.studios,public.opening_hours,public.pricing_rules,public.booking_rules to anon;
grant select,insert,update,delete on public.studios,public.opening_hours,public.blocked_periods,public.pricing_rules,public.booking_rules to authenticated;
create trigger studios_updated_at before update on public.studios for each row execute procedure public.set_updated_at();
create trigger opening_hours_updated_at before update on public.opening_hours for each row execute procedure public.set_updated_at();
create trigger blocked_periods_updated_at before update on public.blocked_periods for each row execute procedure public.set_updated_at();
create trigger pricing_rules_updated_at before update on public.pricing_rules for each row execute procedure public.set_updated_at();
create trigger booking_rules_updated_at before update on public.booking_rules for each row execute procedure public.set_updated_at();
create trigger studios_audit after insert or update or delete on public.studios for each row execute procedure public.audit_cms_entity();
create trigger opening_hours_audit after insert or update or delete on public.opening_hours for each row execute procedure public.audit_cms_entity();
create trigger blocked_periods_audit after insert or update or delete on public.blocked_periods for each row execute procedure public.audit_cms_entity();
create trigger pricing_rules_audit after insert or update or delete on public.pricing_rules for each row execute procedure public.audit_cms_entity();
create trigger booking_rules_audit after insert or update or delete on public.booking_rules for each row execute procedure public.audit_cms_entity();
insert into public.studios(name,slug,timezone,currency) values('Studio Two','studio-two','Africa/Accra','GHS');
