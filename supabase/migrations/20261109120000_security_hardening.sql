-- Security audit corrective migration (does not modify or drop any
-- existing table, migration file, or data — only ADD CONSTRAINT /
-- ALTER POLICY / CREATE OR REPLACE FUNCTION / CREATE FUNCTION+TRIGGER).
--
-- Before applying to a database with existing rows, check for rows that
-- would violate the new composite foreign keys below — if any exist,
-- they must be fixed manually first, because ADD CONSTRAINT will refuse
-- to apply over data that violates it (safe failure, not data loss):
--
--   select esd.employee_id, esd.organization_id, e.organization_id as employee_actual_org
--   from public.employee_sensitive_data esd
--   join public.employees e on e.id = esd.employee_id
--   where esd.organization_id is distinct from e.organization_id;
--
--   select cr.id, cr.organization_id, e.organization_id as employee_actual_org
--   from public.calculation_runs cr
--   join public.employees e on e.id = cr.employee_id
--   where cr.organization_id is distinct from e.organization_id;
--
--   select crr.id, crr.organization_id, cr.organization_id as run_actual_org
--   from public.calculation_run_rules crr
--   join public.calculation_runs cr on cr.id = crr.calculation_run_id
--   where crr.organization_id is distinct from cr.organization_id;

-- ---------------------------------------------------------------------------
-- 1. Composite foreign keys: an organization_id column next to a FK into
--    a child row is only trustworthy if the database itself guarantees it
--    matches that child row's real organization_id. Before this, RLS
--    policies checked the organization_id *value a client supplied*, not
--    whether it actually matched the referenced employee/run — so a
--    privileged user of Org B could, by supplying Org A's employee_id,
--    attach sensitive data or a calculation run to Org A's employee while
--    it stayed scoped to Org B's own RLS visibility. These constraints
--    close that at the data layer, independent of any RLS policy logic.
-- ---------------------------------------------------------------------------

alter table public.employees
  add constraint employees_id_organization_id_key unique (id, organization_id);

alter table public.employee_sensitive_data
  add constraint employee_sensitive_data_employee_org_fkey
  foreign key (employee_id, organization_id)
  references public.employees (id, organization_id);

alter table public.calculation_runs
  add constraint calculation_runs_employee_org_fkey
  foreign key (employee_id, organization_id)
  references public.employees (id, organization_id);

alter table public.calculation_runs
  add constraint calculation_runs_id_organization_id_key unique (id, organization_id);

-- calculation_run_rules' INSERT policy already verifies this via an
-- exists() check; this is added for defense-in-depth independent of RLS
-- (e.g. a direct migration/SQL Editor write bypassing RLS entirely).
alter table public.calculation_run_rules
  add constraint calculation_run_rules_run_org_fkey
  foreign key (calculation_run_id, organization_id)
  references public.calculation_runs (id, organization_id);

-- ---------------------------------------------------------------------------
-- 2. RLS policies left unrestricted on role: every policy below had no
--    `to authenticated` clause, meaning it technically applied to PUBLIC
--    (including the `anon` role), not just signed-in users. In practice
--    `auth.uid()` is NULL for `anon`, so is_member_of()/is_owner_of()/
--    is_privileged_member_of() already return false for it today — but
--    that safety was incidental, not declared. ALTER POLICY only narrows
--    the role list; it changes no data and no USING/WITH CHECK logic.
-- ---------------------------------------------------------------------------

alter policy "profiles_select_own" on public.profiles to authenticated;
alter policy "profiles_update_own" on public.profiles to authenticated;

alter policy "organizations_select_member" on public.organizations to authenticated;
alter policy "organizations_update_owner" on public.organizations to authenticated;

alter policy "organization_members_select_member" on public.organization_members to authenticated;

alter policy "employees_select_member" on public.employees to authenticated;
alter policy "employees_insert_member" on public.employees to authenticated;
alter policy "employees_update_member" on public.employees to authenticated;

alter policy "employee_sensitive_data_select_privileged" on public.employee_sensitive_data to authenticated;
alter policy "employee_sensitive_data_insert_privileged" on public.employee_sensitive_data to authenticated;
alter policy "employee_sensitive_data_update_privileged" on public.employee_sensitive_data to authenticated;

alter policy "calculation_runs_select_member" on public.calculation_runs to authenticated;
alter policy "calculation_runs_insert_member" on public.calculation_runs to authenticated;

alter policy "calculation_run_rules_select_member" on public.calculation_run_rules to authenticated;
alter policy "calculation_run_rules_insert_member" on public.calculation_run_rules to authenticated;

-- ---------------------------------------------------------------------------
-- 3. legal_rules immutability: the existing trigger blocked editing
--    rule_definition / effective_from / input_schema_version while
--    status was VERIFIED/ACTIVE, but did NOT block moving status back to
--    an earlier stage first — which would have reopened those same
--    fields to editing on a second statement (old.status would then be
--    e.g. 'DRAFT', outside the guarded set). This widens the protected
--    field list and blocks status regression out of VERIFIED/ACTIVE.
--
--    effective_until is intentionally NOT protected — closing an
--    open-ended ACTIVE rule's validity window (when a successor version
--    is introduced) is a legitimate, expected edit even post-VERIFIED,
--    and the existing exclusion constraint still prevents it from
--    creating an overlap with any other version.
--
--    Note: there is still no client-side UPDATE policy on legal_rules at
--    all, so today this trigger only guards direct migration/SQL Editor
--    writes, not the public API — it is tightened here anyway so that
--    path is not silently weaker than intended once any write path to
--    legal_rules is added later (e.g. an admin panel).
-- ---------------------------------------------------------------------------

create or replace function public.prevent_verified_rule_mutation()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status in ('VERIFIED', 'ACTIVE') then
    if new.rule_definition is distinct from old.rule_definition
      or new.effective_from is distinct from old.effective_from
      or new.input_schema_version is distinct from old.input_schema_version
      or new.legal_source_id is distinct from old.legal_source_id
      or new.jurisdiction is distinct from old.jurisdiction
      or new.verified_by is distinct from old.verified_by
      or new.verified_at is distinct from old.verified_at
    then
      raise exception
        'legal_rules: rule_definition, effective_from, input_schema_version, '
        'legal_source_id, jurisdiction, verified_by, and verified_at are '
        'immutable once a row is VERIFIED or ACTIVE — create a new version instead.';
    end if;

    if new.status is distinct from old.status
      and new.status not in ('VERIFIED', 'ACTIVE')
    then
      raise exception
        'legal_rules: cannot move status from % back to % — once VERIFIED, '
        'a rule can only advance to ACTIVE, never regress.', old.status, new.status;
    end if;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. SECURITY DEFINER helper functions: tighten EXECUTE to `authenticated`
--    only. These already return boolean-only / RLS-filtered results, so
--    this closes unnecessary surface rather than a live exploit.
--
--    REVOKE ... FROM PUBLIC alone is not enough: Supabase provisions new
--    functions in `public` with explicit per-role grants (anon,
--    authenticated, service_role) via ALTER DEFAULT PRIVILEGES at project
--    creation — those are separate, independently-held grants, not
--    inherited from PUBLIC. Revoking from PUBLIC does not touch a grant
--    held directly by `anon`, so `anon` must be revoked explicitly too.
--    `service_role` is left untouched on purpose: it already bypasses RLS
--    entirely, so restricting EXECUTE on a boolean helper function would
--    not reduce what it can actually access.
-- ---------------------------------------------------------------------------

revoke execute on function public.is_member_of(uuid) from public;
revoke execute on function public.is_member_of(uuid) from anon;
grant execute on function public.is_member_of(uuid) to authenticated;

revoke execute on function public.is_owner_of(uuid) from public;
revoke execute on function public.is_owner_of(uuid) from anon;
grant execute on function public.is_owner_of(uuid) to authenticated;

revoke execute on function public.is_privileged_member_of(uuid) from public;
revoke execute on function public.is_privileged_member_of(uuid) from anon;
grant execute on function public.is_privileged_member_of(uuid) to authenticated;

revoke execute on function public.get_applicable_rule(text, date) from public;
revoke execute on function public.get_applicable_rule(text, date) from anon;
grant execute on function public.get_applicable_rule(text, date) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. employees.organization_id must never change after creation. Without
--    this, the composite FKs above only protect an employee once it has
--    at least one employee_sensitive_data/calculation_runs row — an
--    employee with no child rows yet could still be reassigned to a
--    different organization_id by anyone privileged in both (e.g. a user
--    who legitimately belongs to two organizations). RLS cannot restrict
--    a single column within an UPDATE policy (it filters rows, not
--    columns — the same reason employee_sensitive_data is a separate
--    table), so this needs a trigger, same pattern as
--    prevent_verified_rule_mutation() above.
-- ---------------------------------------------------------------------------

create function public.prevent_employee_organization_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.organization_id is distinct from old.organization_id then
    raise exception 'employees.organization_id cannot be changed after creation';
  end if;
  return new;
end;
$$;

create trigger employees_prevent_organization_change
  before update on public.employees
  for each row execute function public.prevent_employee_organization_change();
