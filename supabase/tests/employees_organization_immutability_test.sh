#!/usr/bin/env bash
# Security audit (Milestone 5 hardening) — employees.organization_id must
# never change after creation (see
# prevent_employee_organization_change() in
# 20261109120000_security_hardening.sql). Checks both directions: the
# change itself is rejected, and a normal field update on the same row
# still works (the trigger targets organization_id specifically, not
# every update).
#
# Uses stable, pre-provisioned accounts (see tools/provision_test_users.sh)
# and signs in — no signup here, so this never touches the email
# rate limit.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh, plus
# `bash supabase/tests/tools/provision_test_users.sh` run at least once.
# Run: bash supabase/tests/employees_organization_immutability_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="$TEST_USER_PASSWORD"
EMAIL_A="stable-orgimmut-a@worklaw-test.test"
EMAIL_B="stable-orgimmut-b@worklaw-test.test"

TOKEN_A=$(json_field "$(signin "$EMAIL_A" "$PASSWORD")" "access_token")
TOKEN_B=$(json_field "$(signin "$EMAIL_B" "$PASSWORD")" "access_token")
[ -n "$TOKEN_A" ] && [ -n "$TOKEN_B" ] || fail "could not sign in test users — run tools/provision_test_users.sh first?"

PROFILE_A=$(psql_scalar "select id from public.profiles where email = '$EMAIL_A';")
ORG_A=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_A")")" "id")
ORG_B=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_B")")" "id")
CDI_ID=$(json_field "$(rest_body "$(rest GET "contract_types?code=eq.CDI&select=id" "$TOKEN_A")")" "id")
[ -n "$PROFILE_A" ] && [ -n "$ORG_A" ] && [ -n "$ORG_B" ] && [ -n "$CDI_ID" ] || \
  fail "setup: could not resolve profile/org/CDI id"

# Make PROFILE_A a privileged member of ORG_B too, via the direct DB
# connection — simulates the one realistic case where this trigger
# actually matters (a user legitimately privileged in two organizations).
# ON CONFLICT DO NOTHING: both accounts are stable, so this membership
# may already exist from a previous run.
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -q -c \
  "insert into public.organization_members (organization_id, profile_id, role) values ('$ORG_B', '$PROFILE_A', 'admin') on conflict (organization_id, profile_id) do nothing;"

EMP_BODY="{\"organization_id\":\"$ORG_A\",\"employee_number\":\"EMP-IMMUT-$(date +%s)\",\"first_name\":\"Samir\",\"last_name\":\"Tazi\",\"position\":\"Dev\",\"hire_date\":\"2022-01-01\",\"contract_type_id\":\"$CDI_ID\",\"employment_type\":\"full_time\"}"
EMP_RESP=$(rest POST "employees" "$TOKEN_A" "$EMP_BODY")
[ "$(rest_status "$EMP_RESP")" = "201" ] || fail "setup: could not create employee: $(rest_body "$EMP_RESP")"
EMP_ID=$(json_field "$(rest_body "$EMP_RESP")" "id")
[ -n "$EMP_ID" ] || fail "setup: no employee id returned"

# --- Attempt to reassign organization_id (A is privileged in both orgs) ---
REASSIGN_RESP=$(rest PATCH "employees?id=eq.$EMP_ID" "$TOKEN_A" "{\"organization_id\":\"$ORG_B\"}")
rest_status "$REASSIGN_RESP" >/dev/null
STILL_ORG_A=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID&select=organization_id" "$TOKEN_A")")
[[ "$STILL_ORG_A" == *"$ORG_A"* ]] || fail "employee organization_id was changed: $STILL_ORG_A"
[[ "$STILL_ORG_A" != *"$ORG_B"* ]] || fail "employee organization_id was changed to org B: $STILL_ORG_A"
pass "employees.organization_id cannot be changed, even by a user privileged in both organizations"

# --- A normal field update on the same row must still work ---
UPDATE_RESP=$(rest PATCH "employees?id=eq.$EMP_ID" "$TOKEN_A" '{"department":"Finance"}')
[ "$(rest_status "$UPDATE_RESP")" = "200" ] || fail "normal field update failed: $(rest_body "$UPDATE_RESP")"
DEPARTMENT_CHECK=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID&select=department" "$TOKEN_A")")
[[ "$DEPARTMENT_CHECK" == *'"department":"Finance"'* ]] || fail "department update did not persist: $DEPARTMENT_CHECK"
pass "a normal field update (department) on the same employee still succeeds"

echo "All employees organization immutability tests passed."
