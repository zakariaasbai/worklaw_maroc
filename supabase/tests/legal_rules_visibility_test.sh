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
# `bash supabase/tests/tools/provision_test_users.sh` run at least once.
# Run: bash supabase/tests/legal_rules_visibility_test.sh
set -euo pipefail
cd "$(dirname "$0")"
source ./_helpers.sh
require_env

PASSWORD="$TEST_USER_PASSWORD"
EMAIL="$(stable_email "stable-legalvis")"
TOKEN=$(json_field "$(signin "$EMAIL" "$PASSWORD")" "access_token")
[ -n "$TOKEN" ] || fail "could not sign in as $EMAIL — run tools/provision_test_users.sh first?"
PROFILE_ID=$(psql_scalar "select id from public.profiles where email = '$EMAIL';")
[ -n "$PROFILE_ID" ] || fail "setup: could not resolve profile id"

# Two distinct rule_keys, not two versions of the same one:
# legal_rules_no_overlapping_periods excludes on (rule_key, period)
# regardless of status, and both rows below share the same
# effective_from with no effective_until — same rule_key would make
# their ranges identical and the ACTIVE insert would be rejected by
# that constraint before this script ever reaches the REST checks.
RULE_KEY_DRAFT="visibility_rule_draft_$(date +%s)"
RULE_KEY_ACTIVE="visibility_rule_active_$(date +%s)"
# This row is never deleted via the API (legal_sources has no DELETE
# path, by design) — the timestamp keeps the title unique across
# repeated runs, so the lookup below can never match more than one row.
SOURCE_TITLE="Visibility test source $(date +%s)"

# Fixture rows are committed (PostgREST reads them over a separate
# connection, so they can't stay inside an open psql transaction) —
# clean them up via the same privileged connection on exit, pass or
# fail, instead of leaving them on the remote project permanently.
cleanup() {
  psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -q -c "
    delete from public.legal_rules where rule_key in ('$RULE_KEY_DRAFT', '$RULE_KEY_ACTIVE');
    delete from public.legal_sources where title = '$SOURCE_TITLE';
  " >/dev/null 2>&1 || echo "Warning: could not clean up fixture rows (rule_key=$RULE_KEY_DRAFT/$RULE_KEY_ACTIVE, legal_sources.title=$SOURCE_TITLE) — remove manually." >&2
}
trap cleanup EXIT

# --- Setup via direct DB connection: one DRAFT row, one ACTIVE row ---
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -q <<SQL
insert into public.legal_sources (title, reference, url_or_citation, added_by)
values ('$SOURCE_TITLE', 'Art. 9', 'https://example.test/9', '$PROFILE_ID');

insert into public.legal_rules
  (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by)
select '${RULE_KEY_DRAFT}', 1, 'DRAFT', null, '2024-01-01', 'v1', '{}', '$PROFILE_ID';

insert into public.legal_rules
  (rule_key, version, status, legal_source_id, effective_from, input_schema_version, rule_definition, created_by, verified_by, verified_at)
select '${RULE_KEY_ACTIVE}', 1, 'ACTIVE', ls.id, '2024-01-01', 'v1', '{}', '$PROFILE_ID', '$PROFILE_ID', now()
from public.legal_sources ls where ls.title = '$SOURCE_TITLE';
SQL

# --- Verification via REST: anon key + this user's own JWT ---
ENCODED_TITLE=$(printf '%s' "$SOURCE_TITLE" | sed 's/ /%20/g')
SOURCES_READ=$(rest_body "$(rest GET "legal_sources?title=eq.${ENCODED_TITLE}" "$TOKEN")")
[[ "$SOURCES_READ" == *"$SOURCE_TITLE"* ]] || \
  fail "authenticated user should be able to read legal_sources, got: $SOURCES_READ"
pass "legal_sources is readable by an authenticated user"

ACTIVE_READ=$(rest_body "$(rest GET "legal_rules?rule_key=eq.${RULE_KEY_ACTIVE}&select=version,status" "$TOKEN")")
[[ "$ACTIVE_READ" == *'"status":"ACTIVE"'* ]] || fail "the ACTIVE row should be visible via the API, got: $ACTIVE_READ"
pass "legal_rules exposes the ACTIVE row via the API"

DRAFT_READ=$(rest_body "$(rest GET "legal_rules?rule_key=eq.${RULE_KEY_DRAFT}" "$TOKEN")")
[ "$DRAFT_READ" = "[]" ] || fail "DRAFT row leaked through the API: $DRAFT_READ"
pass "legal_rules hides the DRAFT row via the API"

echo "All legal_rules visibility tests passed."
