#!/usr/bin/env bash
# Runs every integration test in supabase/tests/ against the remote
# Supabase project, prompting for the two sensitive values interactively
# so neither ever lands in a file or in shell history via an `export`
# line typed into a terminal transcript.
#
# - SUPABASE_ANON_KEY is read visibly (it is not a secret — see
#   DATABASE.md), but its format is validated before use.
# - The DB password is read with `read -rs` (not echoed to the screen),
#   percent-encoded into the connection URI, and never printed, logged,
#   or written to disk. Do NOT run this script with `bash -x` — that
#   would print every expanded command, including SUPABASE_DB_URL.
# - Uses the Session Pooler, not the direct `db.<ref>.supabase.co` host
#   — that host is IPv6-only on many projects and unreachable from WSL2
#   by default ("Network is unreachable"). See DATABASE.md.
#
# Run: bash supabase/tests/run_all.sh
set -uo pipefail
cd "$(dirname "$0")"

SUPABASE_PROJECT_REF="upraqzlgnhjssaxmkdeh"
export SUPABASE_URL="https://${SUPABASE_PROJECT_REF}.supabase.co"

for cmd in psql curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is required but was not found on PATH." >&2
    exit 1
  fi
done

read -r -p "SUPABASE_ANON_KEY: " SUPABASE_ANON_KEY
echo
read -r -p "Session Pooler host (e.g. aws-0-eu-west-3.pooler.supabase.com): " POOLER_HOST
echo
read -r -s -p "Supabase DB password (input hidden): " SUPABASE_DB_PASSWORD
echo

[ -n "$SUPABASE_ANON_KEY" ] || { echo "Error: SUPABASE_ANON_KEY cannot be empty." >&2; exit 1; }
[ -n "$POOLER_HOST" ] || { echo "Error: the pooler host cannot be empty." >&2; exit 1; }
[ -n "$SUPABASE_DB_PASSWORD" ] || { echo "Error: the DB password cannot be empty." >&2; exit 1; }

# Sanity-check the anon/publishable key format before using it anywhere —
# catches a pasted project ref, access token, or truncated key early
# instead of letting all 10 tests fail on a confusing 401/invalid-apikey.
if { [[ "$SUPABASE_ANON_KEY" != eyJ* ]] && [[ "$SUPABASE_ANON_KEY" != sb_publishable_* ]]; } \
  || [ "${#SUPABASE_ANON_KEY}" -le 40 ]; then
  echo "Error: SUPABASE_ANON_KEY doesn't look like a valid key —" >&2
  echo "it must start with 'eyJ' or 'sb_publishable_' and be longer than 40 characters." >&2
  exit 1
fi

# Percent-encode the password so special characters (@, :, /, etc.) can't
# break the connection URI.
urlencode() {
  local string="$1" length i c hex encoded=""
  length="${#string}"
  for ((i = 0; i < length; i++)); do
    c="${string:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) encoded+="$c" ;;
      *)
        printf -v hex '%%%02X' "'$c"
        encoded+="$hex"
        ;;
    esac
  done
  printf '%s' "$encoded"
}

export SUPABASE_ANON_KEY
export SUPABASE_DB_URL="postgresql://postgres.${SUPABASE_PROJECT_REF}:$(urlencode "$SUPABASE_DB_PASSWORD")@${POOLER_HOST}:5432/postgres"
unset SUPABASE_DB_PASSWORD

# Test the DB connection once, up front — if the pooler host/port is
# wrong, or the network can't reach it, fail fast with the real cause
# instead of letting 10 tests fail one by one for the same reason.
echo "Testing database connection via the Session Pooler..."
CONN_TEST_OUTPUT=$(PGCONNECT_TIMEOUT=10 psql "$SUPABASE_DB_URL" -tAq -v ON_ERROR_STOP=1 -c "select 1;" 2>&1)
CONN_TEST_STATUS=$?
if [ "$CONN_TEST_STATUS" -ne 0 ]; then
  echo "Error: could not connect to the database via the Session Pooler." >&2
  echo "Cause reported by psql:" >&2
  echo "$CONN_TEST_OUTPUT" >&2
  echo >&2
  echo "Check the pooler host, and that the username/port match" >&2
  echo "Project Settings -> Database -> Connection pooling -> Session pooler." >&2
  exit 1
fi
echo "Database connection OK."
echo

passed=0
failed=0
skipped=0
failed_names=()
failed_first_lines=()
skipped_names=()
skipped_first_lines=()

# First line that looks like the actual cause, for the final summary —
# prefers a line matching the given marker ("FAIL:" or "SKIP:", how a
# test reports its own result) and falls back to the first non-empty
# output line (e.g. a raw curl/psql error if the script died before
# reaching any assertion at all).
first_marked_line() {
  local text="$1" marker="$2" line
  line=$(printf '%s\n' "$text" | grep -m1 -i "$marker" || true)
  if [ -z "$line" ]; then
    line=$(printf '%s\n' "$text" | grep -m1 . || true)
  fi
  printf '%s' "$line"
}

for test_file in ./*.sh; do
  base="$(basename "$test_file")"
  [ "$base" = "_helpers.sh" ] && continue
  [ "$base" = "run_all.sh" ] && continue

  echo "=== Running $base ==="
  output=$(bash "$test_file" 2>&1)
  status=$?
  printf '%s\n' "$output"
  case "$status" in
    0)
      passed=$((passed + 1))
      ;;
    2)
      # Reserved exit code for "rate limited, not retried" — see
      # skip() in _helpers.sh / handle_new_user_test.sh. Not a failure.
      skipped=$((skipped + 1))
      skipped_names+=("$base")
      skipped_first_lines+=("$(first_marked_line "$output" "SKIP:")")
      ;;
    *)
      failed=$((failed + 1))
      failed_names+=("$base")
      failed_first_lines+=("$(first_marked_line "$output" "FAIL:")")
      ;;
  esac
  echo
done

echo "========================================"
echo "Summary: $passed passed, $failed failed, $skipped skipped"
if [ "$skipped" -gt 0 ]; then
  echo "Skipped tests:"
  for i in "${!skipped_names[@]}"; do
    echo "  - ${skipped_names[$i]}: ${skipped_first_lines[$i]}"
  done
fi
if [ "$failed" -gt 0 ]; then
  echo "Failed tests:"
  for i in "${!failed_names[@]}"; do
    echo "  - ${failed_names[$i]}: ${failed_first_lines[$i]}"
  done
  exit 1
fi
