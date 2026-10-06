#!/usr/bin/env bash
# Integration test for the handle_new_user() trigger (Milestone 2).
#
# It calls the real local GoTrue signup endpoint — the same one the Flutter
# app will call — rather than hand-crafting an INSERT into auth.users, so it
# exercises the exact path used in production.
#
# Prerequisites:
#   1. `npx supabase start` is running.
#   2. Export these from `npx supabase status`:
#        export SUPABASE_URL=http://127.0.0.1:54321   # API URL
#        export SUPABASE_ANON_KEY=...                 # anon public key
#        export SUPABASE_DB_URL=postgresql://postgres:postgres@127.0.0.1:54322/postgres
#
# Run: bash supabase/tests/handle_new_user_test.sh

set -euo pipefail

: "${SUPABASE_URL:?Set SUPABASE_URL (see 'npx supabase status')}"
: "${SUPABASE_ANON_KEY:?Set SUPABASE_ANON_KEY (see 'npx supabase status')}"
: "${SUPABASE_DB_URL:?Set SUPABASE_DB_URL (see 'npx supabase status')}"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }

signup() {
  local email="$1" full_name="$2" org_name="$3"
  curl -s -o /tmp/handle_new_user_test_response.json -w '%{http_code}' \
    -X POST "$SUPABASE_URL/auth/v1/signup" \
    -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"Passw0rd!23\",\"data\":{\"full_name\":\"$full_name\",\"organization_name\":\"$org_name\"}}"
}

row_count() {
  psql "$SUPABASE_DB_URL" -t -A -c "$1"
}

# --- Test 1: happy path creates profile + organization + owner membership ---
EMAIL_OK="trigger-test-ok-$(date +%s)@test.local"
STATUS=$(signup "$EMAIL_OK" "Jane Doe" "Acme SARL")
[ "$STATUS" = "200" ] || fail "happy path signup returned HTTP $STATUS (expected 200): $(cat /tmp/handle_new_user_test_response.json)"

PROFILE_COUNT=$(row_count "select count(*) from public.profiles p join auth.users u on u.id = p.id where u.email = '$EMAIL_OK';")
[ "$PROFILE_COUNT" = "1" ] || fail "expected 1 profile row for $EMAIL_OK, got $PROFILE_COUNT"

MEMBER_COUNT=$(row_count "
  select count(*) from public.organization_members om
  join public.profiles p on p.id = om.profile_id
  join auth.users u on u.id = p.id
  join public.organizations o on o.id = om.organization_id
  where u.email = '$EMAIL_OK' and om.role = 'owner' and o.name = 'Acme SARL' and o.created_by = p.id;
")
[ "$MEMBER_COUNT" = "1" ] || fail "expected 1 owner membership linking profile/org for $EMAIL_OK, got $MEMBER_COUNT"
pass "happy path creates profile + organization + owner membership"

# --- Test 2: missing organization_name must reject signup, no orphan rows ---
EMAIL_BAD="trigger-test-bad-$(date +%s)@test.local"
STATUS=$(signup "$EMAIL_BAD" "John Doe" "")
[ "$STATUS" != "200" ] || fail "signup with empty organization_name should have failed, got HTTP 200"

ORPHAN_COUNT=$(row_count "select count(*) from auth.users where email = '$EMAIL_BAD';")
[ "$ORPHAN_COUNT" = "0" ] || fail "expected no auth.users row left behind for rejected signup $EMAIL_BAD, found $ORPHAN_COUNT"
pass "invalid organization_name is rejected without leaving an orphaned auth user"

echo "All handle_new_user() integration tests passed."
