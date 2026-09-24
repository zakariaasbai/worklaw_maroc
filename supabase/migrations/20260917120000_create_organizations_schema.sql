-- Milestone 2: authentication + organization account
-- profiles / organizations / organization_members, signup trigger, RLS.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.organizations enable row level security;

create table public.organization_members (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  role text not null default 'owner' check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default now(),
  unique (organization_id, profile_id)
);

alter table public.organization_members enable row level security;

create index organization_members_profile_id_idx
  on public.organization_members (profile_id);
create index organization_members_organization_id_idx
  on public.organization_members (organization_id);

-- ---------------------------------------------------------------------------
-- Signup trigger: creates profile + organization + owner membership
-- atomically with the auth.users insert. Any exception raised here rolls
-- back the whole signup transaction, so a user can never end up without an
-- organization.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_full_name text;
  v_organization_name text;
  v_organization_id uuid;
begin
  v_full_name := trim(new.raw_user_meta_data ->> 'full_name');
  v_organization_name := trim(new.raw_user_meta_data ->> 'organization_name');

  if v_full_name is null or v_full_name = '' then
    raise exception 'full_name is required';
  end if;

  if char_length(v_full_name) > 200 then
    raise exception 'full_name must be 200 characters or fewer';
  end if;

  if v_organization_name is null or v_organization_name = '' then
    raise exception 'organization_name is required';
  end if;

  if char_length(v_organization_name) > 200 then
    raise exception 'organization_name must be 200 characters or fewer';
  end if;

  insert into public.profiles (id, full_name, email)
  values (new.id, v_full_name, new.email);

  insert into public.organizations (name, created_by)
  values (v_organization_name, new.id)
  returning id into v_organization_id;

  insert into public.organization_members (organization_id, profile_id, role)
  values (v_organization_id, new.id, 'owner');

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- RLS: deny-by-default. Only SELECT (and own-row UPDATE on profiles) is
-- granted to the authenticated role; every other write path is closed for
-- now (creation goes through the SECURITY DEFINER trigger above; future
-- writes such as invitations will go through dedicated RPC functions).
-- ---------------------------------------------------------------------------

create function public.is_member_of(target_org_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members
    where organization_id = target_org_id
      and profile_id = auth.uid()
  );
$$;

create function public.is_owner_of(target_org_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.organization_members
    where organization_id = target_org_id
      and profile_id = auth.uid()
      and role = 'owner'
  );
$$;

-- profiles
create policy "profiles_select_own"
  on public.profiles for select
  using (id = auth.uid());

create policy "profiles_update_own"
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid());

-- organizations
create policy "organizations_select_member"
  on public.organizations for select
  using (public.is_member_of(id));

create policy "organizations_update_owner"
  on public.organizations for update
  using (public.is_owner_of(id))
  with check (public.is_owner_of(id));

-- organization_members
create policy "organization_members_select_member"
  on public.organization_members for select
  using (public.is_member_of(organization_id));
