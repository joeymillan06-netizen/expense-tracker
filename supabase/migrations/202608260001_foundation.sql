create type public.app_role as enum ('customer', 'staff', 'manager', 'admin', 'owner');
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '', last_name text not null default '',
  email text not null, phone text, company_name text, profile_image text,
  address text, city text, country text, preferred_contact_method text,
  role public.app_role not null default 'customer',
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null, entity_type text not null, entity_id text,
  old_value jsonb, new_value jsonb, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create or replace function public.current_user_role() returns public.app_role language sql stable security definer set search_path = '' as $$ select role from public.profiles where id = auth.uid() $$;
revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, first_name, last_name)
  values (new.id, coalesce(new.email, ''), coalesce(new.raw_user_meta_data ->> 'first_name', ''), coalesce(new.raw_user_meta_data ->> 'last_name', ''));
  return new;
end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.set_updated_at() returns trigger language plpgsql set search_path = '' as $$ begin new.updated_at = now(); return new; end; $$;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();
alter table public.profiles enable row level security;
alter table public.audit_logs enable row level security;
create policy "profiles read own" on public.profiles for select to authenticated using (id = auth.uid());
create policy "profiles update own safe fields" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid() and role = public.current_user_role());
create policy "admins read profiles" on public.profiles for select to authenticated using (public.current_user_role() in ('admin', 'owner'));
create policy "owners manage profiles" on public.profiles for update to authenticated using (public.current_user_role() = 'owner') with check (public.current_user_role() = 'owner');
create policy "admins read audit logs" on public.audit_logs for select to authenticated using (public.current_user_role() in ('admin', 'owner'));
revoke all on public.profiles, public.audit_logs from anon;
grant select, update on public.profiles to authenticated;
grant select on public.audit_logs to authenticated;
comment on table public.audit_logs is 'Append-only audit events. Inserts are performed only by trusted server functions added with each domain.';
