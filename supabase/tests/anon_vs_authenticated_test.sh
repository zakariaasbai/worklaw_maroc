#!/usr/bin/env bash
# Security audit (Milestone 5 hardening) — proves the `ALTER POLICY ...
# TO authenticated` changes in 20261109120000_security_hardening.sql
# actually block the `anon` role through the real REST API, not just in
# theory. Before that migration, these policies had no `to` clause
# (applied to PUBLIC); this was incidentally safe because auth.uid() is
# NULL for anon, but was never declared — this test makes it explicit
# and durable.
#
# The anon key itself is a valid JWT for the `anon` role, so it is used
# directly as the bearer token for the "no user session" calls below —
# this is a real, unauthenticated-equivalent REST call, not a SQL-level
# policy inspection.
#
# Uses a stable, pre-provisioned account (see provision_test_users.sh)
# and signs in — no signup here, so this never touches the email
# rate limit.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh, plus
# `bash supabase/tests/provision_test_users.sh` run at least once.
# Run: bash supabase/tests/anon_vs_authenticated_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="$TEST_USER_PASSWORD"
EMAIL="stable-anon@worklaw-test.test"

TOKEN=$(json_field "$(signin "$EMAIL" "$PASSWORD")" "access_token")
[ -n "$TOKEN" ] || fail "could not sign in as $EMAIL — run provision_test_users.sh first?"

ORG_ID=$(json_field "$(rest_body "$(rest GET "organizations?select=id" "$TOKEN")")" "id")
CDI_ID=$(json_field "$(rest_body "$(rest GET "contract_types?code=eq.CDI&select=id" "$TOKEN")")" "id")
[ -n "$ORG_ID" ] && [ -n "$CDI_ID" ] || fail "setup: could not resolve org/CDI id"

EMP_BODY="{\"organization_id\":\"$ORG_ID\",\"employee_number\":\"EMP-ANON-$(date +%s)\",\"first_name\":\"Rania\",\"last_name\":\"Berrada\",\"position\":\"Dev\",\"hire_date\":\"2022-01-01\",\"contract_type_id\":\"$CDI_ID\",\"employment_type\":\"full_time\"}"
EMP_RESP=$(rest POST "employees" "$TOKEN" "$EMP_BODY")
[ "$(rest_status "$EMP_RESP")" = "201" ] || fail "setup: could not create employee: $(rest_body "$EMP_RESP")"
EMP_ID=$(json_field "$(rest_body "$EMP_RESP")" "id")
[ -n "$EMP_ID" ] || fail "setup: no employee id returned"

# --- anon key alone (no user session) must see nothing ---
ANON_READ=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID" "$SUPABASE_ANON_KEY")")
[ "$ANON_READ" = "[]" ] || fail "anon role could read employees data: $ANON_READ"
pass "anon role (no user session) gets zero rows from /rest/v1/employees"

ANON_ORG_READ=$(rest_body "$(rest GET "organizations?id=eq.$ORG_ID" "$SUPABASE_ANON_KEY")")
[ "$ANON_ORG_READ" = "[]" ] || fail "anon role could read organizations data: $ANON_ORG_READ"
pass "anon role (no user session) gets zero rows from /rest/v1/organizations"

# --- the legitimate, signed-in org member must still see its own data ---
MEMBER_READ=$(rest_body "$(rest GET "employees?id=eq.$EMP_ID&select=id" "$TOKEN")")
[[ "$MEMBER_READ" == *"$EMP_ID"* ]] || fail "authenticated org member lost access to its own employee: $MEMBER_READ"
pass "authenticated org member still has normal access to its own data"

# --- anon must not even have EXECUTE on the SECURITY DEFINER helpers,
#     not just be blocked by the policies that call them. Supabase grants
#     EXECUTE to anon explicitly at project creation (ALTER DEFAULT
#     PRIVILEGES) — a bare "REVOKE ... FROM PUBLIC" does not remove that
#     separate grant, only an explicit "REVOKE ... FROM anon" does. This
#     checks the actual grant via has_function_privilege(), not just
#     behavior through a policy. ---
for fn in "is_member_of(uuid)" "is_owner_of(uuid)" "is_privileged_member_of(uuid)" "get_applicable_rule(text, date)"; do
  HAS_PRIV=$(psql_scalar "select has_function_privilege('anon', 'public.${fn}', 'execute');")
  [ "$HAS_PRIV" = "f" ] || fail "anon still has EXECUTE on public.${fn}: has_function_privilege returned '$HAS_PRIV'"
  pass "anon has no EXECUTE on public.${fn}"
done

echo "All anon-vs-authenticated tests passed."
