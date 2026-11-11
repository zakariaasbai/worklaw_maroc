#!/usr/bin/env bash
# Run this ONCE (or whenever you need to (re)create the suite's stable
# test accounts) — creates every fixed test user used by
# supabase/tests/*.sh via the Supabase Admin API, with email_confirm=true.
#
# The admin "create user" endpoint does NOT send a confirmation email —
# the account is marked confirmed directly — so running this never
# touches the project's email-sending rate limit, unlike a normal
# signup(). After this, every test script (except handle_new_user_test.sh,
# which specifically tests the real signup path) signs in with one of
# these accounts instead of signing up a fresh one.
#
# Secrets handling:
#   - service_role key: read with input hidden, held only in this
#     process's memory. Passed to curl via a temporary `-K` config file
#     (curl reads "header = ..." lines from it) instead of a command-line
#     -H flag — a -H value is visible to any other process on the
#     machine via `ps`/`/proc/<pid>/cmdline` for as long as curl runs; a
#     -K file is not. The file is created 600 (owner-only), and a trap
#     removes it on exit no matter how the script ends.
#   - test user password: read with input hidden. This is the SAME
#     password every supabase/tests/*.sh script will need later to sign
#     in as these accounts — there's no file to read it back from (that
#     would defeat the point), so remember what you type here.
#
# Do NOT run this script with `bash -x`.
# Run: bash supabase/tests/provision_test_users.sh
set -uo pipefail
cd "$(dirname "$0")"
source ./_test_users.sh

SUPABASE_PROJECT_REF="upraqzlgnhjssaxmkdeh"
SUPABASE_URL="https://${SUPABASE_PROJECT_REF}.supabase.co"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: 'curl' is required but was not found on PATH." >&2
  exit 1
fi

read -r -s -p "Supabase service_role key (input hidden): " SERVICE_ROLE_KEY
echo
read -r -s -p "Password to set for all stable test accounts (input hidden): " TEST_PASSWORD
echo
[ -n "$SERVICE_ROLE_KEY" ] || { echo "Error: the service_role key cannot be empty." >&2; exit 1; }
[ -n "$TEST_PASSWORD" ] || { echo "Error: the test password cannot be empty." >&2; exit 1; }

CURL_CONFIG=$(mktemp)
chmod 600 "$CURL_CONFIG"
trap 'rm -f "$CURL_CONFIG"' EXIT INT TERM
{
  printf 'header = "apikey: %s"\n' "$SERVICE_ROLE_KEY"
  printf 'header = "Authorization: Bearer %s"\n' "$SERVICE_ROLE_KEY"
} > "$CURL_CONFIG"

created=0
already_existed=0
failed=0

for entry in "${TEST_USERS[@]}"; do
  IFS='|' read -r email full_name org_name <<< "$entry"

  response=$(curl -s -K "$CURL_CONFIG" -w '\n%{http_code}' -X POST "$SUPABASE_URL/auth/v1/admin/users" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$email\",\"password\":\"$TEST_PASSWORD\",\"email_confirm\":true,\"user_metadata\":{\"full_name\":\"$full_name\",\"organization_name\":\"$org_name\"}}")
  status=$(tail -n1 <<< "$response")
  body=$(sed '$d' <<< "$response")

  case "$status" in
    200 | 201)
      echo "Created: $email"
      created=$((created + 1))
      ;;
    *)
      if [[ "$body" == *"already"* ]] || [[ "$body" == *"exists"* ]]; then
        echo "Already exists: $email"
        already_existed=$((already_existed + 1))
      else
        echo "FAILED ($status) for $email: $body" >&2
        failed=$((failed + 1))
      fi
      ;;
  esac
done

unset SERVICE_ROLE_KEY TEST_PASSWORD

echo
echo "Summary: $created created, $already_existed already existed, $failed failed"
[ "$failed" -eq 0 ] || exit 1
