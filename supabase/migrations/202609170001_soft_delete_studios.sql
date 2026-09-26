alter table public.studios add column if not exists deleted_at timestamptz;
alter table public.studios drop constraint if exists studios_slug_key;
drop index if exists public.studios_slug_key;
create unique index if not exists studios_active_slug_unique
  on public.studios (slug)
  where deleted_at is null;
