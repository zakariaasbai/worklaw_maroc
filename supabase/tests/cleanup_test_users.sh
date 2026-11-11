#!/usr/bin/env bash
# Deletes the stable test accounts created by provision_test_users.sh
# via the Supabase Admin API. Destructive and irreversible — requires
# typing an explicit confirmation phrase before anything is deleted.
#
# Same secret handling as provision_test_users.sh: service_role key read
# with input hidden, passed to curl via a temporary 600 `-K` config file
# removed on exit via trap, never a command-line -H value.
#
# Do NOT run this script with `bash -x`.
# Run: bash supabase/tests/cleanup_test_users.sh
set -uo pipefail
cd "$(dirname "$0")"
source ./_test_users.sh

SUPABASE_PROJECT_REF="upraqzlgnhjssaxmkdeh"
SUPABASE_URL="https://${SUPABASE_PROJECT_REF}.supabase.co"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: 'curl' is required but was not found on PATH." >&2
  exit 1
fi

echo "This will PERMANENTLY delete ${#TEST_USERS[@]} stable test accounts"
echo "(and, via cascade, their organizations/employees/etc.) from:"
echo "  $SUPABASE_URL"
echo
echo "Accounts to delete:"
for entry in "${TEST_USERS[@]}"; do
  IFS='|' read -r email _ _ <<< "$entry"
  echo "  - $email"
done
echo
read -r -p "Type DELETE (all caps) to confirm, anything else cancels: " CONFIRMATION
if [ "$CONFIRMATION" != "DELETE" ]; then
  echo "Cancelled — nothing was deleted."
  exit 1
fi

read -r -s -p "Supabase service_role key (input hidden): " SERVICE_ROLE_KEY
echo
[ -n "$SERVICE_ROLE_KEY" ] || { echo "Error: the service_role key cannot be empty." >&2; exit 1; }

CURL_CONFIG=$(mktemp)
chmod 600 "$CURL_CONFIG"
trap 'rm -f "$CURL_CONFIG"' EXIT INT TERM
{
  printf 'header = "apikey: %s"\n' "$SERVICE_ROLE_KEY"
  printf 'header = "Authorization: Bearer %s"\n' "$SERVICE_ROLE_KEY"
} > "$CURL_CONFIG"

deleted=0
not_found=0
failed=0

for entry in "${TEST_USERS[@]}"; do
  IFS='|' read -r email _ _ <<< "$entry"

  # Look the user up by email first — the admin API deletes by user id,
  # not by email.
  encoded_email=$(printf '%s' "$email" | sed 's/@/%40/')
  lookup=$(curl -s -K "$CURL_CONFIG" -w '\n%{http_code}' \
    "$SUPABASE_URL/auth/v1/admin/users?email=${encoded_email}")
  lookup_status=$(tail -n1 <<< "$lookup")
  lookup_body=$(sed '$d' <<< "$lookup")

  user_id=$(grep -o '"id":"[^"]*"' <<< "$lookup_body" | head -1 | cut -d'"' -f4 || true)

  if [ "$lookup_status" != "200" ] || [ -z "$user_id" ]; then
    echo "Not found (already deleted?): $email"
    not_found=$((not_found + 1))
    continue
  fi

  delete_resp=$(curl -s -K "$CURL_CONFIG" -w '\n%{http_code}' -X DELETE \
    "$SUPABASE_URL/auth/v1/admin/users/${user_id}")
  delete_status=$(tail -n1 <<< "$delete_resp")

  if [ "$delete_status" = "200" ] || [ "$delete_status" = "204" ]; then
    echo "Deleted: $email"
    deleted=$((deleted + 1))
  else
    echo "FAILED ($delete_status) deleting $email: $(sed '$d' <<< "$delete_resp")" >&2
    failed=$((failed + 1))
  fi
done

unset SERVICE_ROLE_KEY

echo
echo "Summary: $deleted deleted, $not_found not found, $failed failed"
[ "$failed" -eq 0 ] || exit 1
