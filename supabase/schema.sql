create extension if not exists pgcrypto;

create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Our Financial Home',
  created_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null,
  role text not null default 'member' check (role in ('owner','member')),
  primary key (workspace_id,user_id)
);

create table if not exists public.workspace_state (
  workspace_id uuid primary key references public.workspaces(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id)
);

alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.workspace_state enable row level security;

create policy "members can read workspace" on public.workspaces for select to authenticated
using (exists (select 1 from public.workspace_members m where m.workspace_id=id and m.user_id=auth.uid()));

create policy "members can read membership" on public.workspace_members for select to authenticated
using (user_id=auth.uid());

create policy "members can read state" on public.workspace_state for select to authenticated
using (exists (select 1 from public.workspace_members m where m.workspace_id=workspace_state.workspace_id and m.user_id=auth.uid()));

create policy "members can insert state" on public.workspace_state for insert to authenticated
with check (exists (select 1 from public.workspace_members m where m.workspace_id=workspace_state.workspace_id and m.user_id=auth.uid()));

create policy "members can update state" on public.workspace_state for update to authenticated
using (exists (select 1 from public.workspace_members m where m.workspace_id=workspace_state.workspace_id and m.user_id=auth.uid()))
with check (exists (select 1 from public.workspace_members m where m.workspace_id=workspace_state.workspace_id and m.user_id=auth.uid()));
