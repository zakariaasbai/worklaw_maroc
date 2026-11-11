#!/usr/bin/env bash
# Security audit (Milestone 5 hardening) — before the composite FK fix in
# 20261109120000_security_hardening.sql, a privileged (owner/admin) user
# of org B could successfully INSERT an employee_sensitive_data row with
# employee_id pointing at org A's employee while declaring organization_id
# = org B — the old INSERT policy only checked organization_id, never
# that it actually matched the referenced employee's real organization.
#
# This is the real client-reachable path (anon key + a real JWT), not a
# direct-DB-only scenario — run it against a database WITHOUT the
# corrective migration applied to see it fail (prove the bug), then
# again after `npx supabase db push` to see it correctly rejected.
#
# Uses stable, pre-provisioned accounts (see provision_test_users.sh)
# and signs in — no signup here, so this never touches the email
# rate limit.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh, plus
# `bash supabase/tests/provision_test_users.sh` run at least once.
# Run: bash supabase/tests/employee_sensitive_data_cross_org_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="$TEST_USER_PASSWORD"
EMAIL_A="stable-xorg-a@worklaw-test.test"
EMAIL_B="stable-xorg-b@worklaw-test.test"

TOKEN_A=$(json_field "$(signin "$EMAIL_A" "$PASSWORD")" "access_token")
TOKEN_B=$(json_field "$(signin "$EMAIL_B" "$PASSWORD")" "access_token")
[ -n "$TOKEN_A" ] && [ -n "$TOKEN_B" ] || fail "could not sign in test users — run provision_test_users.sh first?"

ORG_A=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_A")")" "id")
ORG_B=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_B")")" "id")
CDI_ID=$(json_field "$(rest_body "$(rest GET "contract_types?code=eq.CDI&select=id" "$TOKEN_A")")" "id")
[ -n "$ORG_A" ] && [ -n "$ORG_B" ] && [ -n "$CDI_ID" ] || fail "setup: could not resolve org/CDI id"

EMP_BODY="{\"organization_id\":\"$ORG_A\",\"employee_number\":\"EMP-XORG-$(date +%s)\",\"first_name\":\"Khadija\",\"last_name\":\"Ziani\",\"position\":\"Dev\",\"hire_date\":\"2021-01-01\",\"contract_type_id\":\"$CDI_ID\",\"employment_type\":\"full_time\"}"
EMP_RESP=$(rest POST "employees" "$TOKEN_A" "$EMP_BODY")
[ "$(rest_status "$EMP_RESP")" = "201" ] || fail "setup: org A could not create employee: $(rest_body "$EMP_RESP")"
EMP_A_ID=$(json_field "$(rest_body "$EMP_RESP")" "id")
[ -n "$EMP_A_ID" ] || fail "setup: no employee id returned"

# --- Attack: org B (owner, privileged) attaches sensitive data to org A's
#     employee while declaring org B as the organization_id. ---
ATTACK_BODY="{\"employee_id\":\"$EMP_A_ID\",\"organization_id\":\"$ORG_B\",\"salary_amount\":99999,\"salary_currency\":\"MAD\",\"cin\":\"ZZ000000\",\"cnss_number\":\"0000000\"}"
ATTACK_RESP=$(rest POST "employee_sensitive_data" "$TOKEN_B" "$ATTACK_BODY")
ATTACK_STATUS=$(rest_status "$ATTACK_RESP")
[ "$ATTACK_STATUS" != "201" ] || fail "org B was able to attach sensitive data to org A's employee (cross-org FK missing): $(rest_body "$ATTACK_RESP")"
pass "org B cannot attach employee_sensitive_data to org A's employee (employee_id/organization_id mismatch rejected)"

echo "All employee_sensitive_data cross-org tests passed."
