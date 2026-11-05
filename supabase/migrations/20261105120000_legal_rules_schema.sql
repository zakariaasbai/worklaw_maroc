-- Milestone 5 Partie B: legal rule governance (sources, versioned rules,
-- immutable calculation snapshots). NO rule or source is seeded here —
-- every row will be added later by a human, via migration or SQL Editor,
-- after legal verification (see CLAUDE.md "RÈGLE ABSOLUE").
--
-- No internal "platform staff" role exists yet, so there are deliberately
-- no client-side write policies on legal_sources / legal_rules — see
-- DATABASE.md for how rows get in until the admin panel ships.

create extension if not exists btree_gist;

-- ---------------------------------------------------------------------------
-- legal_sources
-- ---------------------------------------------------------------------------

create table public.legal_sources (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  reference text not null,
  url_or_citation text not null,
  jurisdiction text not null default 'MA',
  source_type text,
  language text check (language in ('fr', 'ar', 'en')),
  published_at date,
  effective_date date,
  last_verified_at timestamptz,
  status text not null default 'ACTIVE'
    check (status in ('ACTIVE', 'SUPERSEDED', 'REPEALED')),
  added_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

alter table public.legal_sources enable row level security;

-- ---------------------------------------------------------------------------
-- legal_rules: one row per version of a rule. Guardrails below are DB
-- constraints/triggers on purpose — the goal is that a non-VERIFIED rule
-- can never be used in production, enforced even if the application code
-- has a bug, not just by convention.
-- ---------------------------------------------------------------------------

create table public.legal_rules (
  id uuid primary key default gen_random_uuid(),
  rule_key text not null,
  version integer not null,
  status text not null default 'DRAFT'
    check (status in ('DRAFT', 'SOURCE_FOUND', 'REVIEWED', 'VERIFIED', 'ACTIVE')),
  jurisdiction text not null default 'MA',
  legal_source_id uuid references public.legal_sources (id),
  effective_from date not null,
  effective_until date,
  input_schema_version text not null,
  rule_definition jsonb not null,
  verified_by uuid references public.profiles (id),
  verified_at timestamptz,
  verified_by_name text,
  verification_notes text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint legal_rules_source_required_past_draft
    check (status = 'DRAFT' or legal_source_id is not null),

  constraint legal_rules_verification_required
    check (
      status not in ('VERIFIED', 'ACTIVE')
      or (verified_by is not null and verified_at is not null)
    ),

  constraint legal_rules_valid_period
    check (effective_until is null or effective_until > effective_from),

  constraint legal_rules_rule_key_version_key unique (rule_key, version)
);

alter table public.legal_rules enable row level security;

-- No two periods of the same rule_key may overlap, regardless of status —
-- catches a bad draft before it ever gets close to VERIFIED.
alter table public.legal_rules
  add constraint legal_rules_no_overlapping_periods
  exclude using gist (
    rule_key with =,
    daterange(effective_from, coalesce(effective_until, 'infinity'::date), '[)') with &&
  );

-- rule_definition / effective_from / input_schema_version become
-- immutable once a row has been VERIFIED or ACTIVE — a real change means a
-- new version (new row), not editing history out from under past
-- calculation_runs that reference this exact row.
create function public.prevent_verified_rule_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status in ('VERIFIED', 'ACTIVE') then
    if new.rule_definition is distinct from old.rule_definition
      or new.effective_from is distinct from old.effective_from
      or new.input_schema_version is distinct from old.input_schema_version
    then
      raise exception
        'legal_rules: rule_definition, effective_from, and input_schema_version '
        'are immutable once a row is VERIFIED or ACTIVE — create a new version instead.';
    end if;
  end if;
  return new;
end;
$$;

create trigger legal_rules_prevent_verified_mutation
  before update on public.legal_rules
  for each row execute function public.prevent_verified_rule_mutation();

-- ---------------------------------------------------------------------------
-- legal_rules_active: status filter ONLY, no date filter. security_invoker
-- means it enforces the querying role's own RLS on legal_rules rather than
-- the view owner's — it is not a privilege escalation path.
-- ---------------------------------------------------------------------------

create view public.legal_rules_active
with (security_invoker = true) as
  select * from public.legal_rules where status = 'ACTIVE';

-- Date-aware lookup: the version of a rule that was in force on a given
-- date (so recomputing a historical calculation reuses the exact version
-- that applied at the time, not whatever is active today).
create function public.get_applicable_rule(p_rule_key text, p_on_date date)
returns public.legal_rules
language sql
stable
set search_path = public
as $$
  select *
  from public.legal_rules_active
  where rule_key = p_rule_key
    and effective_from <= p_on_date
    and (effective_until is null or effective_until > p_on_date)
  order by effective_from desc
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- calculation_runs + calculation_run_rules: immutable snapshot of a
-- calculation. A run can use more than one rule (e.g. a solde de tout
-- compte combining a préavis rule and an indemnité rule), hence the child
-- table rather than a single legal_rule_id column.
-- ---------------------------------------------------------------------------

create table public.calculation_runs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  employee_id uuid not null references public.employees (id),
  calculator_key text not null,
  calculator_version text not null,
  input_snapshot jsonb not null,
  result_snapshot jsonb not null,
  calculated_by uuid not null references public.profiles (id),
  calculated_at timestamptz not null default now()
);

alter table public.calculation_runs enable row level security;

create index calculation_runs_organization_id_idx
  on public.calculation_runs (organization_id);
create index calculation_runs_employee_id_idx
  on public.calculation_runs (employee_id);

create table public.calculation_run_rules (
  id uuid primary key default gen_random_uuid(),
  calculation_run_id uuid not null references public.calculation_runs (id) on delete cascade,
  legal_rule_id uuid not null references public.legal_rules (id),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  unique (calculation_run_id, legal_rule_id)
);

alter table public.calculation_run_rules enable row level security;

create index calculation_run_rules_calculation_run_id_idx
  on public.calculation_run_rules (calculation_run_id);
create index calculation_run_rules_organization_id_idx
  on public.calculation_run_rules (organization_id);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

-- legal_sources: readable by any authenticated user. No client-side
-- INSERT/UPDATE/DELETE policy — rows are added via migration or the
-- Supabase SQL Editor until an internal platform_staff role exists
-- (see DATABASE.md).
create policy "legal_sources_select_authenticated"
  on public.legal_sources for select
  to authenticated
  using (true);

-- legal_rules: only ACTIVE rows are readable by a normal authenticated
-- user — DRAFT/SOURCE_FOUND/REVIEWED/VERIFIED stay invisible to the API
-- entirely, not just filtered out of the app's UI. Same "no client write
-- policy" reasoning as legal_sources.
create policy "legal_rules_select_active_only"
  on public.legal_rules for select
  to authenticated
  using (status = 'ACTIVE');

-- calculation_runs / calculation_run_rules: any org member, read + insert
-- only — no UPDATE, no DELETE policy anywhere, so a calculation snapshot
-- can never be altered or removed through the API once created.
create policy "calculation_runs_select_member"
  on public.calculation_runs for select
  using (public.is_member_of(organization_id));

-- calculated_by must be the inserting user — otherwise a member could
-- attribute a calculation to someone else in the same organization.
create policy "calculation_runs_insert_member"
  on public.calculation_runs for insert
  with check (
    public.is_member_of(organization_id)
    and calculated_by = auth.uid()
  );

create policy "calculation_run_rules_select_member"
  on public.calculation_run_rules for select
  using (public.is_member_of(organization_id));

-- organization_id alone isn't enough to check here: a member could claim
-- their own organization_id while pointing calculation_run_id at another
-- organization's run. The exists() clause confirms the referenced run
-- actually belongs to that same organization.
create policy "calculation_run_rules_insert_member"
  on public.calculation_run_rules for insert
  with check (
    public.is_member_of(organization_id)
    and exists (
      select 1 from public.calculation_runs cr
      where cr.id = calculation_run_rules.calculation_run_id
        and cr.organization_id = calculation_run_rules.organization_id
    )
  );
