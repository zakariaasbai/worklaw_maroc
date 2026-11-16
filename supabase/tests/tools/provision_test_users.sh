#!/usr/bin/env bash
# Run this ONCE (or whenever you need to (re)create the suite's stable
# test accounts) — creates every fixed test user used by
# supabase/tests/*_test.sh via the Supabase Admin API, with
# email_confirm=true.
#
# The admin "create user" endpoint does NOT send a confirmation email —
# the account is marked confirmed directly — so running this never
# touches the project's email-sending rate limit, unlike a normal
# signup(). After this, every test script (except handle_new_user_test.sh,
# which specifically tests the real signup path) signs in with one of
# these accounts instead of signing up a fresh one.
#
# Secrets handling:
#   - service_role / secret key: read with input hidden, held only in
#     this process's memory. Passed to curl via a temporary `-K` config
#     file (curl reads "header = ..." lines from it) instead of a
#     command-line -H flag — a -H value is visible to any other process
#     on the machine via `ps`/`/proc/<pid>/cmdline` for as long as curl
#     runs; a -K file is not. The file is created 600 (owner-only), and
#     a trap removes it on exit no matter how the script ends.
#   - test user password: read with input hidden. This is the SAME
#     password every supabase/tests/*_test.sh script will need later to
#     sign in as these accounts — there's no file to read it back from
#     (that would defeat the point), so remember what you type here.
#
# Do NOT run this script with `bash -x`.
# Run: bash supabase/tests/tools/provision_test_users.sh
set -uo pipefail
cd "$(dirname "$0")"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: 'curl' is required but was not found on PATH." >&2
  exit 1
fi

# Not a secret — read visibly. A real mailbox you control; the 14
# accounts below are plus-addressed variants of it (see _test_users.sh),
# since Supabase's email validation rejects an invented domain.
read -r -p "Base email address for the test accounts (e.g. prenom.nom@gmail.com): " TEST_EMAIL_BASE
echo
[[ "$TEST_EMAIL_BASE" == *@* ]] || { echo "Error: TEST_EMAIL_BASE must look like an email address (contain '@')." >&2; exit 1; }
export TEST_EMAIL_BASE

source ./_test_users.sh
source ./_admin_auth.sh

SUPABASE_PROJECT_REF="upraqzlgnhjssaxmkdeh"
SUPABASE_URL="https://${SUPABASE_PROJECT_REF}.supabase.co"

read -r -s -p "Supabase service_role / secret key (input hidden): " SERVICE_ROLE_KEY
echo
validate_admin_key_format "$SERVICE_ROLE_KEY" || exit 1

read -r -s -p "Password to set for all stable test accounts (input hidden): " TEST_PASSWORD
echo
[ -n "$TEST_PASSWORD" ] || { echo "Error: the test password cannot be empty." >&2; exit 1; }

CURL_CONFIG=$(mktemp)
chmod 600 "$CURL_CONFIG"
trap 'rm -f "$CURL_CONFIG"' EXIT INT TERM
write_admin_curl_config "$SERVICE_ROLE_KEY" "$CURL_CONFIG"

echo "Verifying the admin key..."
verify_admin_key "$SUPABASE_URL" "$CURL_CONFIG" || exit 1
echo "Admin key OK."
echo

created=0
already_existed=0

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
        # Stop at the first real failure instead of repeating the same
        # cause 14 times — e.g. a rejected email domain/format applies
        # identically to every remaining account.
        echo "Error: creating $email failed (HTTP $status): $body" >&2
        echo "Stopping after the first failure; $created created, $already_existed already existed before this." >&2
        unset SERVICE_ROLE_KEY TEST_PASSWORD
        exit 1
      fi
      ;;
  esac
done

unset SERVICE_ROLE_KEY TEST_PASSWORD

echo
echo "Summary: $created created, $already_existed already existed"
