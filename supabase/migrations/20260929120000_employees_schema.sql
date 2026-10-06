-- Milestone 3: employee management (CRUD schema).
-- Sensitive data (salary, CNSS, CIN) is split into employee_sensitive_data
-- because Postgres RLS filters rows, not columns — the only way to let a
-- plain 'member' see an employee's name but not their salary is a separate
-- table with its own policy.

-- ---------------------------------------------------------------------------
-- contract_types: reference table instead of an ENUM, so a new contract
-- type can be added with a plain INSERT, no migration. Only CDI/CDD are
-- seeded — no other type is invented without a verified legal source.
-- ---------------------------------------------------------------------------

create table public.contract_types (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  label_fr text not null,
  label_ar text not null,
  label_en text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.contract_types enable row level security;

insert into public.contract_types (code, label_fr, label_ar, label_en) values
  ('CDI', 'Contrat à durée indéterminée', 'عقد غير محدد المدة', 'Permanent contract'),
  ('CDD', 'Contrat à durée déterminée', 'عقد محدد المدة', 'Fixed-term contract');

-- ---------------------------------------------------------------------------
-- employees: non-sensitive fields, readable/writable by any org member.
-- ---------------------------------------------------------------------------

create table public.employees (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  employee_number text not null,
  first_name text not null,
  last_name text not null,
  date_of_birth date,
  nationality text,
  address text,
  phone text,
  email text,
  position text not null,
  department text,
  hire_date date not null,
  contract_type_id uuid not null references public.contract_types (id),
  employment_type text not null check (employment_type in ('full_time', 'part_time')),
  weekly_hours numeric(4, 1),
  status text not null default 'active' check (status in ('active', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.employees enable row level security;

create index employees_organization_id_idx
  on public.employees (organization_id);
create index employees_organization_status_idx
  on public.employees (organization_id, status);
create index employees_organization_name_idx
  on public.employees (organization_id, last_name, first_name);
create unique index employees_organization_employee_number_key
  on public.employees (organization_id, employee_number);

-- ---------------------------------------------------------------------------
-- employee_sensitive_data: salary, CNSS, CIN. organization_id is
-- denormalized on purpose so RLS policies here don't need a join back to
-- employees.
-- ---------------------------------------------------------------------------

create table public.employee_sensitive_data (
  employee_id uuid primary key references public.employees (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  cin text,
  salary_amount numeric(12, 2),
  salary_currency text not null default 'MAD',
  cnss_number text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.employee_sensitive_data enable row level security;

create index employee_sensitive_data_organization_id_idx
  on public.employee_sensitive_data (organization_id);
create unique index employee_sensitive_data_organization_cin_key
  on public.employee_sensitive_data (organization_id, cin)
  where cin is not null;
create unique index employee_sensitive_data_organization_cnss_key
  on public.employee_sensitive_data (organization_id, cnss_number)
  where cnss_number is not null;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

create function public.is_privileged_member_of(target_org_id uuid)
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
      and role in ('owner', 'admin')
  );
$$;

-- contract_types: global reference data, readable by any authenticated user.
create policy "contract_types_select_authenticated"
  on public.contract_types for select
  to authenticated
  using (true);

-- employees: any org member — no DELETE policy anywhere, so a hard delete
-- is impossible through the API even if the UI tried it. Archiving is the
-- only removal path, via UPDATE status = 'archived'.
create policy "employees_select_member"
  on public.employees for select
  using (public.is_member_of(organization_id));

create policy "employees_insert_member"
  on public.employees for insert
  with check (public.is_member_of(organization_id));

create policy "employees_update_member"
  on public.employees for update
  using (public.is_member_of(organization_id))
  with check (public.is_member_of(organization_id));

-- employee_sensitive_data: owner/admin only. A plain member gets an empty
-- result, not an error — the client can treat "no row" as "not authorized
-- to see salary" without a separate permission check.
create policy "employee_sensitive_data_select_privileged"
  on public.employee_sensitive_data for select
  using (public.is_privileged_member_of(organization_id));

create policy "employee_sensitive_data_insert_privileged"
  on public.employee_sensitive_data for insert
  with check (public.is_privileged_member_of(organization_id));

create policy "employee_sensitive_data_update_privileged"
  on public.employee_sensitive_data for update
  using (public.is_privileged_member_of(organization_id))
  with check (public.is_privileged_member_of(organization_id));
