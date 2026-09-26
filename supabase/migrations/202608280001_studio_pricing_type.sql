alter table public.studios
  add column pricing_type text not null default 'hourly'
  check (pricing_type in ('hourly', 'daily', 'fixed'));
