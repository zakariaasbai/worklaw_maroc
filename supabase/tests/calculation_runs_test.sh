#!/usr/bin/env bash
# Milestone 5 Partie B — calculation_runs / calculation_run_rules:
# multi-tenant isolation (same pattern as Milestone 3's employees
# isolation test) and immutability (no UPDATE/DELETE policy anywhere, so
# a calculation snapshot can never be altered or removed through the API).
#
# The one legal_rules fixture row needed for the FK is created via
# SUPABASE_DB_URL (no client write path exists for legal_rules — that's
# intentional, see the migration). Everything else goes through the anon
# key + real JWTs, like the Flutter app would.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh.
# Run: bash supabase/tests/calculation_runs_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="Passw0rd!23"
EMAIL_A="calcrun-a-$(date +%s)@test.local"
EMAIL_B="calcrun-b-$(date +%s)@test.local"
signup "$EMAIL_A" "$PASSWORD" "Owner A" "CalcRun Org A" >/dev/null
signup "$EMAIL_B" "$PASSWORD" "Owner B" "CalcRun Org B" >/dev/null

TOKEN_A=$(json_field "$(signin "$EMAIL_A" "$PASSWORD")" "access_token")
TOKEN_B=$(json_field "$(signin "$EMAIL_B" "$PASSWORD")" "access_token")
[ -n "$TOKEN_A" ] && [ -n "$TOKEN_B" ] || fail "could not sign in test users"

PROFILE_A=$(psql_scalar "select id from public.profiles where email = '$EMAIL_A';")
PROFILE_B=$(psql_scalar "select id from public.profiles where email = '$EMAIL_B';")
ORG_A=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_A")")" "id")
ORG_B=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_B")")" "id")
CDI_ID=$(json_field "$(rest_body "$(rest GET "contract_types?code=eq.CDI&select=id" "$TOKEN_A")")" "id")
[ -n "$PROFILE_A" ] && [ -n "$PROFILE_B" ] && [ -n "$ORG_A" ] && [ -n "$ORG_B" ] && [ -n "$CDI_ID" ] || \
  fail "setup: could not resolve profile/org/CDI id"

EMP_BODY="{\"organization_id\":\"$ORG_A\",\"employee_number\":\"EMP-CALC-1\",\"first_name\":\"Nadia\",\"last_name\":\"Idrissi\",\"position\":\"Dev\",\"hire_date\":\"2021-01-01\",\"contract_type_id\":\"$CDI_ID\",\"employment_type\":\"full_time\"}"
EMP_RESP=$(rest POST "employees" "$TOKEN_A" "$EMP_BODY")
[ "$(rest_status "$EMP_RESP")" = "201" ] || fail "setup: could not create employee: $(rest_body "$EMP_RESP")"
EMP_ID=$(json_field "$(rest_body "$EMP_RESP")" "id")

RULE_KEY="calcrun_rule_$(date +%s)"
RULE_ID=$(psql_scalar "
  insert into public.legal_sources (title, reference, url_or_citation, added_by)
  values ('CalcRun fixture source', 'Art. 7', 'https://example.test/7', '$PROFILE_A');
  insert into public.legal_rules
    (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by, verified_by, verified_at)
  select '$RULE_KEY', 1, 'ACTIVE', ls.id, '2024-01-01', 'v1', '{}', '$PROFILE_A', '$PROFILE_A', now()
  from public.legal_sources ls where ls.title = 'CalcRun fixture source'
  returning id;
")
[ -n "$RULE_ID" ] || fail "setup: could not create legal_rules fixture row"

# --- A forged calculated_by (someone else's profile id) must be rejected ---
FORGED_BODY="{\"organization_id\":\"$ORG_A\",\"employee_id\":\"$EMP_ID\",\"calculator_key\":\"test_calc\",\"calculator_version\":\"v1\",\"input_snapshot\":{\"x\":1},\"result_snapshot\":{\"y\":2},\"calculated_by\":\"$PROFILE_B\"}"
FORGED_RESP=$(rest POST "calculation_runs" "$TOKEN_A" "$FORGED_BODY")
FORGED_STATUS=$(rest_status "$FORGED_RESP")
[ "$FORGED_STATUS" != "201" ] || fail "insert with calculated_by != auth.uid() should have been rejected, got HTTP 201"
pass "calculation_runs insert with a forged calculated_by (not the inserting user) is rejected"

# --- Security audit (Milestone 5 hardening): org B must not be able to
#     create a calculation_runs row pointing employee_id at org A's
#     employee while declaring organization_id = org B. Before the
#     composite FK fix, only organization_id was checked, so this
#     succeeded — a client-reachable cross-org data integrity issue, not
#     just a theoretical one. ---
XORG_BODY="{\"organization_id\":\"$ORG_B\",\"employee_id\":\"$EMP_ID\",\"calculator_key\":\"test_calc\",\"calculator_version\":\"v1\",\"input_snapshot\":{\"x\":1},\"result_snapshot\":{\"y\":2},\"calculated_by\":\"$PROFILE_B\"}"
XORG_RESP=$(rest POST "calculation_runs" "$TOKEN_B" "$XORG_BODY")
[ "$(rest_status "$XORG_RESP")" != "201" ] || \
  fail "org B was able to create a calculation run against org A's employee (cross-org FK missing): $(rest_body "$XORG_RESP")"
pass "calculation_runs insert referencing another organization's employee is rejected"

# --- A creates a calculation run + attaches the fixture rule ---
RUN_BODY="{\"organization_id\":\"$ORG_A\",\"employee_id\":\"$EMP_ID\",\"calculator_key\":\"test_calc\",\"calculator_version\":\"v1\",\"input_snapshot\":{\"x\":1},\"result_snapshot\":{\"y\":2},\"calculated_by\":\"$PROFILE_A\"}"
RUN_RESP=$(rest POST "calculation_runs" "$TOKEN_A" "$RUN_BODY")
[ "$(rest_status "$RUN_RESP")" = "201" ] || fail "org A could not create a calculation run: $(rest_body "$RUN_RESP")"
RUN_ID=$(json_field "$(rest_body "$RUN_RESP")" "id")
[ -n "$RUN_ID" ] || fail "no calculation run id returned"
pass "org A can create a calculation run"

RULE_LINK_BODY="{\"calculation_run_id\":\"$RUN_ID\",\"legal_rule_id\":\"$RULE_ID\",\"organization_id\":\"$ORG_A\"}"
RULE_LINK_RESP=$(rest POST "calculation_run_rules" "$TOKEN_A" "$RULE_LINK_BODY")
[ "$(rest_status "$RULE_LINK_RESP")" = "201" ] || fail "org A could not attach a rule to the run: $(rest_body "$RULE_LINK_RESP")"
pass "org A can attach a rule to its calculation run (calculation_run_rules)"

# --- Isolation: org B must not see org A's run or its rule links ---
B_RUN_READ=$(rest_body "$(rest GET "calculation_runs?id=eq.$RUN_ID" "$TOKEN_B")")
[ "$B_RUN_READ" = "[]" ] || fail "org B could read org A's calculation run: $B_RUN_READ"
pass "org B cannot read org A's calculation run"

B_RULE_LINK_READ=$(rest_body "$(rest GET "calculation_run_rules?calculation_run_id=eq.$RUN_ID" "$TOKEN_B")")
[ "$B_RULE_LINK_READ" = "[]" ] || fail "org B could read org A's calculation_run_rules: $B_RULE_LINK_READ"
pass "org B cannot read org A's calculation_run_rules"

# --- Immutability: no UPDATE, no DELETE, even for the owning org ---
rest PATCH "calculation_runs?id=eq.$RUN_ID" "$TOKEN_A" '{"calculator_version":"v2-tampered"}' >/dev/null
A_RECHECK=$(rest_body "$(rest GET "calculation_runs?id=eq.$RUN_ID&select=calculator_version" "$TOKEN_A")")
[[ "$A_RECHECK" != *"v2-tampered"* ]] || fail "calculation_runs was updated despite no UPDATE policy: $A_RECHECK"
pass "calculation_runs cannot be updated (no UPDATE policy) — even by the owning org"

rest DELETE "calculation_runs?id=eq.$RUN_ID" "$TOKEN_A" >/dev/null
STILL_THERE=$(rest_body "$(rest GET "calculation_runs?id=eq.$RUN_ID&select=id" "$TOKEN_A")")
[[ "$STILL_THERE" == *"$RUN_ID"* ]] || fail "calculation_runs row disappeared after DELETE attempt"
pass "calculation_runs cannot be deleted (no DELETE policy) — even by the owning org"

echo "All calculation_runs tests passed."
