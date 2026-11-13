#!/usr/bin/env bash
# Milestone 5 Partie B — DB-level guardrails on legal_rules: these are
# constraints/triggers, not application code, so they hold even if a
# future bug in the app tries to bypass them.
#
# Every scenario runs inside BEGIN/ROLLBACK — nothing here is committed,
# and no legal rule or source is left behind. Uses the direct Postgres
# connection (SUPABASE_DB_URL) since this tests raw DB behavior, not RLS.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh, plus
# `bash supabase/tests/tools/provision_test_users.sh` run at least once (the
# PROFILE_ID below just needs to be a valid, stable profiles.id to
# satisfy created_by/added_by FKs — every scenario runs in its own
# BEGIN/ROLLBACK anyway, so reusing the same profile across runs is
# fine).
# Run: bash supabase/tests/legal_rules_constraints_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

expect_fail() {
  local sql="$1" expected_substring="$2" description="$3"
  local output
  output=$(cat <<SQL | psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 2>&1
begin;
$sql
rollback;
SQL
  ) || true
  [[ "$output" == *"$expected_substring"* ]] || \
    fail "$description — expected error containing '$expected_substring', got: $output"
  pass "$description"
}

expect_success() {
  local sql="$1" description="$2"
  if ! cat <<SQL | psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -q 2>&1
begin;
$sql
rollback;
SQL
  then
    fail "$description — expected this to succeed"
  fi
  pass "$description"
}

# --- Setup: a real, stable profile id to satisfy created_by/added_by FKs ---
PASSWORD="$TEST_USER_PASSWORD"
EMAIL="stable-legalrules@worklaw-test.test"
TOKEN=$(json_field "$(signin "$EMAIL" "$PASSWORD")" "access_token")
[ -n "$TOKEN" ] || fail "could not sign in as $EMAIL — run tools/provision_test_users.sh first?"
PROFILE_ID=$(psql_scalar "select id from public.profiles where email = '$EMAIL';")
[ -n "$PROFILE_ID" ] || fail "setup: could not resolve profile id"

RULE_KEY="test_rule_$(date +%s)"

# --- Test 1: legal_source_id required from SOURCE_FOUND onward ---
expect_fail "
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by)
  values
    ('${RULE_KEY}_a', 1, 'SOURCE_FOUND', null, '2024-01-01', 'v1', '{}', '$PROFILE_ID');
" "legal_rules_source_required_past_draft" \
  "SOURCE_FOUND without legal_source_id is rejected"

expect_success "
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by)
  values
    ('${RULE_KEY}_a', 1, 'DRAFT', null, '2024-01-01', 'v1', '{}', '$PROFILE_ID');
" "DRAFT without legal_source_id is allowed"

# --- Test 2: verified_by / verified_at required from VERIFIED onward ---
expect_fail "
  insert into public.legal_sources (title, reference, url_or_citation, added_by)
  values ('Test source', 'Art. 1', 'https://example.test', '$PROFILE_ID')
  returning id;
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by)
  select '${RULE_KEY}_b', 1, 'VERIFIED', id, '2024-01-01', 'v1', '{}', '$PROFILE_ID'
  from public.legal_sources where title = 'Test source' limit 1;
" "legal_rules_verification_required" \
  "VERIFIED without verified_by/verified_at is rejected"

# --- Test 3: rule_definition immutable once VERIFIED ---
expect_fail "
  insert into public.legal_sources (title, reference, url_or_citation, added_by)
  values ('Test source 2', 'Art. 2', 'https://example.test/2', '$PROFILE_ID');
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by, verified_by, verified_at)
  select '${RULE_KEY}_c', 1, 'VERIFIED', ls.id, '2024-01-01', 'v1', '{\"value\": 1}'::jsonb, '$PROFILE_ID', '$PROFILE_ID', now()
  from public.legal_sources ls where ls.title = 'Test source 2';
  update public.legal_rules set rule_definition = '{\"value\": 2}'::jsonb where rule_key = '${RULE_KEY}_c';
" "immutable once a row is VERIFIED or ACTIVE" \
  "rule_definition cannot be changed once VERIFIED"

# --- Test 4: no overlapping periods for the same rule_key ---
expect_fail "
  insert into public.legal_sources (title, reference, url_or_citation, added_by)
  values ('Test source 3', 'Art. 3', 'https://example.test/3', '$PROFILE_ID');
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, effective_until, input_schema_version, rule_definition, created_by)
  select '${RULE_KEY}_d', 1, 'DRAFT', ls.id, '2024-01-01', '2025-01-01', 'v1', '{}', '$PROFILE_ID'
  from public.legal_sources ls where ls.title = 'Test source 3';
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, effective_until, input_schema_version, rule_definition, created_by)
  select '${RULE_KEY}_d', 2, 'DRAFT', ls.id, '2024-06-01', null, 'v1', '{}', '$PROFILE_ID'
  from public.legal_sources ls where ls.title = 'Test source 3';
" "legal_rules_no_overlapping_periods" \
  "two overlapping periods for the same rule_key are rejected"

# --- Test 5: get_applicable_rule() returns the version in force at a past date ---
expect_success "
  insert into public.legal_sources (title, reference, url_or_citation, added_by)
  values ('Test source 5', 'Art. 5', 'https://example.test/5', '$PROFILE_ID');
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, effective_until, input_schema_version, rule_definition, created_by, verified_by, verified_at)
  select '${RULE_KEY}_e', 1, 'ACTIVE', ls.id, '2020-01-01', '2023-01-01', 'v1', '{\"n\": 1}'::jsonb, '$PROFILE_ID', '$PROFILE_ID', now()
  from public.legal_sources ls where ls.title = 'Test source 5';
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, effective_until, input_schema_version, rule_definition, created_by, verified_by, verified_at)
  select '${RULE_KEY}_e', 2, 'ACTIVE', ls.id, '2023-01-01', null, 'v1', '{\"n\": 2}'::jsonb, '$PROFILE_ID', '$PROFILE_ID', now()
  from public.legal_sources ls where ls.title = 'Test source 5';
  do \$\$
  declare
    v_old jsonb;
    v_new jsonb;
  begin
    select rule_definition into v_old from public.get_applicable_rule('${RULE_KEY}_e', '2021-06-01');
    select rule_definition into v_new from public.get_applicable_rule('${RULE_KEY}_e', '2024-06-01');
    if v_old->>'n' != '1' then
      raise exception 'expected version 1 (n=1) for a 2021 date, got %', v_old;
    end if;
    if v_new->>'n' != '2' then
      raise exception 'expected version 2 (n=2) for a 2024 date, got %', v_new;
    end if;
  end;
  \$\$;
" "get_applicable_rule() resolves the version that was in force at a past date, not today's"

# --- Test 6 (security audit hardening): status cannot regress out of
#     VERIFIED/ACTIVE. Before this fix, flipping status back to DRAFT was
#     allowed by the trigger (it only guarded the protected fields), which
#     would have reopened rule_definition/effective_from/
#     input_schema_version to editing on a second statement. ---
expect_fail "
  insert into public.legal_sources (title, reference, url_or_citation, added_by)
  values ('Test source 6', 'Art. 6', 'https://example.test/6', '$PROFILE_ID');
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by, verified_by, verified_at)
  select '${RULE_KEY}_f', 1, 'ACTIVE', ls.id, '2024-01-01', 'v1', '{}', '$PROFILE_ID', '$PROFILE_ID', now()
  from public.legal_sources ls where ls.title = 'Test source 6';
  update public.legal_rules set status = 'DRAFT' where rule_key = '${RULE_KEY}_f';
" "cannot move status from ACTIVE back to DRAFT" \
  "status cannot regress from ACTIVE back to DRAFT"

# --- Test 7 (security audit hardening): verified_by / verified_at become
#     immutable too once VERIFIED/ACTIVE — otherwise the audit trail of
#     who verified a rule and when could be silently overwritten. ---
expect_fail "
  insert into public.legal_sources (title, reference, url_or_citation, added_by)
  values ('Test source 7', 'Art. 7', 'https://example.test/7', '$PROFILE_ID');
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by, verified_by, verified_at)
  select '${RULE_KEY}_g', 1, 'VERIFIED', ls.id, '2024-01-01', 'v1', '{}', '$PROFILE_ID', '$PROFILE_ID', now()
  from public.legal_sources ls where ls.title = 'Test source 7';
  update public.legal_rules set verified_at = now() + interval '1 day' where rule_key = '${RULE_KEY}_g';
" "immutable once a row is VERIFIED or ACTIVE" \
  "verified_at cannot be changed once VERIFIED"

echo "All legal_rules constraint tests passed."
