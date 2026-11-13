#!/usr/bin/env bash
# Milestone 3 — multi-tenant isolation: organization B must not be able to
# read or modify organization A's employees, even when it knows the
# employee's id.
#
# Uses stable, pre-provisioned accounts (see tools/provision_test_users.sh)
# and signs in — no signup here, so this never touches the email
# rate limit.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh, plus
# `bash supabase/tests/tools/provision_test_users.sh` run at least once.
# Run: bash supabase/tests/employees_isolation_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="$TEST_USER_PASSWORD"
EMAIL_A="stable-isolation-a@worklaw-test.test"
EMAIL_B="stable-isolation-b@worklaw-test.test"

TOKEN_A=$(json_field "$(signin "$EMAIL_A" "$PASSWORD")" "access_token")
TOKEN_B=$(json_field "$(signin "$EMAIL_B" "$PASSWORD")" "access_token")
[ -n "$TOKEN_A" ] && [ -n "$TOKEN_B" ] || fail "could not sign in test users — run tools/provision_test_users.sh first?"

ORG_A=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_A")")" "id")
CDI_ID=$(json_field "$(rest_body "$(rest GET "contract_types?code=eq.CDI&select=id" "$TOKEN_A")")" "id")
[ -n "$ORG_A" ] && [ -n "$CDI_ID" ] || fail "setup: could not resolve org A / CDI id"

CREATE_BODY="{\"organization_id\":\"$ORG_A\",\"employee_number\":\"EMP-ISO-$(date +%s)\",\"first_name\":\"Youssef\",\"last_name\":\"Amrani\",\"position\":\"Technicien\",\"hire_date\":\"2023-06-01\",\"contract_type_id\":\"$CDI_ID\",\"employment_type\":\"full_time\"}"
CREATE_RESP=$(rest POST "employees" "$TOKEN_A" "$CREATE_BODY")
[ "$(rest_status "$CREATE_RESP")" = "201" ] || fail "setup: could not create employee in org A: $(rest_body "$CREATE_RESP")"
EMP_ID=$(json_field "$(rest_body "$CREATE_RESP")" "id")
[ -n "$EMP_ID" ] || fail "setup: no employee id returned"

B_READ=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID" "$TOKEN_B")")
[ "$B_READ" = "[]" ] || fail "org B could read org A's employee: $B_READ"
pass "org B cannot read org A's employee"

rest PATCH "employees?id=eq.$EMP_ID" "$TOKEN_B" '{"department":"Hacked"}' >/dev/null
A_RECHECK=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID&select=department" "$TOKEN_A")")
[[ "$A_RECHECK" != *"Hacked"* ]] || fail "org B was able to modify org A's employee"
pass "org B cannot modify org A's employee"

echo "All employees isolation tests passed."
