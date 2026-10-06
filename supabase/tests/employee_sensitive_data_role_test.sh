#!/usr/bin/env bash
# Milestone 3 — employee_sensitive_data (salary/CNSS/CIN) must be visible
# only to owner/admin, never to a plain 'member'.
#
# Setup (adding the 'member' row to organization_members) goes through
# SUPABASE_DB_URL — a privileged direct Postgres connection — because there
# is no client-side way to self-assign a role yet (no invite flow), and RLS
# correctly refuses it. That step proves nothing by itself.
#
# Verification goes through the anon key + a real signed-in JWT for that
# member, exactly like the Flutter app would call it. That's the part that
# actually proves the RLS behavior.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh.
# Run: bash supabase/tests/employee_sensitive_data_role_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="Passw0rd!23"
EMAIL_OWNER="sensitive-owner-$(date +%s)@example.com"
EMAIL_MEMBER="sensitive-member-$(date +%s)@example.com"

signup "$EMAIL_OWNER" "$PASSWORD" "Owner" "Sensitive Data Org" >/dev/null
# Signing up gives this user their own separate organization (as owner) —
# irrelevant here, we only use their identity, then add them as 'member' of
# EMAIL_OWNER's organization below.
signup "$EMAIL_MEMBER" "$PASSWORD" "Member" "Member's Own Org" >/dev/null

TOKEN_OWNER=$(json_field "$(signin "$EMAIL_OWNER" "$PASSWORD")" "access_token")
[ -n "$TOKEN_OWNER" ] || fail "could not sign in as owner"

ORG_ID=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN_OWNER")")" "id")
CDI_ID=$(json_field "$(rest_body "$(rest GET "contract_types?code=eq.CDI&select=id" "$TOKEN_OWNER")")" "id")
[ -n "$ORG_ID" ] && [ -n "$CDI_ID" ] || fail "setup: could not resolve org / CDI id"

CREATE_BODY="{\"organization_id\":\"$ORG_ID\",\"employee_number\":\"EMP-SENS-1\",\"first_name\":\"Sara\",\"last_name\":\"Bennani\",\"position\":\"RH\",\"hire_date\":\"2022-03-01\",\"contract_type_id\":\"$CDI_ID\",\"employment_type\":\"full_time\"}"
CREATE_RESP=$(rest POST "employees" "$TOKEN_OWNER" "$CREATE_BODY")
[ "$(rest_status "$CREATE_RESP")" = "201" ] || fail "setup: could not create employee: $(rest_body "$CREATE_RESP")"
EMP_ID=$(json_field "$(rest_body "$CREATE_RESP")" "id")
[ -n "$EMP_ID" ] || fail "setup: no employee id returned"

SENSITIVE_BODY="{\"employee_id\":\"$EMP_ID\",\"organization_id\":\"$ORG_ID\",\"salary_amount\":12000,\"salary_currency\":\"MAD\",\"cin\":\"AB123456\",\"cnss_number\":\"1234567\"}"
SENSITIVE_RESP=$(rest POST "employee_sensitive_data" "$TOKEN_OWNER" "$SENSITIVE_BODY")
[ "$(rest_status "$SENSITIVE_RESP")" = "201" ] || fail "setup: owner could not create employee_sensitive_data row: $(rest_body "$SENSITIVE_RESP")"

# --- Privileged setup step: add MEMBER's profile to ORG_ID as 'member'. ---
MEMBER_PROFILE_ID=$(psql_scalar "select id from public.profiles where email = '$EMAIL_MEMBER';")
[ -n "$MEMBER_PROFILE_ID" ] || fail "could not resolve member profile id via direct DB connection"
psql "$SUPABASE_DB_URL" -q -c \
  "insert into public.organization_members (organization_id, profile_id, role) values ('$ORG_ID', '$MEMBER_PROFILE_ID', 'member');"

# --- Verification: real client calls, anon key + member's own JWT. ---
TOKEN_MEMBER=$(json_field "$(signin "$EMAIL_MEMBER" "$PASSWORD")" "access_token")
[ -n "$TOKEN_MEMBER" ] || fail "could not sign in as member"

MEMBER_EMP_READ=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID&select=id" "$TOKEN_MEMBER")")
[[ "$MEMBER_EMP_READ" == *"$EMP_ID"* ]] || fail "member should be able to read the base employee row, got: $MEMBER_EMP_READ"
pass "member can read the non-sensitive employee record"

MEMBER_SENSITIVE_READ=$(rest_body "$(rest GET "employee_sensitive_data?employee_id=eq.$EMP_ID" "$TOKEN_MEMBER")")
[ "$MEMBER_SENSITIVE_READ" = "[]" ] || fail "member should NOT see employee_sensitive_data, got: $MEMBER_SENSITIVE_READ"
pass "member cannot read employee_sensitive_data (salary/CNSS/CIN hidden)"

OWNER_SENSITIVE_READ=$(rest_body "$(rest GET "employee_sensitive_data?employee_id=eq.$EMP_ID" "$TOKEN_OWNER")")
[[ "$OWNER_SENSITIVE_READ" == *'"salary_amount":12000'* ]] || fail "owner should see the salary, got: $OWNER_SENSITIVE_READ"
pass "owner can read employee_sensitive_data"

echo "All employee_sensitive_data role-visibility tests passed."
