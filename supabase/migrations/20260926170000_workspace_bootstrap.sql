create or replace function public.bootstrap_finance_workspace(member_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  existing_workspace uuid;
  new_workspace uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select workspace_id into existing_workspace
  from public.workspace_members
  where user_id = auth.uid()
  limit 1;

  if existing_workspace is not null then
    return existing_workspace;
  end if;

  insert into public.workspaces (name)
  values ('Our Financial Home')
  returning id into new_workspace;

  insert into public.workspace_members (workspace_id, user_id, display_name, role)
  values (new_workspace, auth.uid(), member_name, 'owner');

  insert into public.workspace_state (workspace_id, payload, updated_by)
  values (new_workspace, '{}'::jsonb, auth.uid());

  return new_workspace;
end;
$$;

revoke all on function public.bootstrap_finance_workspace(text) from public;
grant execute on function public.bootstrap_finance_workspace(text) to authenticated;
