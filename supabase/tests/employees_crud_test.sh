#!/usr/bin/env bash
# Milestone 3 — employees CRUD integration test (create/read/update/archive,
# and confirms hard delete is impossible since there is no DELETE policy).
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh
# (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_DB_URL exported).
#
# Run: bash supabase/tests/employees_crud_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

EMAIL="employees-crud-$(date +%s)@example.com"
PASSWORD="Passw0rd!23"

signup "$EMAIL" "$PASSWORD" "Test Owner" "CRUD Test Org" >/dev/null

TOKEN=$(json_field "$(signin "$EMAIL" "$PASSWORD")" "access_token")
[ -n "$TOKEN" ] || fail "could not sign in as $EMAIL"

ORG_ID=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN")")" "id")
[ -n "$ORG_ID" ] || fail "could not resolve organization id"

CDI_ID=$(json_field "$(rest_body "$(rest GET "contract_types?code=eq.CDI&select=id" "$TOKEN")")" "id")
[ -n "$CDI_ID" ] || fail "CDI contract type not found — was the migration applied?"

CREATE_BODY="{\"organization_id\":\"$ORG_ID\",\"employee_number\":\"EMP-001\",\"first_name\":\"Amina\",\"last_name\":\"El Fassi\",\"position\":\"Comptable\",\"hire_date\":\"2024-01-15\",\"contract_type_id\":\"$CDI_ID\",\"employment_type\":\"full_time\"}"
CREATE_RESP=$(rest POST "employees" "$TOKEN" "$CREATE_BODY")
[ "$(rest_status "$CREATE_RESP")" = "201" ] || fail "employee creation failed: $(rest_body "$CREATE_RESP")"
EMP_ID=$(json_field "$(rest_body "$CREATE_RESP")" "id")
[ -n "$EMP_ID" ] || fail "no id returned on employee creation"
pass "employee created"

READ_JSON=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID&select=first_name,status" "$TOKEN")")
[[ "$READ_JSON" == *'"status":"active"'* ]] || fail "expected status=active by default, got: $READ_JSON"
pass "employee readable with status=active by default"

PATCH_RESP=$(rest PATCH "employees?id=eq.$EMP_ID" "$TOKEN" '{"department":"Finance"}')
[ "$(rest_status "$PATCH_RESP")" = "200" ] || fail "employee update failed: $(rest_body "$PATCH_RESP")"
pass "employee updated"

ARCHIVE_RESP=$(rest PATCH "employees?id=eq.$EMP_ID" "$TOKEN" '{"status":"archived"}')
ARCHIVE_JSON=$(rest_body "$ARCHIVE_RESP")
[[ "$ARCHIVE_JSON" == *'"status":"archived"'* ]] || fail "expected archive to set status=archived, got: $ARCHIVE_JSON"
pass "employee archived (soft delete, still queryable)"

rest DELETE "employees?id=eq.$EMP_ID" "$TOKEN" >/dev/null
STILL_THERE=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID&select=id" "$TOKEN")")
[[ "$STILL_THERE" == *"$EMP_ID"* ]] || fail "employee row disappeared after DELETE — hard delete should be impossible"
pass "hard delete is blocked by RLS (no DELETE policy) — employee still exists"

echo "All employees CRUD tests passed."
