#!/usr/bin/env bash
# Milestone 5 Partie B — RLS visibility: legal_sources is readable by any
# authenticated user; legal_rules only exposes ACTIVE rows via the API,
# never DRAFT/SOURCE_FOUND/REVIEWED/VERIFIED — checked through a real
# signed-in JWT + the anon key, the same way the Flutter app would call it.
#
# Setup (creating the DRAFT/ACTIVE rows) goes through SUPABASE_DB_URL —
# there is deliberately no client-side write path for legal_rules.
#
# Prerequisites: same as supabase/tests/handle_new_user_test.sh, plus
# `bash supabase/tests/provision_test_users.sh` run at least once.
# Run: bash supabase/tests/legal_rules_visibility_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="$TEST_USER_PASSWORD"
EMAIL="stable-legalvis@worklaw-test.test"
TOKEN=$(json_field "$(signin "$EMAIL" "$PASSWORD")" "access_token")
[ -n "$TOKEN" ] || fail "could not sign in as $EMAIL — run provision_test_users.sh first?"
PROFILE_ID=$(psql_scalar "select id from public.profiles where email = '$EMAIL';")
[ -n "$PROFILE_ID" ] || fail "setup: could not resolve profile id"

RULE_KEY="visibility_rule_$(date +%s)"
# This row is never deleted (legal_sources has no DELETE path, by
# design) — the timestamp keeps the title unique across repeated runs,
# so the lookup below can never match more than one row.
SOURCE_TITLE="Visibility test source $(date +%s)"

# --- Setup via direct DB connection: one DRAFT row, one ACTIVE row ---
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -q <<SQL
insert into public.legal_sources (title, reference, url_or_citation, added_by)
values ('$SOURCE_TITLE', 'Art. 9', 'https://example.test/9', '$PROFILE_ID');

insert into public.legal_rules
  (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by)
select '${RULE_KEY}', 1, 'DRAFT', null, '2024-01-01', 'v1', '{}', '$PROFILE_ID';

insert into public.legal_rules
  (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by, verified_by, verified_at)
select '${RULE_KEY}', 2, 'ACTIVE', ls.id, '2024-01-01', 'v1', '{}', '$PROFILE_ID', '$PROFILE_ID', now()
from public.legal_sources ls where ls.title = '$SOURCE_TITLE';
SQL

# --- Verification via REST: anon key + this user's own JWT ---
ENCODED_TITLE=$(printf '%s' "$SOURCE_TITLE" | sed 's/ /%20/g')
SOURCES_READ=$(rest_body "$(rest GET "legal_sources?title=eq.${ENCODED_TITLE}" "$TOKEN")")
[[ "$SOURCES_READ" == *"$SOURCE_TITLE"* ]] || \
  fail "authenticated user should be able to read legal_sources, got: $SOURCES_READ"
pass "legal_sources is readable by an authenticated user"

RULES_READ=$(rest_body "$(rest GET "legal_rules?rule_key=eq.${RULE_KEY}&select=version,status" "$TOKEN")")
VERSION_COUNT=$(grep -o '"version":' <<< "$RULES_READ" | wc -l | tr -d ' ')
[ "$VERSION_COUNT" = "1" ] || fail "expected exactly 1 visible version for ${RULE_KEY}, got: $RULES_READ"
[[ "$RULES_READ" == *'"status":"ACTIVE"'* ]] || fail "the one visible row should be ACTIVE, got: $RULES_READ"
[[ "$RULES_READ" != *'"status":"DRAFT"'* ]] || fail "DRAFT row leaked through the API: $RULES_READ"
pass "legal_rules only exposes the ACTIVE version via the API, DRAFT stays invisible"

echo "All legal_rules visibility tests passed."
