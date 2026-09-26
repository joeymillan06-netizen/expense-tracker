create or replace function public.has_permission(required_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
    public.current_user_role() in ('admin','owner') or
    (public.current_user_role() in ('staff','manager') and (auth.jwt() -> 'app_metadata' -> 'permissions') ? required_permission),
    false
  )
$$;
revoke all on function public.has_permission(text) from public;
grant execute on function public.has_permission(text) to authenticated;
create or replace function public.is_content_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
    public.current_user_role() in ('admin','owner') or
    (public.current_user_role() in ('staff','manager') and jsonb_array_length(coalesce(auth.jwt() -> 'app_metadata' -> 'permissions','[]'::jsonb)) > 0),
    false
  )
$$;
create policy "permitted staff read profiles" on public.profiles for select to authenticated
using (public.has_permission('customers') or public.has_permission('staff'));
